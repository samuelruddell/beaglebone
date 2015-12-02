# beaglebone black PID controller
A PID controller for the beaglebone black. Please note that this software is a work in progress.

To use this software, you will need to load a device tree overlay (.dtbo) to allow the device to understand how the hardware is supposed to be used. This can be achieved by (e.g.):

`echo cape-bone-iio > /sys/devices/bone_capemgr.*/slots`

To compile the software, ensure you have all the correct compilers (gcc, pasm). These are present by default on the Beaglebone Black Rev C. You can then run `make` in the appropriate folders, once for the C program and once for the PRU assembly program. The executable will be in the bin folder.
        
## PRU Register assignment
| REGISTER      |                   USE                 |
| :------------ | :------------------------------------ |
| r0            | bits[4:0] XFR SHIFT                   |
| r1            | TMP ADDR                              |
| r2            | TMP VALUE                             |
| r3            | w2: MEMORY SIZE               w0: WRITE COUNTER       |
| r4            | BOOLS 	                        |
| r5            | ACCUMULATER FOR SLOW DAC AVERAGING    |
| r6            | w2: ACCUMULATER NUMBER        w0: COUNTER             |
| r7            | DAC VALUE                             |
| r8            | TIME                                  |
| r9            | w2: DAC VALUE (PACKED)	w0: ADC                 |
| r10           | w2: OPEN LOOP SCAN POINT      w0: OPEN LOOP AMPLITUDE |
| r11           | w2: XLOCK	                w0: YLOCK / AUTOLOCK POINT|
| r12           | PGAIN                                 |
| r13           | IGAIN                                 |
| r14           | DGAIN                                 | 
| r15           | P_RESULT                              |
| r16           | I_RESULT                              |
| r17           | D_RESULT                              |
| r18           | PREVIOUS ERROR SIGNAL                 |
| r19           | ERROR SIGNAL                          |
| r20           | ADC_                                  |
| r21           | ADC_FIFO0                             |
| r22           | MCSPI1_                               |
| r23           |                               w0: JAL REGISTER        |
| r24           | w2: AUTO INT OVERFLOW         w0: AUTO INT UNDERFLOW  |
| r25           | MAC SETTINGS / CYCLE SETTINGS         |
| r26           | MAC LOWER PRODUCT                     |
| r27           | MAC UPPER PRODUCT                     |
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
| 0x4		| BOOLEANS 	|
| 0x8		| XLOCK		|
| 0xC		| YLOCK		|
| 0x20		| ADC_CLKDIV	|
| 0x24		| ADC_AVERAGE	|
| 0x28		| OPENDELAY	|
| 0x2C		| CLOSEDELAY	|
| 0x30		| SPI_CH1CONF	|
| 0x34		| OPENAMPL      |
| 0x40		| PGAIN		|
| 0x44		| IGAIN		|
| 0x48		| DGAIN		|
