/* PRU_1 OSCILLOSCOPE CODE */
/* Copyright (C) 2015 Samuel Ruddell */

.origin 0

/* DEFINITIONS */
#include "pru.hp"

/* PERIPHERAL INITIALIZATION */
    INIT:
      LBCO r2, c4, 4, 4                 // SYSCFG register
      CLR r2, r2, 4                     // enable OCP master ports
      SBCO r2, c4, 4, 4                 // store SYSCFG settings
    
      MOV r1, CTPPR0                    // Constant Table Programmable Pointer
      MOV r2, 0x240                     // set up c28 as PRU CTRL register pointer
      SBBO r2, r1, 0, 4                 // store address for easy reference later

      MOV r2, 0x0
      SBCO r2, c28, CTBIR0, 4           // ensure c24 and c25 setup correctly
    
      MOV r3, 0                         // step counter register, disable writing until ready
      MOV r4.w0, 2048 << 2              // steps until interrupt * 4 (for 8192 bytes of memory)

      LBCO r5, c28, 0, 4                // load in CYCLE settings
      SET r5, 3                         // set bit 3 to enable CYCLE
      SBCO r5, c28, 0, 4                // store CYCLE settings

      XIN 0, r25, 1                     // load in MAC settings (multiply accumulate)
      CLR r25.t0                        // set up multiply-only mode
      XOUT 0, r25, 1                    // store MAC_mode to MAC

      JAL r23.w0, LOAD_PARAMETERS       // load parameters from memory subroutine
      MOV r7, 0x8000                    // Start DAC at centre of range

      JAL r23.w0, SETUP_SPI             // setup SPI subroutine  
      JAL r23.w0, SETUP_ADC             // setup ADC subroutine 

/* READ ADC AND PACK DATA */
    WAIT:
      LBBO r2, r20, FIFOCOUNT, 4        // check for words in FIFO0
      QBEQ WAIT, r2, 0                  // WAIT until word present in FIFO0
    
    READ:
      LBCO r8, c28, CYCLE, 4            // load in CYCLE COUNT
      LBBO r9, r21, 0, 4                // load 4 bytes from FIFO into r9
    
    QBBS PACK_XY, r4.t20                // TIME or XY mode for oscilloscope 
    PACK_TIME:                          // pack time data into 32 bit register
      LSL r6, r8, 12                    // use bits[31:12] for time, store in r6
      QBA PACK_END
    PACK_XY:
      LSL r6, r7.w0, 12                 // pack X data into 32 bit register
    PACK_END:
      OR r6, r6, r9                     // pack as: time->bits[31:12], adc->bits[11:0]

/* OPEN LOOP */
      QBBC CLOSEDLOOP, r4.t16           // do closed loop if bit[16] clear
    OPENLOOP:
      MOV r2, 0x8000                    // used to test whether amplitude reached below
      QBBC SCANDOWN, r4.t18             // scan down instead

      SCANUP:
        ADD r2, r2, r10.w0              // test whether upper amplitude reached 
        QBLE TOGGLE_DIRECTION, r7, r2   // toggle direction if upper amplitude reached
        ADD r7, r7, 1                   // increase DAC output
        QBA ENDLOOP        

      SCANDOWN:
        SUB r2, r2, r10.w0              // test whether lower amplitude reached
        QBGE TOGGLE_DIRECTION, r7, r2   // toggle direction if lower amplitude reached
        SUB r7, r7, 1                   // decrease DAC output
        QBA ENDLOOP        

      TOGGLE_DIRECTION:
        MOV r7, r2                      // MOV min/max amplitude to DAC output
        XOR r4.w2, r4.w2, 1<<2          // TOGGLE scan UP/DOWN

      LOAD_ADC_PARAMETERS:              // LOAD new ADC parameters on open loop only
        JAL r23.w0, SETUP_ADC           // setup ADC subroutine 
        QBA ENDLOOP

