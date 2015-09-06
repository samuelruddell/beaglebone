/* PRU oscilloscope host program */
/* Copyright (C) 2015 Samuel Ruddell */

/* Include driver header */
#include <prussdrv.h>
#include <pruss_intc_mapping.h>
#include <stdio.h>

#define PRU_0	   	0
#define PRU_1      	1
#define PRU0_DATARAM 	0x00000000
#define PRU1_DATARAM 	0x00002000


/* IRQ handler thread */
void *pruevtout0_thread(void *arg) {
	do {
		prussdrv_pru_wait_event (PRU_EVTOUT_0);
		prussdrv_pru_clear_event (PRU_EVTOUT_0, PRU1_ARM_INTERRUPT);
	} while (1);
}

int main (void)
{
	static void *pru1DataMemory;
	static unsigned int *pru1DataMemory_int;

	int i;
	unsigned int data[2048];
	unsigned int time[2048];
	unsigned int adc[2048];

	FILE *datafile;

	/* Initialize structure used by prussdrv_pruintc_intc   */
	/* PRUSS_INTC_INITDATA is found in pruss_intc_mapping.h */
	tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;

	/* Allocate and initialize memory */
	prussdrv_init ();
	prussdrv_open (PRU_EVTOUT_0);

	/* Map PRU's INTC */
	prussdrv_pruintc_init(&pruss_intc_initdata);

	/* Map PRU data ram memory */
	prussdrv_map_prumem(PRUSS0_PRU1_DATARAM, &pru1DataMemory);
	pru1DataMemory_int = (unsigned int *) pru1DataMemory;

	/* Load and execute binary on PRU */
	prussdrv_exec_program (PRU_1, "./pru.bin");

	/* Wait for event completion from PRU */
	prussdrv_pru_wait_event (PRU_EVTOUT_0);

	/* Read PRU memory and print */
	for(i=0; i<2048; i++){
		data[i] = *(pru1DataMemory_int + i);
		time[i] = data[i] >> 12;		// unpack time data
		adc[i] = data[i] & 0x0fff;		// 12-bit bitmask for ADC values
	}

	/* write data to file */
	datafile = fopen("data", "w");
	for(i=0; i<2048; i++){
		fprintf(datafile,"%u %u\n", time[i], adc[i]);
	}
	fclose(datafile);

	/* Disable PRU and close memory mappings */
	prussdrv_pru_disable(PRU_1);
	prussdrv_exit ();

	return 0;
}
