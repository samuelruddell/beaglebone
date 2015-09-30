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
	MYSQL_RES *result;
	MYSQL_ROW row;

	unsigned int runScope = 1;

	/* connect to database */
	conn = mysqlConnect();

	/* initialise PRU */
	static void *pru0DataMemory;
	static unsigned int *pru0DataMemory_int;
	static void *pru1DataMemory;
	static unsigned int *pru1DataMemory_int;

	char mysqlStr[60000];
	unsigned int data[2048];
	int i;
	int mem_offset, mem_value;

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

	/* Load default settings and write to PRU memory */
	mysql_query(conn, "SELECT addr, value FROM parameters");
	result = mysql_store_result(conn);
	while ((row = mysql_fetch_row(result))){
		mem_offset = atoi(row[0]);
		mem_value = atoi(row[1]);
		*(pru0DataMemory_int + mem_offset) = mem_value;
	}
	mysql_free_result(result);	

	/* Load and execute binary on PRU */
	prussdrv_exec_program (PRU_1, "./pru.bin");

	while(1) {
		/* run oscilloscope */
		if(runScope){

			/* send interrupt to PRU and wait for EVTOUT */
			// event 17 maps to r31.t31, event 18 maps to r31.t30
			prussdrv_pru_send_wait_clear_event  ( 18, PRU_EVTOUT_0, PRU1_ARM_INTERRUPT);

			/* Read PRU memory and store in MySQL database */
			char *mysqlStrPointer = mysqlStr;
			mysqlStrPointer += sprintf(mysqlStrPointer, "INSERT INTO data (i, time, adc) VALUES");
			//mysqlStrPointer += sprintf(mysqlStrPointer, "REPLACE INTO data (i, time, adc) VALUES");

			/* Build string for inserting data */
			for(i=0; i<2048; i++){
				data[i] = *(pru1DataMemory_int + i);
				// time[i] = data[i] >> 12;		// unpack time data
				// adc[i] = data[i] & 0x0fff;		// 12-bit bitmask for ADC values
				if (i<2047){
					mysqlStrPointer += sprintf(mysqlStrPointer, "(%hu,%u,%hu),", i, data[i] >> 12, data[i] & 0x0fff);
				} else {
					mysqlStrPointer += sprintf(mysqlStrPointer, "(%hu,%u,%hu)", i, data[i] >> 12, data[i] & 0x0fff);
				}	
			}

			mysqlStrPointer += sprintf(mysqlStrPointer, " ON DUPLICATE KEY UPDATE i=VALUES(i), time=VALUES(time), adc=VALUES(adc)");

			/* Insert data to table */
			if (mysql_query(conn, mysqlStr)) {
				mysqlError(conn);
			}

		}

		/* sleep for performance reasons */
		sleep(0.5);

		/* Load settings and write to PRU memory */
		mysql_query(conn, "SELECT addr, value FROM parameters");
		result = mysql_store_result(conn);
		while ((row = mysql_fetch_row(result))){
			mem_offset = atoi(row[0]);
			mem_value = atoi(row[1]);
			*(pru0DataMemory_int + mem_offset) = mem_value;
			// check status of RUN
			if(mem_offset==0){
				runScope = mem_value;			// set runScope to value of RUN
			}
		}
		mysql_free_result(result);
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
