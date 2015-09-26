#define ADC_      		0x44e0d000
#define CTRL 	        	0x040
#define CLKDIV			0x04c
#define STEPENABLE 		0x054
#define STEPCONFIG1      	0x064
#define FIFOCOUNT		0x0e4
#define FIFO 		        0x100

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
