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

      MOV r2, 0x1                       // XFR shift disabled, PRU1 has scratch priority
      SBCO r2, c4, 0x34, 4              // store SPP settings (Scratch Pad Priority)

      MOV r1, CTPPR0                    // Constant Table Programmable Pointer
      MOV r2, 0x240                     // set up c28 as PRU CTRL register pointer
      SBBO r2, r1, 0, 4                 // store address for easy reference later

      MOV r2, 0x0
      SBCO r2, c28, CTBIR0, 4           // ensure c24 and c25 setup correctly
    
      MOV r3, 0                         // step counter register
      MOV r3.w2, 2048 << 2              // steps until interrupt * 4 (for 8192 bytes of memory)
      CLR r4.t31                        // disable writing until ready

      XIN 0, r25, 1                     // load in MAC settings (multiply accumulate)
      CLR r25.t0                        // set up multiply-only mode
      XOUT 0, r25, 1                    // store MAC_mode to MAC

      LBCO r25, c28, 0, 4               // load in CYCLE settings
      SET r25, 3                        // set bit 3 to enable CYCLE
      SBCO r25, c28, 0, 4               // store CYCLE settings

      JAL r23.w0, LOAD_PARAMETERS       // load parameters from memory subroutine
      MOV r7, r2.w2                     // Start DAC at scan point

      JAL r23.w0, SETUP_SPI             // setup SPI subroutine  
      JAL r23.w0, SETUP_ADC             // setup ADC subroutine 

/* READ ADC AND PACK DATA */
/*    
    WAIT:
      LBBO r2, r20, FIFOCOUNT, 4        // check for words in FIFO0
      QBEQ WAIT, r2, 0                  // WAIT until word present in FIFO0
    
    READ:
      LBCO r8, c28, CYCLE, 4            // load in CYCLE COUNT
      LBBO r9, r21, 0, 4                // load 4 bytes from FIFO into r9
    
    XFR_DATA:
      XOUT 10, r4, 32                   // send booleans, ADC, lock point to PRU_0

    PACK:                               // pack DAC and ADC data into a single 32-bit register
      MOV r9.w2, r7.w0                  // DAC value
*/

/* PRE-LOOP */
    BEGINLOOP:
      QBBC SEMICLOSEDLOOP, r4.t0        // do semi-closed / closed loop if bit[0] (open/closed loop) clear
      
/* OPEN LOOP */
    OPENLOOP:
      /* READ ADC AND PACK DATA */
      OPEN_WAIT:
        LBBO r2, r20, FIFOCOUNT, 4      // check for words in FIFO0
        QBEQ OPEN_WAIT, r2, 0           // WAIT until word present in FIFO0
    
      OPEN_READ:
        LBCO r8, c28, CYCLE, 4          // load in CYCLE COUNT
        LBBO r9, r21, 0, 4              // load 4 bytes from FIFO into r9
    
      OPEN_PACK:                        // pack DAC and ADC data into a single 32-bit register
        MOV r9.w2, r7.w0                // DAC value

      /* OSCILLOSCOPE TRIGGER LOGIC */
      CLR r4.t29                          // clear write this step flag
      QBBC SCAN_LOGIC, r4.t30             // no need for writing if trigger not reached
      QBEQ OPEN_ACCUM_FULL, r6.w0, r6.w2  // if number of accumulations reached
      ADD r6.w0, r6.w0, 1                 // increase accumulation
      QBA SCAN_LOGIC                      // skip gain calculation, SPI out, memory storing and interrupt handling

      OPEN_ACCUM_FULL:
        MOV r6.w0, 0x0                  // clear accumulator counts
        LSR r6.w2, r10.w0, 10           // prepare number of skips (assumes DAC steps of 1)
        SET r4.t29                      // write this step

      /* OPEN LOOP SCANNING LOGIC */
      SCAN_LOGIC:
        MOV r2, r10.w2                  // open loop scan point for condition checking below
        QBBC SCANDOWN, r4.t16           // scan down instead

      SCANUP:
        ADD r2, r2, r10.w0              // test whether upper amplitude reached 
        QBLE TOGGLE_DIRECTION, r7, r2   // toggle direction if upper amplitude reached
        MOV r2, 0xffff
        QBEQ TOGGLE_DIRECTION, r7, r2   // toggle direction if max amplitude reached
        ADD r7, r7, 1                   // else increase DAC output
        QBA ENDOPENLOOP        

      SCANDOWN:
        SUB r2, r2, r10.w0              // test whether lower amplitude reached
        QBBC SCANDOWN_CONT, r2.t31      // check if lower amplitude is negative 
        MOV r2, 0x0                     // if negative set lower amplitude as zero 
        SCANDOWN_CONT:
          QBGE PRE_TOGGLE_DIR, r7, r2   // toggle direction if lower amplitude reached
          SUB r7, r7, 1                 // else decrease DAC output
          QBA ENDOPENLOOP        

      PRE_TOGGLE_DIR:
        QBBC TOGGLE_DIRECTION, r4.t31   // no writing yet
        SET r4.t30                      // trigger for begin write out

      TOGGLE_DIRECTION:
        MOV r7, r2                      // MOV min/max amplitude to DAC output
        XOR r4.b2, r4.b2, 1             // TOGGLE scan UP/DOWN
      LOAD_ADC_PARS:                    // LOAD new ADC parameters on open loop only
        JAL r23.w0, SETUP_ADC           // setup ADC subroutine (only on open loop toggle direction)
        SET r4.t17                      // prime semiclosed loop

      ENDOPENLOOP:
      /* OPEN LOOP SPI OUT */
        SPI_OPEN_BUILDWORD:               // prepare data for sending to DAC AD5545
          MOV r1, r7.w0 
          SET r1.t17                      // target slow DAC output
  
        SPI_OPEN_SEND:
          SBBO r1, r22, SPI_TX0, 4        // word to transmit 

        SPI_OPEN_END:
          QBBS WRITEDATA, r4.t29
          QBBC ARM_INTERRUPT, r4.t31      // check interrupt if write disabled
          QBA INT_CHECK

