/* PRU_1 OSCILLOSCOPE CODE */
/* Copyright (C) 2015 Samuel Ruddell */

.origin 0

#define PRU_INTERRUPT 		32
#define PRU_EVTOUT_0		3
#define PRU_DATARAM_1 		0x00000000

#define ADC_      		0x44e0d000
#define CTRL 	        	0x040
#define CLKDIV			0x04c
#define STEPENABLE 		0x054
#define STEPCONFIG1      	0x064
#define FIFOCOUNT		0x0e4
#define FIFO 		        0x100

#define CTPPR_0			0x24028

INIT:

  // enable OCP master ports
  LBCO r0, C4, 4, 4		// SYSCFG register
  CLR r0, r0, 4			// enable OCP master ports
  SBCO r0, C4, 4, 4

  MOV r1, CTPPR_0		// Constant Table Programmable Pointer Table
  MOV r2, 0x240			// set up C28 as CTRL register pointer
  SBBO r2, r1, 0, 4	        // store address easy reference later

  LBCO r2, C28, 0, 4		// load in CYCLE settings
  SET r2, 3			// set bit 3 to enable CYCLE
  SBCO r2, C28, 0, 4		// store CYCLE settings

  MOV r5, 0			// step counter register
  MOV r6, 2048 << 2		// steps until interrupt * 4

ADC_INIT:
  MOV r1, PRU_DATARAM_1		// DATARAM address
  MOV r2, ADC_		        // ADC address
  MOV r3, ADC_ | FIFO		// FIFO0 address

  // edit CTRL register
  MOV r4, 0x4			// Make step configuration registers writable, disable TSC_ADC_SS
  SBBO r4, r2, CTRL, 4		// Store configuration to ADC_CTRL register

  // edit CLKDIV register
  MOV r4, 0x0			// ADC clock divisor = 1
  SBBO r4, r2, CLKDIV, 4 	// for fastest possible readings (1.6MHz)

  // Step configuration 1
  MOV r4, 0x1			// ADC SW enabled, continuous, no averaging
  SBBO r4, r2, STEPCONFIG1, 4	// Store configuration to ADC_STEPCONFIG1 register

  // enable ADC STEPCONFIG 1
  MOV r4, 0x2			// Enable step 1 only
  SBBO r4, r2, STEPENABLE, 4	// Store configuration to ADC_STEPENABLE register

  // enable ADC reading
  MOV r4, 0x5
  SBBO r4, r2, CTRL, 4		// enable ADC to start oscilloscope

WAIT:		
  LBBO r4, r2, FIFOCOUNT, 4	// check for words in FIFO0
  QBEQ WAIT, r4, 0		// WAIT until word present in FIFO0

READ:
  LBCO r11, c28, 0xC, 4         // load in CYCLE COUNT
  LBBO r4, r3, 0, 4		// load 4 bytes from FIFO into r4

PACK:				// pack data into 32 bit register
  LSL r11, r11, 12		// use bits[31:12] for time
  OR r11, r11, r4		// pack as: time=bits[31:12], adc=bits[11:0]

USEDATA:
  SBBO r11, r1, r5, 4		// store data in PRU_DATARAM_1
  ADD r5, r5, 4			// increment counter

  QBNE WAIT, r5, r6		// check if enough samples taken

DEINIT:
  MOV r4, 0x0			// disable STEPENABLE
  SBBO r4, r2, STEPENABLE, 4

INTERRUPT:
  MOV r31.b0, PRU_INTERRUPT | PRU_EVTOUT_0

QUIT:
  HALT
