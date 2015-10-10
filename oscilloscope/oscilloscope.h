MYSQL * mysqlConnect();
unsigned int mysqlGetParameters(MYSQL *conn, unsigned int *pruSharedDataMemory_int);
void mysqlDisconnect(MYSQL *conn);
void mysqlError(MYSQL *conn);