/* SEMI-CLOSED LOOP */
      // The point of this is to scan DAC to XLOCK before enabling closed loop 
      // set a default value of PREVIOUS_ERROR_SIGNAL

/* CLOSED LOOP */
    CLOSEDLOOP:
        SUB r19, r9, r11.w0             // calculate error signal as ADC - YLOCK

      PROPORTIONAL:
        MOV r28, r19                    // error signal value to MAC as operand 1
        MOV r29, r12                    // move PGAIN to MAC
        XOUT 0, r28, 8                  // multiply
        XIN 0, r26, 8                   // load in product to r26 and r27
        MOV r15, r26                    // store lower product in r15

      INTEGRAL:
        QBBS INTEGRAL_RESET, r4.t19     // skip this if integrator reset active
        MOV r29, r13                    // move IGAIN to MAC
        XOUT 0, r28, 8                  // multiply
        XIN 0, r26, 8                   // load in product to r26 and r27
        ADD r16, r16, r26               // integrate lower product into r16

        INT_OVERFLOW_TEST:                      // test for integrator overflow
          QBEQ DERIVATIVE, r16.w2, 0            // no overflow or underflow
          QBBS INT_UNDERFLOW, r16.t31           // number is negative, check for underflow
          INT_OVERFLOW:
            MOV r16, 0xffff                     // max output
            QBA DERIVATIVE
          INT_UNDERFLOW:
            MOV r2, 0xffff                      // to test for underflow
            QBEQ DERIVATIVE, r16.w2, r2.w0      // number is just negative, no underflow here
            MOV r16, 0xffff0000                 // min output, twos complement
          QBA DERIVATIVE

        INTEGRAL_RESET:
          MOV r16, 0x0                  // integrator reset

      DERIVATIVE:
        SUB r28, r19, r18               // calculate derivative
        MOV r29, r14                    // move DGAIN to MAC
        XOUT 0, r28, 8                  // multiply
        XIN 0, r26, 8                   // load in product to r26 and r27
        MOV r17, r26                    // move lower product to r17
        MOV r18, r19                    // error signal to previous error signal

      COMBINE_PID:
        ADD r2, r15, r16                // ADD P_RESULT and I_RESULT
        ADD r2, r2, r17                 // ADD D_RESULT
        QBBS CLOSED_LOOP_OUT, r4.t17    // skip below step if locking to positive slope 
        RSB r2, r2, 0                   // Reverse Unsigned Integer Subtract r7 = 0 - r7

        CLOSED_LOOP_OUT:
          ADD r7, r7.w0, r2             // ADD PID result to DAC output

        OVERFLOW_TEST:                  // test for PID overflow
          QBEQ ENDLOOP, r7.w2, 0        // no overflow or underflow
          QBBS UNDERFLOW, r7.t31        // number is negative therefore underflow
          OVERFLOW:
            MOV r7, 0xffff              // max output
            QBA ENDLOOP
          UNDERFLOW:
            MOV r7, 0x0                 // min output

/* SPI SEND DATA TO DAC */
    ENDLOOP:
      SPI_BUILDWORD:                    // prepare data for sending to DAC

      SPI_CHECK:                        // Check transmitter register status
        LBBO r2, r22, SPI_CH1STAT, 4
        QBBC SPI_END, r2.t1             // skip if still transmitting previous data

      SPI_SEND:
        SBBO r7, r22, SPI_TX1, 4        // word to transmit 
      SPI_END:

