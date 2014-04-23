/* PRU_0 PID CONTROLLER CODE */
/* Copyright (C) 2015 Samuel Ruddell */

/* PRU_0's function is to handle PID calculations for slow DAC */

.origin 0

/* DEFINITIONS */
#include "pru.hp"

/* INITIALISE REGISTERS */
INIT:
    ZERO 0, 124                         // ensure all registers zero
    MOV r22, MCSPI0_                    // SPI address

/* AWAIT ADC READING */
AWAIT:
    XIN 10, r4, 44                      // LOAD data from PRU_1
    QBBS CLR_INTEGRATOR, r4.t17         // currently at semiclosed loop: clear integrator
    QBBC AWAIT, r4.t15                  // check whether DAC enabled

     /* ACCUMULATION AVERAGING LOGIC */
        QBEQ ACCUM_PREP, r1.b2, 0x0     // skip accumulator if no accumulation called for
        ADD r3, r3, r9.w0               // add current ADC reading to accumulator
        ADD r1.w0, r1.w0, 1             // increase accumulation
        QBBS ACCUM_FULL, r1, r1.b2      // if number of accumulations reached (powers of 2)
        QBA AWAIT                       // more readings needed for accumulation averaging

        ACCUM_FULL:
          LSR r3, r3, r1.b2             // average all values in r3 (floor remainder)
          MOV r9.w0, r3.w0              // move averaged ADC value to r9.w0 for processing
          MOV r3, 0x0                   // clear accumulator
          MOV r1.w0, 0x0                // clear accumulator counts

        ACCUM_PREP:
          MOV r1.b2, r6.b3              // number of averages may have changed due to LOAD_PARAMETERS

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
          ADD r21, r11.w2, r2           // ADD PID result to DAC output
        
        OVERFLOW_TEST:                  // test for PID overflow
          QBEQ SPI_BUILDWORD, r21.w2, 0 // no overflow or underflow
          QBBS UNDERFLOW, r21.t31       // number is negative therefore underflow
          OVERFLOW:
            MOV r21, 0xffff             // max output
            QBA SPI_BUILDWORD
          UNDERFLOW:
            MOV r21, 0x0                // min output

/* SPI SEND DATA TO DAC */
      SPI_BUILDWORD:                    // prepare data for sending to DAC AD5545      
        MOV r21.w2, 0x2                 // SET r21.t17 -- designates slow DAC

      QBEQ SPI_END, r20, r21            // no need to use SPI if result is the same
      SPI_SEND:
        SBBO r21, r22, SPI_TX0, 4       // word to transmit 
      SPI_END:

/* PREPARE FOR NEXT CALCULATION */
PREPARE_NEXT:
    SUB r18, r9.w0, r11.w0              // error signal becomes previous error signal
    MOV r20, r21                        // DAC value to previous DAC value

    CLR r4.t15                          // disable until triggered by PRU_1
    XOUT 10, r4, 4                      // store bools to broadside memory
    QBA AWAIT

QUIT:
    HALT

/* SUBROUTINES */
CLR_INTEGRATOR:
    MOV r16, 0x0                        // clear integrator before closed loop starts
    QBA AWAIT
