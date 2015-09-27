/* setup for SPI module */

#define CM_PER_                 0x44e00000  // clock module peripheral
#define SPI0_CLKCTRL            0x4c
#define SPI1_CLKCTRL            0x50

#define MCSPI0_                 0x48030100
#define MCSPI1_                 0x481a0100
#define SPI_SYSCONFIG           0x10
#define SPI_SYSSTATUS           0x14
#define SPI_IRQENABLE           0x1c
#define SPI_MODULCTRL           0x28
#define SPI_CH1CONF             0x40
#define SPI_CH1STAT             0x44
#define SPI_CH1CTRL             0x48
#define SPI_TX1                 0x4c

INIT_SPI:
    MOV r22, MCSPI1_            // MCSPI1 base address

    // define SPI1 clock management
    MOV r1, CM_PER_ | SPI1_CLKCTRL
    MOV r2, 0x2
    SBBO r2, r1, 0, 4           // explicitly enabled

    // soft reset SPI1
    LBBO r2, r22, SPI_SYSCONFIG, 4      // load in settings
    SET r2.t1                           // SOFTRESET
    SBBO r2, r22, SPI_SYSCONFIG, 4       

SPI_RESET_CHECK:                // wait for reset to complete
    LBBO r2, r22, SPI_SYSSTATUS, 4
    QBBC SPI_RESET_CHECK, r2.t0

    // configure module control
    MOV r2, 0x0                 // Master mode
    SBBO r2, r22, SPI_MODULCTRL, 4        

    // configure SYSCONFIG
    MOV r2, 0b1100010001        // OCP & Functional clocks maintained
                                // Smart-idle mode
                                // Automatic OCP clock gating
    SBBO r2, r22, SPI_SYSCONFIG, 4       

    // ensure interrupts are disabled
    MOV r2, 0x0                 // disable interrupts
    SBBO r2, r22, SPI_IRQENABLE, 4       

    // disable SPI CH1
    MOV r2, 0x0                 // disable CH1
    SBBO r2, r22, SPI_CH1CTRL, 4       

    // configure channel 1
    MOV r2, 0b110010010111111000000
            // bit[0]       phase                           (data latched to odd numbered edges of SPICLK)
            // bit[1]       polarity                        (SPICLK active high)
            // bits[5:2]    frequency divider               (divide by 1)
            // bit[6]       SPIEN polarity                  (active low)
            // bits[11:7]   WORD length                     (32 bits)
            // bits[13:12]  Transmit/Receive mode           (transmit only mode)
            // bit[14]      DMAW                            (DMA write disabled)
            // bit[15]      DMAR                            (DMA read disabled)
            // bit[16]      Transmission on data line 0     (true)
            // bit[17]      Transmission on data line 1     (false)
            // bit[18]      Input select                    (data line 0)
            // bit[19]      TURBO                           (true)
            // bit[20]      FORCE                           (true)
    OR r2, r2, 0000 << 2      // frequency division bits[5:2]
    SBBO r2, r22, SPI_CH1CONF, 4

    // Enable channel 1
    MOV r2, 0x1
    SBBO r2, r22, SPI_CH1CTRL, 4