/* STORING DATA TO MEMORY AND INTERRUPT IN HANDLING */
    WRITEDATA:
      QBBC ARM_INTERRUPT, r4.t31        // skip write if disabled
      SBCO r8, c25, r3.w0, 4            // store time in PRU_DATARAM_0, offset r3.w0
      SBCO r9, c24, r3.w0, 4            // store packed data in PRU_DATARAM_1, offset r3.w0
      ADD r3.w0, r3.w0, 4               // increment counter
      QBA INT_CHECK                     // if writing enabled, no need for ARM interrupt check
    
    ARM_INTERRUPT:
      QBBC LOAD_DATA, r31.t30           // skip this if no interrupt
      SET r4.t31                        // enable writing
      SET r25, 3                        // set bit 3 to enable CYCLE timer
      SBCO r25, c28, 0, 4               // store CYCLE settings 
    
    CLEAR_ARM_INTERRUPT:
      MOV r2, 1<<18                     // write 1 to clear event
      MOV r1, SECR0                     // System Event Status Enable/Clear register
      SBCO r2, c0, r1, 4                // c0 is interrupt controller
      QBA INT_CHECK

/* END OF LOOP AND INTERRUPT OUT HANDLING */
    LOAD_DATA:
      JAL r23.w0, LOAD_PARAMETERS       // load parameters

    INT_CHECK:
      QBNE BEGINLOOP, r3.w2, r3.w0      // check number of samples taken
    
    INTERRUPT:                          // when memory full
      MOV r31.b0, PRU_INTERRUPT | PRU_EVTOUT_0
    
      CLR r25, 3                        // clear bit 3 to disable CYCLE
      SBCO r25, c28, 0, 4               // store CYCLE settings
      MOV r2, 0x0                       // 0x0 to reset CYCLE count to zero
      SBCO r2, c28, CYCLE, 4            // clear CYCLE counter
    
      MOV r3.w0, 0                      // start from 0th memory address
      AND r4.b3, r4.b3, 0b00011111      // CLR r4.t29-t31 to disable writing

      QBA BEGINLOOP

/* SEMI-CLOSED LOOP */
      SEMICLOSEDLOOP:                     // Scan DAC to XLOCK before enabling closed loop 
        /* READ ADC AND PACK DATA */
        WAIT:
          LBBO r2, r20, FIFOCOUNT, 4      // check for words in FIFO0
          QBEQ WAIT, r2, 0                // WAIT until word present in FIFO0
    
        READ:
          LBBO r9, r21, 0, 4              // load 4 bytes from FIFO into r9
    
        PACK:                             // pack DAC and ADC data into a single 32-bit register
          MOV r9.w2, r7.w0                // DAC value

        QBBC CLOSEDLOOP, r4.t17           // no SEMI-CLOSED LOOP
        QBLT SEMI_SCANDOWN, r7.w0, r11.w2        

        SEMI_SCANUP:
          ADD r7, r7, 1
          QBA SEMI_TRANSITION

        SEMI_SCANDOWN:
          SUB r7, r7, 1

        SEMI_TRANSITION:
          QBNE ENDLOOP, r11.w2, r7.w0   // continue semi-closed loop if values not equal
                                        // otherwise transition to closed loop
          SUB r18, r9.w0, r11.w0        // set an initial value for previous error signal
          CLR r4.t17                    // unprime semi-closed loop
          MOV r6.b2, r6.b3              // prepare slow accumulator
          MOV r5, 0x0
          MOV r6.w0, 0x0
          
          MOV r16, 0x0                  // reset integrator

          JAL r23.w0, SETUP_ADC         // setup adc for closed loop

