/* PRU_1 OSCILLOSCOPE CODE */
/* Copyright (C) 2015 Samuel Ruddell */

.origin 0

#define PRU_INTERRUPT 		32
#define PRU_EVTOUT_0		3
#define PRU_DATARAM_1 		0x00000000

#define CTPPR_0			0x24028
#define SECR0                   0x280

/* PERIPHERAL INITIALIZATION */
    INIT:
      // enable OCP master ports
      LBCO r20, C4, 4, 4		// SYSCFG register
      CLR r20, r0, 4		        // enable OCP master ports
      SBCO r20, C4, 4, 4		// store SYSCFG settings
    
      MOV r1, CTPPR_0		        // Constant Table Programmable Pointer
      MOV r2, 0x240			// set up C28 as CTRL register pointer
      SBBO r2, r1, 0, 4	                // store address for easy reference later
    
      LBCO r20, C28, 0, 4		// load in CYCLE settings
      SET r20, 3			// set bit 3 to enable CYCLE
      SBCO r20, C28, 0, 4		// store CYCLE settings
    
      MOV r5.w0, 0			// step counter register
      MOV r5.w2, 0                      // disable writing until ready
      MOV r6, 2048 << 2		        // steps until interrupt * 4 (for 8192 bytes of memory)

    #include "setup_spi.p"              // setup SPI for data out to DAC
    #include "setup_adc.p"              // ADC definition, setup and start ADC

/* READ ADC AND PACK DATA */
    WAIT:
      LBBO r4, r2, FIFOCOUNT, 4	        // check for words in FIFO0
      QBEQ WAIT, r4, 0		        // WAIT until word present in FIFO0
    
    READ:
      LBCO r11, C28, 0xC, 4             // load in CYCLE COUNT
      LBBO r4, r3, 0, 4		        // load 4 bytes from FIFO into r4
    
    PACK:				// pack data into 32 bit register
      LSL r11, r11, 12		        // use bits[31:12] for time
      OR r11, r11, r4		        // pack as: time->bits[31:12], adc->bits[11:0]

/* HANDLE STORING DATA TO MEMORY */
    WRITEDATA:
      QBEQ ARM_INTERRUPT, r5.w2, 0      // skip write if disabled
      SBBO r11, r1, r5.w0, 4	        // store data in PRU_DATARAM_1
      ADD r5.w0, r5.w0, 4		// increment counter
      QBA INT_CHECK                     // if writing enabled, no need for ARM interrupt check
    
    ARM_INTERRUPT:                 
      QBBC INT_CHECK, r31.t30           // skip this if no interrupt
      MOV r5.w2, 1                      // enable writing
      SET r20, 3			// set bit 3 to enable CYCLE timer
      SBCO r20, C28, 0, 4		// store CYCLE settings 
    
    CLEAR_ARM_INTERRUPT:
      MOV r15, 1<<18                    // write 1 to clear event
      MOV r16, SECR0                    // System Event Status Enable/Clear register
      SBCO r15, C0, r16, 4              // C0 is interrupt controller
    
    INT_CHECK:
      QBNE WAIT, r5.w0, r6              // check number of samples taken
    
    INTERRUPT:                          // memory full
      MOV r31.b0, PRU_INTERRUPT | PRU_EVTOUT_0
    
      CLR r20, 3			// clear bit 3 to disable CYCLE
      SBCO r20, C28, 0, 4		// store CYCLE settings
      MOV r21, 0x0			// 0x0 to reset CYCLE count to zero
      SBCO r21, C28, 0xC, 4             // clear CYCLE counter
    
      MOV r5, 0                         // start from 0th memory address; disable writing
    
      QBA WAIT

/* HANDLE DEINITIALIZATION AND QUIT */
    DEINIT:
      MOV r4, 0x0			// disable STEPENABLE
      SBBO r4, r2, STEPENABLE, 4        // store STEPENABLE settings
    
    QUIT:
      HALT
