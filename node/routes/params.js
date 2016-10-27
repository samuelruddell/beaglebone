//
// routes/params.js
//
// Routes for working with PID parameters. Pass in the express app instance.
//

var database = require('../database')

module.exports = function (app) {

	// Ask the server to update the current set of parameters.
	app.post("/params/", function (req, res) {
		var jsonString = ''

		req.on('data', function (data) {
			jsonString += data
		});

		req.on('end', function() {
			try {						// handle invalid JSON from client
				var jsonObj = JSON.parse(jsonString)
				var inserts = [jsonObj.value, jsonObj.name]

				if (inserts[0] && inserts[1]) {		// ensure values not undefined
					database.query('UPDATE parameters SET value = ? WHERE name = ?', inserts)
					
					res.sendStatus(200)		// OK
				} else {
					res.sendStatus(400)		// Bad Request
				}

			} catch (err) {					// JSON failed to parse
				res.sendStatus(400)			// Bad Request
			}
		});
	});

	// Ask the server for the current set of parameters.
	app.get("/params/", function(req, res) {
		database.query('SELECT ?? FROM ??', [['name','value'],'parameters'], function(data) {
			res.send(data)
		})
	});	

};