/* CLOSED LOOP */
    CLOSEDLOOP:
    /* CALCULATE FAST PROPORTIONAL */
      FAST_PROPORTIONAL:
        XIN 11, r29, 4                  // move PGAIN to MAC
        XOUT 0, r28, 8                  // multiply
        XIN 0, r26, 8                   // load in product to r26 and r27
        QBBC FAST_PPOS, r26.t31         // result is positive
        FAST_PNEG:
          RSB r15, r26, 0               // make negative result positive to prevent rounding to negative infinity
          LSR r15, r15, 15              // round result correctly
          RSB r15, r15, 0               // make result negative again
          QBA INTEGRAL
        FAST_PPOS:
          LSR r15, r26, 15              // store lower product in r15 with LSR

    /* ACCUMULATION AVERAGING LOGIC */
        QBEQ ACCUM_PREP, r6.b2, 0x0     // skip accumulator if no accumulation called for
        ADD r5, r5, r9.w0               // add current ADC reading to accumulator
        ADD r6.w0, r6.w0, 1             // increase accumulation
        QBBS ACCUM_FULL, r6, r6.b2      // if number of accumulations reached (powers of 2)
        QBA LOAD_DATA                   // skip gain calculation, SPI out, memory storing and interrupt handling

        ACCUM_FULL:
          LSR r5, r5, r6.b2             // average all values in r5 (floor remainder)
          MOV r9.w0, r5.w0              // move averaged ADC value to r9.w0 for processing
          MOV r5, 0x0                   // clear accumulator
          MOV r6.w0, 0x0                // clear accumulator counts

        ACCUM_PREP:
          MOV r6.b2, r6.b3              // number of averages may have changed due to LOAD_PARAMETERS

    /* PID LOGIC */
      PERFORM_CLOSED_LOOP:
        SUB r19, r9.w0, r11.w0          // calculate error signal as ADC - YLOCK
        MOV r28, r19                    // error signal value to MAC as operand 1

      PROPORTIONAL:
        MOV r29, r12                    // move PGAIN to MAC
        XOUT 0, r28, 8                  // multiply
        XIN 0, r26, 8                   // load in product to r26 and r27
        QBBC PPOS, r26.t31              // result is positive
        PNEG:
          RSB r15, r26, 0               // make negative result positive to prevent rounding to negative infinity
          LSR r15, r15, 15              // round result correctly
          RSB r15, r15, 0               // make result negative again
          QBA INTEGRAL
        PPOS:
          LSR r15, r26, 15              // store lower product in r15 with LSR

      INTEGRAL:
        QBBS INTEGRAL_RESET, r4.t1      // skip this if integrator reset active
        MOV r29, r13                    // move IGAIN to MAC
        XOUT 0, r28, 8                  // multiply
        XIN 0, r26, 8                   // load in product to r26 and r27
        QBBC IPOS, r26.t31              // result is positive
        INEG:
          RSB r2, r26, 0                // make negative result positive to prevent rounding to negative infinity
          LSR r2, r2, 15                // round result correctly
          RSB r2, r2, 0                 // make result negative again
          QBA INTEGRATE
        IPOS:
          LSR r2, r26, 15               // store lower product in r2 with LSR

        INTEGRATE:
          ADD r16, r16, r2              // integrate into r16

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
                                                // else underflow has occurred, reset integrator
        INTEGRAL_RESET:
          MOV r16, 0x0                  // integrator reset

      DERIVATIVE:
        SUB r28, r19, r18               // calculate derivative
        MOV r29, r14                    // move DGAIN to MAC
        XOUT 0, r28, 8                  // multiply
        XIN 0, r26, 8                   // load in product to r26 and r27
        QBBC DPOS, r26.t31              // result is positive
        DNEG:
          RSB r17, r26, 0               // make negative result positive to prevent rounding to negative infinity
          LSR r17, r17, 15              // round result correctly
          RSB r17, r17, 0               // make result negative again
          QBA DERIV_END
        DPOS:
          LSR r17, r26, 15              // store lower product in r15 with LSR

        DERIV_END:
          MOV r18, r19                  // error signal to previous error signal

      COMBINE_PID:
        ADD r2, r15, r16                // ADD P_RESULT and I_RESULT
        ADD r2, r2, r17                 // ADD D_RESULT
        QBBS CLOSED_LOOP_OUT, r4.t3     // skip below step if locking to positive slope 
        RSB r2, r2, 0                   // Reverse Unsigned Integer Subtract r2 = 0 - r2

        CLOSED_LOOP_OUT:
          ADD r1, r7.w0, r2             // ADD PID result to DAC output
        
        OVERFLOW_TEST:                  // test for PID overflow
          QBEQ ENDCLOSED, r1.w2, 0      // no overflow or underflow
          QBBS UNDERFLOW, r1.t31        // number is negative therefore underflow
          OVERFLOW:
            MOV r1, 0xffff              // max output
            QBA ENDCLOSED
          UNDERFLOW:
            MOV r1, 0x0                 // min output

        ENDCLOSED:                      
          MOV r9.w2, r1.w0              // pack correct value for oscilloscope
          SET r1.t17
          QBA SPI_SEND

