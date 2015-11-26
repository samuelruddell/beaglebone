/* setup for SPI module */
SPI1_INIT:
    MOV r22, MCSPI1_                    // MCSPI1 base address

    MOV r1, CM_PER_ | SPI1_CLKCTRL      // define SPI1 clock management
    MOV r2, 0x2                         // explicitly enabled
    SBBO r2, r1, 0, 4                   

    LBBO r2, r22, SPI_SYSCONFIG, 4      // soft reset SPI_1
    SET r2.t1                           
    SBBO r2, r22, SPI_SYSCONFIG, 4       

SPI1_RESET_CHECK:                       // wait for reset to complete
    LBBO r2, r22, SPI_SYSSTATUS, 4
    QBBC SPI1_RESET_CHECK, r2.t0

SPI1_CONFIGURE:
    MOV r2, 0x0                         // configure module contral: Master mode
    SBBO r2, r22, SPI_MODULCTRL, 4      

    // configure SYSCONFIG
    MOV r2, 0b1100010001                // OCP & Functional clocks maintained
                                        // Smart-idle mode
                                        // Automatic OCP clock gating
    SBBO r2, r22, SPI_SYSCONFIG, 4       

    MOV r2, 0x0                         // disable interrupts
    SBBO r2, r22, SPI_IRQENABLE, 4       

    /* setup channel 0 */
    MOV r2, 0x0                         // disable SPI1 channel 0
    SBBO r2, r22, SPI_CH0CTRL, 4       

    // configure channel 0 for MAX5216 DAC
    MOV r2, 0b00000000000000010010101111000001
    SBBO r2, r22, SPI_CH0CONF, 4

    MOV r2, 0x1                         // enable SPI1 channel 0
    SBBO r2, r22, SPI_CH0CTRL, 4
