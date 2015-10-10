/* PRU_1 PID CONTROLLER CODE */
/* Copyright (C) 2015 Samuel Ruddell */

.origin 0

/* DEFINITIONS */
#include "pru.hp"

/* PERIPHERAL INITIALIZATION */
    INIT:
      LBCO r2, c4, 4, 4                 // SYSCFG register
      CLR r2, r2, 4                     // enable OCP master ports
      SBCO r2, c4, 4, 4                 // store SYSCFG settings

      MOV r2, 0x3                       // XFR shift enabled, give PRU1 scratch priority
      SBCO r2, c4, 0x34, 4              // store SPP settings (Scratch Pad Priority)

      MOV r1, CTPPR0                    // Constant Table Programmable Pointer
      MOV r2, 0x240                     // set up c28 as PRU CTRL register pointer
      SBBO r2, r1, 0, 4                 // store address for easy reference later

      MOV r2, 0x0
      SBCO r2, c28, CTBIR0, 4           // ensure c24 and c25 setup correctly
    
      MOV r3, 0                         // step counter register
      MOV r3.w2, 2048 << 2              // steps until interrupt * 4 (for 8192 bytes of memory)
      CLR r4.t31                        // disable writing until ready

      LBCO r5, c28, 0, 4                // load in CYCLE settings
      SET r5, 3                         // set bit 3 to enable CYCLE
      SBCO r5, c28, 0, 4                // store CYCLE settings

      XIN 0, r25, 1                     // load in MAC settings (multiply accumulate)
      CLR r25.t0                        // set up multiply-only mode
      XOUT 0, r25, 1                    // store MAC_mode to MAC

      JAL r23.w0, LOAD_PARAMETERS       // load parameters from memory subroutine
      MOV r7, r2.w2                     // Start DAC at scan point

      JAL r23.w0, SETUP_SPI             // setup SPI subroutine  
      JAL r23.w0, SETUP_ADC             // setup ADC subroutine 

/* READ ADC AND PACK DATA */
    WAIT:
      LBBO r2, r20, FIFOCOUNT, 4        // check for words in FIFO0
      QBEQ WAIT, r2, 0                  // WAIT until word present in FIFO0
    
    READ:
      LBCO r8, c28, CYCLE, 4            // load in CYCLE COUNT
      LBBO r9, r21, 0, 4                // load 4 bytes from FIFO into r9
    
    PACK:                               // pack DAC and ADC data into a single 32-bit register
      MOV r6.w2, r7.w0                  // DAC value
      MOV r6.w0, r9.w0                  // ADC value

/* OPEN LOOP */
      QBBC SEMICLOSEDLOOP, r4.t0        // do semi-closed / closed loop if bit[16] (open/closed loop) clear
    OPENLOOP:
      MOV r2, r10.w2                    // used to test whether amplitude reached below
      QBBC SCANDOWN, r4.t16             // scan down instead

      SCANUP:
        ADD r2, r2, r10.w0              // test whether upper amplitude reached 
        QBLE TOGGLE_DIRECTION, r7, r2   // toggle direction if upper amplitude reached
        MOV r2, 0xffff
        QBEQ TOGGLE_DIRECTION, r7, r2   // toggle direction if max amplitude reached
        ADD r7, r7, 1                   // increase DAC output
        QBA ENDLOOP        

      SCANDOWN:
        SUB r2, r2, r10.w0              // test whether lower amplitude reached
        QBBC SCANDOWN_CONT, r2.t31      // check if lower amplitude is negative 
        MOV r2, 0x0                     // if negative set lower amplitude as zero 
        SCANDOWN_CONT:
          QBGE TOGGLE_DIRECTION, r7, r2 // toggle direction if lower amplitude reached
          SUB r7, r7, 1                 // decrease DAC output
          QBA ENDLOOP        

      TOGGLE_DIRECTION:
        MOV r7, r2                      // MOV min/max amplitude to DAC output
        XOR r4.b2, r4.b2, 1             // TOGGLE scan UP/DOWN

      LOAD_ADC_PARAMETERS:              // LOAD new ADC parameters on open loop only
        JAL r23.w0, SETUP_ADC           // setup ADC subroutine 
        SET r4.t17                      // prime semiclosed loop
        QBA ENDLOOP