/* SPI SEND DATA TO DAC */
    ENDLOOP:
      SPI_BUILDWORD:                    // prepare data for sending to DAC AD5545      
        MOV r1, r7.w0
        SET r1.t17

      SPI_SEND:
        SBBO r1, r22, SPI_TX0, 4        // word to transmit 
      SPI_END:

        JAL r23.w0, LOAD_CLOSED_PARAMETERS       // load parameters from memory subroutine

      QBA BEGINLOOP

/* HANDLE DEINITIALIZATION AND QUIT */
    DEINIT:
      MOV r2, 0x0                       // disable STEPENABLE
      SBBO r2, r20, STEPENABLE, 4       // store STEPENABLE settings
    
    QUIT:
      HALT

/* SUBROUTINES UTILISING JAL */
  /* LOAD PARAMETERS */
    LOAD_PARAMETERS:
      MOV r1, 0x00010000                // PRUSS0_SHARED_MEMORY

      LBBO r4.w0, r1, BOOLEANS, 2       // load externally set booleans into r4.w0
                                        // bit[0]: OPEN / CLOSED LOOP
                                        // bit[1]: INTEGRATOR RESET
                                        // bit[2]: AUTOMATIC INTEGRATOR RESET ON OVERFLOW / UNDERFLOW
                                        // bit[3]: LOCK SLOPE
                                        // bit[15]: ENABLE FAST DAC

                                        // internally set booleans stored in r4.w2
                                        // bit[16]: OPEN LOOP SCAN UP / DOWN
                                        // bit[17]: SEMI-CLOSED LOOP STATUS
                                        // bit[29]: OPEN LOOP WRITE THIS STEP
                                        // bit[30]: OPEN LOOP WRITE TRIGGER
                                        // bit[31]: WRITE OUT ENABLE

      LBBO r6.b3, r1, SLOW_ACCUM, 1     // load number of accumulations for slow DAC
      LBBO r10, r1, OPEN_POINT_AMPL, 4  // load open loop ramp scan point and amplitude
      LBBO r11, r1, XLOCK_YLOCK, 4      // w2: DAC set point (for scan to)
                                        // w0: ADC set point

      LBBO r29, r1, PGAIN2, 4           // load PGAIN2
      XOUT 11, r29, 4                   // store PGAIN2 in r29 broadside memory bank 11

      LBBO r12, r1, PGAIN, 4            // load PGAIN
      LBBO r13, r1, IGAIN, 4            // load IGAIN
      LBBO r14, r1, DGAIN, 4            // load DGAIN
      LBBO r24, r1, IRESET_POS_NEG, 4   // load INTEGRATOR AUTO OVERFLOW AND UNDERFLOW VALUES

      JMP r23.w0                        // RETURN

    /* LOAD PARAMETERS FOR CLOSED LOOP ONLY */
    LOAD_CLOSED_PARAMETERS:
      MOV r1, 0x00010000                // PRUSS0_SHARED_MEMORY

      LBBO r4.w0, r1, BOOLEANS, 2       // load externally set booleans into r4.w0
      SET r4.t15

      JMP r23.w0                        // RETURN

  /* SETUP SPI*/
    SETUP_SPI:
      #include "setup_spi.p"            // setup SPI for data out to DAC
      JMP r23.w0

  /* SETUP ADC*/
    SETUP_ADC:
      #include "setup_adc.p"            // ADC definitions, setup and start ADC
      JMP r23.w0
