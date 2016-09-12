#define INVERT_MUXOUT_GPIO

struct GpioAddr {
	volatile void *gpio0_addr, *gpio1_addr, *gpio2_addr, *gpio3_addr;
	volatile unsigned int *SetAddr, *ClearAddr;
};

MYSQL * mysqlConnect();
unsigned int mysqlGetParameters(MYSQL *conn, unsigned int *pruSharedDataMemory_int, struct GpioAddr);
void mysqlDisconnect(MYSQL *conn);
void mysqlError(MYSQL *conn);
int setMuxOut(struct GpioAddr, int );
int setMuxIn(struct GpioAddr, int );