/* SEMI-CLOSED LOOP */
      SEMICLOSEDLOOP:                   // Scan DAC to XLOCK before enabling closed loop 
        QBBC CLOSEDLOOP, r4.t17         // no SEMI-CLOSED LOOP
        QBLT SEMI_SCANDOWN, r7.w0, r11.w2        

        SEMI_SCANUP:
          ADD r7, r7, 1
          QBA SEMI_TRANSITION

        SEMI_SCANDOWN:
          SUB r7, r7, 1

        SEMI_TRANSITION:
        QBNE ENDLOOP, r11.w2, r7.w0     // continue semi-closed loop if values not equal
                                        // otherwise transition to closed loop
        SUB r18, r9, r11.w0             // set an initial value for previous error signal
        CLR r4.t17                      // unprime semi-closed loop

        JAL r23.w0, SETUP_ADC           // setup adc for closed loop

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
        QBBS INTEGRAL_RESET, r4.t1      // skip this if integrator reset active
        MOV r29, r13                    // move IGAIN to MAC
        XOUT 0, r28, 8                  // multiply
        XIN 0, r26, 8                   // load in product to r26 and r27
        ADD r16, r16, r26               // integrate lower product into r16

        QBBS AUTO_INT_RESET_TEST, r4.t2         // if auto integrator reset enabled, check for that instead
        INT_OVERFLOW_TEST:                      // test for integrator overflow
          QBEQ DERIVATIVE, r16.w2, 0            // no overflow or underflow
          QBBS INT_UNDERFLOW, r16.t31           // number is negative, check for underflow
          INT_OVERFLOW:
            MOV r16, 0xffff                     // overflow occurred, set max output
            QBA DERIVATIVE
          INT_UNDERFLOW:
            MOV r2, 0xffff                      // to test for underflow
            QBEQ DERIVATIVE, r16.w2, r2.w0      // number is just negative, no underflow here
            MOV r16, 0xffff0000                 // min output, twos complement
          QBA DERIVATIVE

        AUTO_INT_RESET_TEST:                    // test for integrator overflow
          QBBS AUTO_UNDERFLOW, r16.t31          // integrator is negative, test for underflow
          AUTO_OVERFLOW:
            QBGT DERIVATIVE, r16.w0, r24.w2     // no overflow
            QBA INTEGRAL_RESET                  // overflow has occurred, reset integrator
          AUTO_UNDERFLOW:
            QBLT DERIVATIVE, r16.w0, r24.w0     // no underflow
                                                // else underflow has occurred, proceed to reset integrator
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
        QBBS CLOSED_LOOP_OUT, r4.t3     // skip below step if locking to positive slope 
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
      QBBC ARM_INTERRUPT, r4.t31        // skip write if disabled
      SBCO r8, c25, r3.w0, 4            // store time in PRU_DATARAM_0, offset r3.w0
      SBCO r6, c24, r3.w0, 4            // store packed data in PRU_DATARAM_1, offset r3.w0
      ADD r3.w0, r3.w0, 4               // increment counter
      QBA INT_CHECK                     // if writing enabled, no need for ARM interrupt check
    
    ARM_INTERRUPT:
      QBBC LOAD_DATA, r31.t30           // skip this if no interrupt
      SET r4.t31                        // enable writing
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
      QBNE WAIT, r3.w2, r3.w0           // check number of samples taken
    
    INTERRUPT:                          // memory full
      MOV r31.b0, PRU_INTERRUPT | PRU_EVTOUT_0
    
      CLR r5, 3                         // clear bit 3 to disable CYCLE
      SBCO r5, C28, 0, 4                // store CYCLE settings
      MOV r2, 0x0                       // 0x0 to reset CYCLE count to zero
      SBCO r2, C28, CYCLE, 4            // clear CYCLE counter
    
      MOV r3.w0, 0                      // start from 0th memory address
      CLR r4.t31                        // disable writing
    
      QBA WAIT

/* HANDLE DEINITIALIZATION AND QUIT */
    DEINIT:
      MOV r2, 0x0                       // disable STEPENABLE
      SBBO r2, r20, STEPENABLE, 4       // store STEPENABLE settings
    
    QUIT:
      HALT

/* SUBROUTINES UTILISING JAL */

    LOAD_PARAMETERS:
      MOV r1, 0x00010000                // PRUSS0_SHARED_MEMORY
      LBBO r4.w0, r1, BOOLEANS, 2       // load externally set booleans into r4.w0
                                        // bit[0]: OPEN / CLOSED LOOP
                                        // bit[1]: INTEGRATOR RESET
                                        // bit[2]: AUTOMATIC INTEGRATOR RESET ON OVERFLOW / UNDERFLOW
                                        // bit[3]: LOCK SLOPE

                                        // internally set booleans stored in r4.w2
                                        // bit[16]: OPEN LOOP SCAN UP / DOWN
                                        // bit[17]: SEMI-CLOSED LOOP STATUS
                                        // bit[31]: WRITE OUT ENABLE

      LBBO r10.w0, r1, OPENAMPL, 2      // load open loop ramp amplitude
      LBBO r10.w2, r1, SCANPOINT, 2     // load open scan point
      LBBO r11.w2, r1, XLOCK, 2         // load PID controller DAC set point (for scan to)
      LBBO r11.w0, r1, YLOCK, 2         // load PID controller set point
      LBBO r12, r1, PGAIN, 4            // load PGAIN
      LBBO r13, r1, IGAIN, 4            // load IGAIN
      LBBO r14, r1, DGAIN, 4            // load DGAIN
      LBBO r24.w2, r1, POS_IRESET, 2    // load INTEGRATOR AUTO OVERFLOW VALUE
      LBBO r24.w0, r1, NEG_IRESET, 2    // load INTEGRATOR AUTO UNDERFLOW VALUE
      JMP r23.w0                        // RETURN

    SETUP_SPI:
      #include "setup_spi.p"            // setup SPI for data out to DAC
      JMP r23.w0

    SETUP_ADC:
      #include "setup_adc.p"            // ADC definitions, setup and start ADC
      JMP r23.w0
