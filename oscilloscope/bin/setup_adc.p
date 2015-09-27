#define ADC_      		0x44e0d000
#define CTRL 	        	0x040
#define CLKDIV			0x04c
#define STEPENABLE 		0x054
#define STEPCONFIG1      	0x064
#define FIFOCOUNT		0x0e4
#define FIFO 		        0x100

ADC_INIT:
  MOV r20, ADC_		        // ADC address
  MOV r21, ADC_ | FIFO		// FIFO0 address

  // edit CTRL register
  MOV r2, 0x4			// Make step configuration registers writable, disable TSC_ADC_SS
  SBBO r2, r20, CTRL, 4		// Store configuration to ADC_CTRL register

  // edit CLKDIV register
  LBCO r2, c25, 0x20, 4		// ADC clock divisor = 1
  SBBO r2, r20, CLKDIV, 4 	// for fastest possible readings (1.6MHz)

  // Step configuration 1
  // Averaging bits[4:2], possibility of 0,2,4,8,16 sample averages
  LBCO r2, c25, 0x24, 4
  LSL r2, r2, 2                 // bits[4:2]
  OR r2, r2, 0x1      	        // ADC SW enabled, continuous, averaging as defined
  SBBO r2, r20, STEPCONFIG1, 4	// Store configuration to ADC_STEPCONFIG1 register

  // enable ADC STEPCONFIG 1
  MOV r2, 0x2			// Enable step 1 only
  SBBO r2, r20, STEPENABLE, 4	// Store configuration to ADC_STEPENABLE register

  // enable ADC reading
  MOV r2, 0x5
  SBBO r2, r20, CTRL, 4		// enable ADC to start oscilloscope