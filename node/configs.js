//
// Node server configurations.
//
(function () {

	//
	// Serverside configurations.
	//
	var server = {
		// Hosting configs.
		hostname	: "localhost",
		port		: 8133,

		clientContentPath: "client",
		clientStartPage	: __dirname + "/client/index.html"
	}

	//
	// MySQL database configurations.
	//
	var mysql = {
		// Database connection string configs.
		host	 	: "localhost",
		port	 	: 3306,

		database 	: "scope",
		username 	: "samuel",
		password 	: ""
	}

	//
	// PID controller configurations.
	//
	var pid = {
		// Poll interval in milliseconds.
		pollingInterval : 500
	}

	//
	// Router configurations.
	//
	var route = {
		routeDirectory 	: __dirname + "/routes"
	}

	// Make the configuration sections accessible when loaded as a module.
	module.exports.server 	= server
	module.exports.mysql 	= mysql
	module.exports.pid 	= pid
	module.exports.route 	= route
}())
