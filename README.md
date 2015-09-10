# beaglebone
Software for use on the BeagleBone Black, including PRU software.

To use this software, you will need to load a device tree overlay (.dtbo) to allow the device to understand how the hardware is supposed to be used. This can be achieved by (e.g.):

`echo cape-bone-iio > /sys/devices/bone_capemgr.*/slots`

To compile the sofware, ensure you have all the correct compilers (gcc, pasm). These are present by default on the Beaglebone Black Rev C. You can then run `make` in the appropriate folders, once for the C program and once for the PRU assembly program. The executable will be in the bin folder.
