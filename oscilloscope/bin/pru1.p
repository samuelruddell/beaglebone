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
      MOV r7, r10.w2                    // Start DAC at scan point

      JAL r23.w0, SETUP_SPI             // setup SPI subroutine  
      JAL r23.w0, SETUP_ADC             // setup ADC subroutine 

/* PRE-LOOP */
    BEGINLOOP:
      QBBC SEMICLOSEDLOOP, r4.t0        // do semi-closed / closed loop if bit[0] (open/closed loop) clear
      QBBS OPENLOOP, r4.t17             // do open loop transition for first time open loop

/* OPEN LOOP TRANSITION */
    TRANSIT_OPEN:
      JAL r23.w0, LOAD_PARAMETERS       // load parameters from memory subroutine
      MOV r7, r10.w2                    // Start DAC at scan point
      JAL r23.w0, SETUP_ADC             // setup ADC subroutine  

      MOV r2, 0x8000                    // reset fast output to 0x8000
      SET r2.t16
      SBBO r2, r22, SPI_TX0, 4

      MOV r2, r10.w2                    // reset slow output to SCAN POINT
      SET r2.t17               
      SBBO r2, r22, SPI_TX0, 4

      MOV r3.w0, 0                      // clear step counter register
      CLR r4.t31                        // disable writing until ready

      SET r4.t17                        // prime semi-closed loop

/* OPEN LOOP (SLOW DAC) */
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
      QBA SCAN_LOGIC                      // skip write step

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
          QBNE SEMICLOSEDLOOP, r11.w2, r7.w0    // continue semi-closed loop if values not equal
                                                // otherwise transition to closed loop
          CLR r4.t17                    // unprime semi-closed loop
          MOV r6.b2, r6.b3              // prepare slow accumulator
          MOV r6.w0, 0x0
          MOV r24, 0x8000               // initialise previous fast DAC value
          
          JAL r23.w0, SETUP_ADC         // setup adc for closed loop

/* CLOSED LOOP */
    CLOSEDLOOP:
      XOUT 10, r4, 44                   // send data to PRU 0

    /* CALCULATE FAST PROPORTIONAL */
      FAST_PROPORTIONAL:
        XOUT 0, r28, 8                  // multiply
        XIN 0, r26, 8                   // load in product to r26 and r27
        QBBC FAST_PPOS, r26.t31         // result is positive
        FAST_PNEG:
          RSB r26, r26, 0               // make negative result positive to prevent rounding to negative infinity
          LSR r26, r26, 15              // round result correctly
          RSB r26, r26, 0               // make result negative again
          QBA SPI
        FAST_PPOS:
          LSR r26, r26, 15              // round result

      SPI:                              // prepare data for sending to DAC AD5545      
        MOV r2, 0x8000
        ADD r2, r2, r26.w0              // calculate DAC output
        SET r2.t16

      QBEQ SPI_END, r2, r24             // no need to use SPI if result is the same
      SPI_SEND:
        SBBO r2, r22, SPI_TX0, 4        // word to transmit 
        MOV r24, r2                     // set previous DAC value

      SPI_END:
        JAL r23.w0, LOAD_BOOLS          // load parameters from memory subroutine

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

      LBBO r12, r1, PGAIN, 4            // load PGAIN
      LBBO r13, r1, IGAIN, 4            // load IGAIN
      LBBO r14, r1, DGAIN, 4            // load DGAIN
      LBBO r29, r1, PGAIN2, 4           // load PGAIN (FAST)

      JMP r23.w0                        // RETURN

    /* LOAD PARAMETERS FOR CLOSED LOOP ONLY */
    LOAD_BOOLS:
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
