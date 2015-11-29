//
// routes/control.js
//
// Routes for working with experiment control. Pass in the express app instance.
//
module.exports = function (app) {
	var configs = require('../configs').sockets
	var database = require('../database')

	// Ask the server to run the experiment.
	app.post("/control/run/", function (req, res) {
		// TODO:
	});

	// Ask the server to change oscilloscope mode.
	app.post("/control/mode/", function (req, res) {
		var jsonString = ''
		req.on('data', function (data) {
			jsonString += data
		});

		req.on('end', function() {
			try {
				var jsonObj = JSON.parse(jsonString)
				configs.dataFormat = jsonObj.value

				// insert into database
				var inserts = [jsonObj.value, jsonObj.name]
				if (inserts[0] && inserts[1]) {		// ensure values not undefined
					database.query('UPDATE parameters SET value = ? WHERE name = ?', inserts)
				}
				res.sendStatus(200)		// OK
			} catch(err) {
				res.sendStatus(400)		// Bad Request
			}
		});
	});

	// Ask the server to store the currently active experiment.
	app.post("/control/save/", function (req, res) {
		// TODO:
	});

	// Ask the server to reset the experiment.
	app.post("/control/reset/", function (req, res) {
		// TODO:
	});
};