/* STORING DATA TO MEMORY AND INTERRUPT IN HANDLING */
    WRITEDATA:
      QBEQ ARM_INTERRUPT, r3.w2, 0      // skip write if disabled
      SBCO r6, c24, r3.w0, 4            // store data in PRU_DATARAM_1, offset r3.w0
      ADD r3.w0, r3.w0, 4               // increment counter
      QBA INT_CHECK                     // if writing enabled, no need for ARM interrupt check
    
    ARM_INTERRUPT:
      QBBC LOAD_DATA, r31.t30           // skip this if no interrupt
      MOV r3.w2, 1                      // enable writing
      SET r5, 3                         // set bit 3 to enable CYCLE timer
      SBCO r5, c28, 0, 4                // store CYCLE settings 
    
    CLEAR_ARM_INTERRUPT:
      MOV r2, 1<<18                     // write 1 to clear event
      MOV r1, SECR0                     // System Event Status Enable/Clear register
      SBCO r2, C0, r1, 4                // C0 is interrupt controller
      QBA INT_CHECK

/* END OF LOOP AND INTERRUPT OUT HANDLING */
    LOAD_DATA:
      JAL r23.w0, LOAD_PARAMETERS       // load parameters

    INT_CHECK:
      QBNE WAIT, r3.w0, r4.w0           // check number of samples taken
    
    INTERRUPT:                          // memory full
      MOV r31.b0, PRU_INTERRUPT | PRU_EVTOUT_0
    
      CLR r5, 3                         // clear bit 3 to disable CYCLE
      SBCO r5, C28, 0, 4                // store CYCLE settings
      MOV r2, 0x0                       // 0x0 to reset CYCLE count to zero
      SBCO r2, C28, CYCLE, 4            // clear CYCLE counter
    
      MOV r3, 0                         // start from 0th memory address; disable writing
    
      QBA WAIT

/* HANDLE DEINITIALIZATION AND QUIT */
    DEINIT:
      MOV r2, 0x0                       // disable STEPENABLE
      SBBO r2, r20, STEPENABLE, 4       // store STEPENABLE settings
    
    QUIT:
      HALT

/* SUBROUTINES UTILISING JAL */

    LOAD_PARAMETERS:
      AND r4.w2, r4.w2, 0b100           // clear all bits to be changed, so that OR works

      LBCO r2, c25, OPENCLOSE, 4        // r4.w2 is booleans, description below
      AND r2, r2, 0x1                   // bitmask to ensure bit[0] only (bool)
      OR r4.w2, r4.w2, r2.w0            // bit[16]: OPEN / CLOSED LOOP          (0 = CLOSED LOOP) 

      LBCO r2, c25, LOCKSLOPE, 4
      AND r2, r2, 0x1                   // bitmask to ensure single bit only
      LSL r2, r2, 1                     // logical shift left
      OR r4.w2, r4.w2, r2.w0            // bit[17] - LOCK SLOPE                  (0 = NEGATIVE SLOPE)
                                        // bit[18] - OPEN SCAN UP / DOWN         (0 = DOWN)
      LBCO r2, c25, IRESET, 4
      AND r2, r2, 0x1
      LSL r2, r2, 3
      OR r4.w2, r4.w2, r2.w0            // bit[19] - INTEGRAL RESET              (1 = RESET)

      LBCO r2, c25, TIME_XY, 4
      AND r2, r2, 0x1
      LSL r2, r2, 4
      OR r4.w2, r4.w2, r2.w0            // bit[20] - TIME or XY mode             (0 = TIME)

      LBCO r10, c25, OPENAMPL, 2        // load open loop ramp amplitude
      MOV r2, 0x7fff                    // ensure maximum amplitude not exceeded
      AND r10, r10, r2                
      LBCO r11.w2, c25, XLOCK, 2        // load PID controller DAC set point (for scan to)
      LBCO r11.w0, c25, YLOCK, 2        // load PID controller set point
      LBCO r12, c25, PGAIN, 4           // load PGAIN
      LBCO r13, c25, IGAIN, 4           // load IGAIN
      LBCO r14, c25, DGAIN, 4           // load DGAIN
      JMP r23.w0                        // RETURN

    SETUP_SPI:
      #include "setup_spi.p"            // setup SPI for data out to DAC
      JMP r23.w0

    SETUP_ADC:
      #include "setup_adc.p"            // ADC definitions, setup and start ADC
      JMP r23.w0
