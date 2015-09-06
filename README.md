# beaglebone
Software for use on the BeagleBone Black, including PRU software.

To use this software, you will need to load a device tree overlay (.dtbo) to allow the device to understand how the hardware is supposed to be used. This can be achieved by (e.g.):

`echo cape-bone-iio > /sys/devices/bone_capemgr.*/slots`

To compile the sofware, ensure you have all the correct compilers (gcc, pasm). These are present by default on the Beaglebone Black Rev C. You can then run `make` in the appropriate folders, once for the C program and once for the PRU assembly program. The executable will be in the bin folder.


Copyright (c) 2015 Samuel Ruddell
 
 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
