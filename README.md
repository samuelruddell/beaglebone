# beaglebone
Software for use on the BeagleBone Black, including PRU software.

To use this software, you will need to load a device tree overlay (.dtbo) to allow the device to understand how the hardware is supposed to be used. This can be achieved by (e.g.):

`echo cape-bone-iio > /sys/devices/bone_capemgr.*/slots`

To compile the sofware, ensure you have all the correct compilers (gcc, pasm). These are present by default on the Beaglebone Black Rev C. You can then run `make` in the appropriate folders, once for the C program and once for the PRU assembly program. The executable will be in the bin folder.
        
## Register assignment
| REGISTER      |                   USE                 |
| :------------ | :------------------------------------ |
| r0            | RESERVED                              |
| r1            | TMP ADDR                              |
| r2            | TMP VALUE                             |
| r3            | w2: WRITE_EN, w0: WRITE COUNTER       |
| r4            | w2: bools, w0: MEMORY SIZE            |
| r5            | CYCLE SETTINGS                        |
| r6            | PACKED DATA                           |
| r7            | DAC VALUE                             |
| r8            | TIME                                  |
| r9            | ADC                                   |
| r10           | OPEN LOOP AMPLITUDE                   |
| r11           | PID SET POINT                         |
| r12           | PGAIN RESULT << 16 \| PGAIN           |
| r13           | IGAIN RESULT << 16 \| IGAIN           |
| r14           | IGAIN CALC REGISTER                   |
| r15           | DGAIN RESULT << 16 \| DGAIN           |
| r16           | DGAIN CALC REGISTER                   |
| r17           |                                       |
| r18           |                                       |
| r19           |                                       |
| r20           | ADC_                                  |
| r21           | ADC_FIFO0                             |
| r22           | MCSPI_TX1                             |
| r23           | MCSPI_CH1STAT                         |
| r24           |                                       |
| r25           | MAC SETTINGS                          |
| r26           | MAC UPPER PRODUCT                     |
| r27           | MAC LOWER PRODUCT                     |
| r28           | MAC OPERAND 1                         |
| r29           | MAC OPERAND 2                         |
| r30           | REALTIME OUT                          |
| r31           | REALTIME IN / INTERRUPT               |
|		|					|
| c24		| PRU 1/0 DATARAM			|
| c25		| PRU 0/1 DATARAM			|
| c28           | CYCLE CTRL                            |

## PRU memory assignment
| ADDR		| name		|
| :------------ | :------------ |
| 0x0		| RUN		|
| 0x4		| OPENCLOSE	|
| 0x8		| XLOCK		|
| 0xC		| YLOCK		|
| 0x10		| TIME_XY	|
| 0x20		| ADC_CLKDIV	|
| 0x24		| ADC_AVERAGE	|
| 0x28		| OPENDELAY	|
| 0x2C		| CLOSEDELAY	|
| 0x30		| SPI_CH1CONF	|
| 0x40		| PGAIN		|
| 0x44		| IGAIN		|
| 0x48		| DGAIN		|
| 0x4C		| IRESET	|
| 0x50		| LOCKSLOPE	|
