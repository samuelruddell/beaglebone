/* PRU_1 OSCILLOSCOPE CODE */
/* Copyright (C) 2015 Samuel Ruddell */

.origin 0

#define PRU_INTERRUPT 		32
#define PRU_EVTOUT_0		3

#define CTBIR0                  0x20    // Constant Table Block Index Register 0
#define CTPPR0			0x24028 // Constant Table Programmable Pointer 0
#define SECR0                   0x280

#define CYCLE			0xc	// CYCLE register

/* PERIPHERAL INITIALIZATION */
    INIT:
      // enable OCP master ports
      LBCO r2, c4, 4, 4			// SYSCFG register
      CLR r2, r0, 4		        // enable OCP master ports
      SBCO r2, c4, 4, 4			// store SYSCFG settings
    
      MOV r1, CTPPR0		        // Constant Table Programmable Pointer
      MOV r2, 0x240			// set up c28 as PRU CTRL register pointer
      SBBO r2, r1, 0, 4	                // store address for easy reference later

      MOV r2, 0x0
      SBCO r2, c28, CTBIR0, 4           // ensure c24 and c25 setup correctly
    
      MOV r3, 0				// step counter register, disable writing until ready
      MOV r4, 2048 << 2		        // steps until interrupt * 4 (for 8192 bytes of memory)

      LBCO r5, c28, 0, 4		// load in CYCLE settings
      SET r5, 3				// set bit 3 to enable CYCLE
      SBCO r5, c28, 0, 4		// store CYCLE settings
    
    #include "setup_spi.p"              // setup SPI for data out to DAC
    #include "setup_adc.p"              // ADC definition, setup and start ADC

/* READ ADC AND PACK DATA */
    WAIT:
      LBBO r2, r20, FIFOCOUNT, 4	// check for words in FIFO0
      QBEQ WAIT, r2, 0		        // WAIT until word present in FIFO0
    
    READ:
      LBCO r8, c28, CYCLE, 4            // load in CYCLE COUNT
      LBBO r9, r21, 0, 4		// load 4 bytes from FIFO into r9
    
    PACK:				// pack data into 32 bit register
      LSL r6, r8, 12		        // use bits[31:12] for time, store in r6
      OR r6, r6, r9		        // pack as: time->bits[31:12], adc->bits[11:0]

/* HANDLE STORING DATA TO MEMORY */
    WRITEDATA:
      QBEQ ARM_INTERRUPT, r3.w2, 0      // skip write if disabled
      SBCO r6, c24, r3.w0, 4	        // store data in PRU_DATARAM_1, offset r3.w0
      ADD r3.w0, r3.w0, 4		// increment counter
      QBA INT_CHECK                     // if writing enabled, no need for ARM interrupt check
    
    ARM_INTERRUPT:                 
      QBBC INT_CHECK, r31.t30           // skip this if no interrupt
      MOV r3.w2, 1                      // enable writing
      SET r5, 3				// set bit 3 to enable CYCLE timer
      SBCO r5, c28, 0, 4		// store CYCLE settings 
    
    CLEAR_ARM_INTERRUPT:
      MOV r2, 1<<18                    	// write 1 to clear event
      MOV r1, SECR0                    	// System Event Status Enable/Clear register
      SBCO r2, C0, r1, 4              	// C0 is interrupt controller
    
    INT_CHECK:
      QBNE WAIT, r3.w0, r4              // check number of samples taken
    
    INTERRUPT:                          // memory full
      MOV r31.b0, PRU_INTERRUPT | PRU_EVTOUT_0
    
      CLR r5, 3				// clear bit 3 to disable CYCLE
      SBCO r5, C28, 0, 4		// store CYCLE settings
      MOV r2, 0x0			// 0x0 to reset CYCLE count to zero
      SBCO r2, C28, CYCLE, 4           	// clear CYCLE counter
    
      MOV r3, 0                         // start from 0th memory address; disable writing
    
      QBA WAIT

/* HANDLE DEINITIALIZATION AND QUIT */
    DEINIT:
      MOV r2, 0x0			// disable STEPENABLE
      SBBO r2, r20, STEPENABLE, 4       // store STEPENABLE settings
    
    QUIT:
      HALT
