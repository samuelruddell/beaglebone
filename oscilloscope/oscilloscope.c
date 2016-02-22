/* PRU oscilloscope host program */
/* Copyright (C) 2015 Samuel Ruddell */

/* Include driver header */
#include <prussdrv.h>
#include <pruss_intc_mapping.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <mysql/mysql.h>
#include "oscilloscope.h"

#define PRU_0	   	0
#define PRU_1      	1

/* mysql global variables */
static char *host = "localhost";
static char *user = "samuel";
static char *pass = "";
static char *dbname = "scope";

unsigned int port = 3306;
static char *unix_socket = NULL;
unsigned int flag = 0;

int main (int argc, char **argv)
{
	MYSQL *conn; 

	unsigned int runScope = 1;

	/* connect to database */
	conn = mysqlConnect();

	/* initialise PRU */
	static void *pru0DataMemory;
	static unsigned int *pru0DataMemory_int;
	static void *pru1DataMemory;
	static unsigned int *pru1DataMemory_int;
	static void *pruSharedDataMemory;
	static unsigned int *pruSharedDataMemory_int;

	char mysqlStr[100000];
	unsigned int data[2048], time[2048];
	int i;

	/* Initialize structure used by prussdrv_pruintc_intc */
	tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;

	/* Allocate and initialize memory */
	prussdrv_init ();
	prussdrv_open (PRU_EVTOUT_0);

	/* Map PRU's INTC */
	prussdrv_pruintc_init(&pruss_intc_initdata);

	/* Map PRU data ram memory */
	prussdrv_map_prumem(PRUSS0_PRU0_DATARAM, &pru0DataMemory);
	pru0DataMemory_int = (unsigned int *) pru0DataMemory;

	prussdrv_map_prumem(PRUSS0_PRU1_DATARAM, &pru1DataMemory);
	pru1DataMemory_int = (unsigned int *) pru1DataMemory;

	prussdrv_map_prumem(PRUSS0_SHARED_DATARAM, &pruSharedDataMemory);
	pruSharedDataMemory_int = (unsigned int *) pruSharedDataMemory;

	/* Load default parameters and store in PRU memory */
	runScope = mysqlGetParameters(conn, pruSharedDataMemory_int);

	/* Load and execute binary on PRU */
	prussdrv_exec_program (PRU_0, "./pru0.bin");
	prussdrv_exec_program (PRU_1, "./pru1.bin");

	while(1) {
		/* run oscilloscope */
		if(runScope){

			/* send interrupt to PRU then wait for and clear EVTOUT0 */
			// event 17 maps to PRU r31.t31, event 18 maps to r31.t30
			prussdrv_pru_send_wait_clear_event  ( 18, PRU_EVTOUT_0, 19);

			/* Read PRU memory and store in MySQL database */
			char *mysqlStrPointer = mysqlStr;
			mysqlStrPointer += sprintf(mysqlStrPointer, "INSERT INTO data (i, time, dac, adc) VALUES");
			//mysqlStrPointer += sprintf(mysqlStrPointer, "REPLACE INTO data (i, time, adc) VALUES");

			/* Build string for inserting data */
			for(i=0; i<2048; i++){
				time[i] = *(pru0DataMemory_int + i);	// 32-bit time value
				data[i] = *(pru1DataMemory_int + i);	// 16-bit DAC value << 16 | 12-bit ADC value
				if (i<2047){
					mysqlStrPointer += sprintf(mysqlStrPointer, "(%hu,%u,%hu,%hu),", i, time[i], data[i] >> 16, data[i] & 0x0fff);
				} else {
					mysqlStrPointer += sprintf(mysqlStrPointer, "(%hu,%u,%hu,%hu)", i, time[i], data[i] >> 16, data[i] & 0x0fff);
				}	
			}

			mysqlStrPointer += sprintf(mysqlStrPointer, " ON DUPLICATE KEY UPDATE i=VALUES(i), time=VALUES(time), dac=VALUES(dac), adc=VALUES(adc)");

			/* Insert data to table */
			if (mysql_query(conn, mysqlStr)) {
				mysqlError(conn);
			}

		}

		/* sleep for performance reasons */
		sleep(0.5);

		/* Load settings and write to PRU memory */
		runScope = mysqlGetParameters(conn, pruSharedDataMemory_int);
	}

	/* Disable PRU and close memory mappings */
	prussdrv_pru_disable(PRU_1);
	prussdrv_exit ();

	/* disconnect from database */
	mysqlDisconnect(conn);

	return 0;
}

