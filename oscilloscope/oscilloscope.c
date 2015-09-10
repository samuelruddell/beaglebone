/* PRU oscilloscope host program */
/* Copyright (C) 2015 Samuel Ruddell */

/* Include driver header */
#include <prussdrv.h>
#include <pruss_intc_mapping.h>
#include <stdio.h>
#include <stdlib.h>

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
	int i;
	unsigned int data[2048];

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

	/* connect to database */
	conn = mysqlConnect();

	/* create data table */
	if (mysql_query(conn, "DROP TABLE IF EXISTS data")) {
		mysqlError(conn);
	}

	if (mysql_query(conn, "CREATE TABLE data(i SMALLINT, time INT, adc SMALLINT, PRIMARY KEY (i))")) {
		mysqlError(conn);
	}

	int j = 0;
	/* Wait for event completion from PRU */
	prussdrv_pru_send_event(1);
	prussdrv_pru_wait_event (PRU_EVTOUT_0);

	char mysqlStr[60000];
	// 100 steps to terminate loop correctly for now
	while(j<100){
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
