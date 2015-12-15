/* PRU_0 PID CONTROLLER CODE */
/* Copyright (C) 2015 Samuel Ruddell */

/* PRU_0's function is to quickly calculate PID result and transfer to fast DAC */
   
.origin 0

/* DEFINITIONS */
#include "pru.hp"

/* INITIALISE REGISTERS */
INIT:
    ZERO 0, 124                         // ensure all registers zero
    MOV r22, MCSPI1_                    // SPI address

/* AWAIT ADC READING */
AWAIT:
    XIN 10, r4, 32                      // LOAD data from PRU_1
    QBBC AWAIT, r4.t15                  // check whether fast DAC enabled
    SUB r28, r9.w0, r11.w0              // calculate error signal as ADC - YLOCK, send to MPY
    
/* CALCULATE PID */
CALC_PROPORTIONAL:
    XOUT 0, r28, 8                      // initiate multiply (take care for collisions with PRU_1)
    XIN 0, r26, 8                       // get result
    QBBC PPOS, r26.t31                  // result is positive
    PNEG:
      RSB r15, r26, 0                   // make negative result positive to prevent rounding to negative infinity
      LSR r15, r15, 15                  // round result correctly
      RSB r15, r15, 0                   // make result negative again
      QBA PREPARE_RESULT
    PPOS:
      LSR r15, r26, 15                  // store lower product in r15 with LSR

/*                                      // only proportional for now, for speed and to prevent MPY collisions
CALC_INTEGRAL:
    MOV r29, r13                        // IGAIN to MPY 
    XOUT 0, r28, 8                      // initiate multiply
    XIN 0, r26, 8                       // get result
    MOV r16, r26, 4                     // store result in r16
CALC_DERIVATIVE:
    SUB r28, r28, r18                   // calculate derivative
    MOV r29, r14                        // DGAIN to MPY
    XOUT 0, r28, 8                      // initiate MPY  
    XIN 0, r26, 8                       // get result
    MOV r17, r26, 4                     // store result in r17
*/

/* PREPARE RESULT */
PREPARE_RESULT:
    QBBS OPEN_SPI, r4.t0                // open loop
    QBBS OPEN_SPI, r4.t17               // semi-closed loop

/* SEND RESULT TO DAC */
CLOSED_SPI:
    ADD r2, r7.w0, r15                  // add PID gain to DAC output
    SBBO r2.w0, r22, SPI_TX1, 4         // send resulting value to DAC 
    QBA PREPARE_NEXT

OPEN_SPI:
    SBBO r7.w0, r22, SPI_TX1, 4         // follow other DAC
        
/* PREPARE FOR NEXT CALCULATION */
PREPARE_NEXT:
    SUB r18, r9.w0, r11.w0              // error signal becomes previous error signal
    XIN 10, r12, 12                     // load in PID gains
    MOV r29, r12                        // PGAIN to MPY

    CLR r4.t15                          // disable DAC until triggered by PRU_1
    XOUT 10, r4, 4
    QBA AWAIT

QUIT:
    HALT