/* Connect to MySQL database */
MYSQL * mysqlConnect(){
	MYSQL *conn;

	conn = mysql_init(NULL);

	if(mysql_real_connect(conn, host, user, pass, dbname, port, unix_socket, flag) == NULL)
	{
		mysqlError(conn);
	}

	return conn;
}

/* Load default settings and write to PRU memory */
unsigned int mysqlGetParameters(MYSQL *conn, unsigned int *pruSharedDataMemory_int){
	MYSQL_RES *result;
	MYSQL_ROW row;

	int mem_offset, mem_value;
	unsigned int runScope           = 0;
	unsigned int pruBooleans        = 0x0;
	unsigned int xlock_ylock        = 0x0;
	unsigned int open_point_ampl    = 0x0;
	unsigned int ireset_pos_neg     = 0x0;

	mysql_query(conn, "SELECT addr, value FROM parameters");
	result = mysql_store_result(conn);
	while ((row = mysql_fetch_row(result))){
		mem_offset = atoi(row[0]);
		mem_value = atoi(row[1]);
		switch (mem_offset) {

			// run status
			case 0 :
				runScope = mem_value;   // RUN
				break;

			// booleans
			case 1 :
				if (mem_value==1){
					pruBooleans |= 0x1;     		// open/closed loop
				}
				break;
			case 19 :
				if (mem_value==1){
					pruBooleans |= 0x2;     		// integrator reset
				}
				break;
			case 20 :
				if (mem_value==1){
					pruBooleans |= 0x4;     		// auto integrator reset
				}
				break;
			case 23 :
				if (mem_value==1){
					pruBooleans |= 0x8;     		// lock slope
				}
				break;
			case 24 :
				if (mem_value==1){
					pruBooleans |= 0x10;     		// autolock enable
				}
				break;
			case 25 :
				if (mem_value==1){
					pruBooleans |= 0x20;     		// autolock above (1) / below (0)
				}
				break;

			// pack XLOCK and YLOCK
			case 2 :	
				xlock_ylock |= ((mem_value & 0xffff) << 16);    // XLOCK
				break;
			case 3 :
				xlock_ylock |= (mem_value & 0x0fff);            // YLOCK
				break;

			// pack SCANPOINT and OPENAMPL:
			case 13 :	
				open_point_ampl |= (mem_value & 0xffff);        // OPENAMPL
				break;
			case 14 : 			
				open_point_ampl |= ((mem_value & 0xffff) << 16);// SCANPOINT
				break;

                        // mask SLOW ACCUMULATOR value
                        case 15 :
				*(pruSharedDataMemory_int + mem_offset) = (mem_value & 0xf);
				break;

			// pack AUTO INTEGRATOR OVERFLOW and UNDERFLOW
			case 21 : 	
				ireset_pos_neg |= ((mem_value & 0xffff) << 16); // POSITIVE OVERFLOW
				break;
			case 22 :
				ireset_pos_neg |= (mem_value & 0xffff);         // NEGATIVE UNDERFLOW
				break;

			// do nothing (parameter not relevant to PRU program)
			case 100 :
			case 101 :
			case 102 :
			case 103 :
			case 104 :
			case 105 :
			case 106 :
			case 107 :
			case 108 :
				break;

			// write memory normally
			default : 			
				*(pruSharedDataMemory_int + mem_offset) = mem_value;
		}
	}

	// store packed data to pru memory
	*(pruSharedDataMemory_int + 1) = pruBooleans;           
	*(pruSharedDataMemory_int + 2) = xlock_ylock;          
	*(pruSharedDataMemory_int + 13) = open_point_ampl;    
	*(pruSharedDataMemory_int + 21) = ireset_pos_neg;    

	// clean up and return runScope
	mysql_free_result(result);	
	return runScope;
}

/* Disconnect from MySQL database */
void mysqlDisconnect(MYSQL *conn){
	mysql_close(conn);
}

/* Print MySQL error */
void mysqlError(MYSQL *conn){
	fprintf(stderr, "%s\n", mysql_error(conn));
	mysql_close(conn);
	exit(1);
}
