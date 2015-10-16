//
//
//
(function () {
	// Load the MySQL module.
	var mysql = require("mysql")

	// Load the MySQL specific configs.
	var configs = require("./configs").mysql

	// Private connection container.
	var connection

	module.exports = {
		// Connect and maintain database connection.
		connect: function () {
			console.log("Database: attempting to connect to MySQL instance: %s@%s", 
				configs.username, configs.host)

			connection = mysql.createConnection({
				host		: configs.host,
				port		: configs.port,
				user		: configs.username,
				password	: configs.password,
				database	: configs.database
			})

			connection.connect(function(err) {
			  if(err) {
					console.error("Database: FATAL - failed to connect to MySQL instance (%s)", err)
				} else {
					console.log("Database: connection created successfully.")
				}
			})
		},
		// Query MySQL database
		query: function (queryString, inserts, callback) {
			var query   		= connection.query(queryString, inserts),
			    data 		= [],
			    array

			query
			.on('error', function(err) {
				console.log("Database: (%s)", err)
			})
			.on('result', function(rows) {
				// extract and push values only
				array = []
				for (var key in rows) {
					array.push(rows[key])
				}
				data.push(array)
			})
			.on('end', function() {
				callback(data)
			})	
		}
	}	
}())
