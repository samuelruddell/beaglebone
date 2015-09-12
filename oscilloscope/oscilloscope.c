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
#define PRU0_DATARAM 	0x00000000
#define PRU1_DATARAM 	0x00002000

/* mysql global variables */
static char *host = "localhost";
static char *user = "samuel";
static char *pass = "";
static char *dbname = "scope";

unsigned int port = 3306;
static char *unix_socket = NULL;
unsigned int flag = 0;

/* IRQ handler thread */
void *pruevtout0_thread(void *arg) {
	do {
		prussdrv_pru_wait_event (PRU_EVTOUT_0);
		prussdrv_pru_clear_event (PRU_EVTOUT_0, PRU1_ARM_INTERRUPT);
	} while (1);
}

int main (int argc, char **argv)
{
	static void *pru1DataMemory;
	static unsigned int *pru1DataMemory_int;

	MYSQL *conn; 
	MYSQL_RES *result;
	MYSQL_ROW row;
	char mysqlStr[70000];
	int i, j;
	unsigned int data[2048];

	/* connect to database */
	conn = mysqlConnect();

	/* infinite loop */
	while(1) {
		// query database for the value of RUN, wait until value = 1
		while(1) {
			sleep(1);			// wait 1 second
			mysql_query(conn, "SELECT value FROM parameters WHERE name = 'RUN' LIMIT 1");
			result = mysql_store_result(conn);
			row = mysql_fetch_row(result);
			// check whether RUN == "1"
			if(!strncmp(row[0], "1", 1)){
				mysql_free_result(result);
				// reset RUN value to 0 in MySQL database
				if (mysql_query(conn, "REPLACE INTO parameters (name, value) VALUES ('RUN', 0);")) {
					mysqlError(conn);
				}
				// break loop and begin oscilloscope
				break;
			}
			mysql_free_result(result);
		}

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

		j = 0;
		/* Wait for event completion from PRU */
		prussdrv_pru_send_event(1);
		prussdrv_pru_wait_event (PRU_EVTOUT_0);

		// 50 steps to terminate loop correctly for now
		while(j<50){
			prussdrv_pru_clear_event (PRU_EVTOUT_0, PRU1_ARM_INTERRUPT);

			/* Read PRU memory and store in MySQL database */
			char *mysqlStrPointer = mysqlStr;
			// note have to check this for multiple loops
			mysqlStrPointer += sprintf(mysqlStrPointer, "REPLACE INTO data (i, time, adc) VALUES");

			/* Build string for inserting data */
			// note: does not account for pru writes overtaking reads 
			for(i=0; i<2048; i++){
				data[i] = *(pru1DataMemory_int + i);
				// time[i] = data[i] >> 12;		// unpack time data
				// adc[i] = data[i] & 0x0fff;		// 12-bit bitmask for ADC values
				if (i<2047){
					mysqlStrPointer += sprintf(mysqlStrPointer, "('%hu', '%u', '%hu'),", i, data[i] >> 12, data[i] & 0x0fff);
				} else {
					mysqlStrPointer += sprintf(mysqlStrPointer, "('%hu', '%u', '%hu');", i, data[i] >> 12, data[i] & 0x0fff);
				}	

			}

			/* Insert data to table */
			if (mysql_query(conn, mysqlStr)) {
				mysqlError(conn);
			}

			/* Interrupt PRU, wait for PRU_EVTOUT_0 */
			prussdrv_pru_send_event (1);
			prussdrv_pru_wait_event (PRU_EVTOUT_0);
			j++;
		}
		/* Disable PRU and close memory mappings */
		prussdrv_pru_disable(PRU_1);
		prussdrv_exit ();

	}

	/* disconnect from database */
	mysqlDisconnect(conn);

	return 0;
}

MYSQL * mysqlConnect(){
	MYSQL *conn;

	conn = mysql_init(NULL);

	if(mysql_real_connect(conn, host, user, pass, dbname, port, unix_socket, flag) == NULL)
	{
		mysqlError(conn);
	}

	return conn;
}

void mysqlDisconnect(MYSQL *conn){
	mysql_close(conn);
}

void mysqlError(MYSQL *conn){
	fprintf(stderr, "%s\n", mysql_error(conn));
	mysql_close(conn);
	exit(1);
}
