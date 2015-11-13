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

    MOV r2, 0x0                         // disable SPI CH1
    SBBO r2, r22, SPI_CH1CTRL, 4       

    // configure channel 1
    MOV r2, 0b110010010111111000000
            // bit[29]      CLKG                        (clock divider granularity)
            // bit[28]      FFER                        (FIFO enabled for read)
            // bit[27]      FFEW                        (FIFO enabled for write)
            // bits[26:25]  TCS                         (time control select)
            // bit[24]      SBPOL                       (start bit polarity)
            // bit[23]      SBE                         (start bit enable)
            // bits[22:21]  SPIENSLV
            // bit[20]      FORCE                       
            // bit[19]      TURBO                       
            // bit[18]      IS                          (input select)                  (data line 0)
            // bit[17]      DPE1                        (Transmission on data line 1)   (false)
            // bit[16]      DPE0                        (Transmission on data line 0)   (true)
            // bit[15]      DMAR                        (DMA read disabled)
            // bit[14]      DMAW                        (DMA write disabled)
            // bits[13:12]  Transmit/Receive mode       (transmit only mode)
            // bits[11:7]   WORD length                 (32 bits)
            // bit[6]       SPIEN polarity              (active low)
            // bits[5:2]    frequency divider           (divide by 1)
            // bit[1]       polarity                    (SPICLK active high)
            // bit[0]       phase                       (data latched to odd numbered edges of SPICLK)

    SBBO r2, r22, SPI_CH1CONF, 4

SPI1_ENABLE:
    MOV r2, 0x1                         // Enable channel 1
    SBBO r2, r22, SPI_CH1CTRL, 4
