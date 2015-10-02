/* setup for ADC module */
  MOV r20, ADC_                 // ADC address
  MOV r21, ADC_ | FIFO          // FIFO0 address
ADC_SETUP:
  // edit CTRL register
  MOV r2, 0x4                   // Make step configuration registers writable, disable TSC_ADC_SS
  SBBO r2, r20, CTRL, 4         // Store configuration to ADC_CTRL register

ADC_CHECK:                      // ensure ADC is disabled
  LBBO r2, r20, ADCSTAT, 4      // Load in ADC status
  AND r2, r2, 0x1f              // bitmask for step_id status  
  QBNE ADC_CHECK, r2, 0x10      // wait until ADC idling before editing step registers

FIFO_EMPTY:
  LBBO r2, r20, FIFOCOUNT, 4    // check for words in FIFO0
  QBEQ FIFO_IS_EMPTY, r2, 0     // skip if FIFO is already empty
  LBBO r9, r21, 0, 4            // load 4 bytes from FIFO into r9
  QBA FIFO_EMPTY
  FIFO_IS_EMPTY:

  // edit CLKDIV register
  LBCO r2, c25, 0x20, 4         // Load in ADC CLKDIV setting from memory
  SBBO r2, r20, CLKDIV, 4       // set to 0 for fastest possible adc readings (1.6MHz)

  // Step configuration 1
  LBCO r2, c25, 0x24, 4         // load averaging from PRU memory
                                // possibility of 0,2,4,8,16 sample averages
  AND r2, r2, 0x7               // bitmask
  LSL r2, r2, 2                 // bits[4:2] define averaging
  OR r2, r2, 0x1                // ADC SW enabled, continuous, averaging as defined
  SBBO r2, r20, STEPCONFIG1, 4  // Store configuration to ADC_STEPCONFIG1 register

ADC_OPENDELAY:                  // Step delay configuration 1 for open loop
  QBBC ADC_CLOSEDDELAY, r4.t16  // use separate delay for closed loop
  LBCO r2, c25, 0x28, 4         // number of ADC clock cycles to wait after applying STEPCONFIG1 
  MOV r1, 0x3ffff               // bitmask for bits[17:0]
  AND r2, r2, r1                // apply bitmask
  SBBO r2, r20, STEPDELAY1, 4   // bits[17:0]
  QBA ADC_ENABLE

ADC_CLOSEDDELAY:                // Step delay configuration 1 for closed loop
  LBCO r2, c25, 0x2c, 4         // number of ADC clock cycles to wait after applying STEPCONFIG1 
  MOV r1, 0x3ffff               // bitmask for bits[17:0]
  AND r2, r2, r1                // apply bitmask
  SBBO r2, r20, STEPDELAY1, 4   // bits[17:0]
    
ADC_ENABLE:
  // enable ADC STEPCONFIG 1
  MOV r2, 0x2                   // Enable step 1 only
  SBBO r2, r20, STEPENABLE, 4   // Store configuration to ADC_STEPENABLE register

  // enable ADC reading
  MOV r2, 0x1                   // make step configuration registers read only, enable TSC_ADC_SS
  SBBO r2, r20, CTRL, 4         // enable ADC to start oscilloscope
