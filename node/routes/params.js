//
// routes/params.js
//
// Routes for working with experiment parameters. Pass in the express app instance.
//
var database = require('../database')

module.exports = function (app) {

	// Ask the server to update the current set of parameters.
	app.post("/params/", function (req, res) {
		var jsonString = ''
		var inserts

		req.on('data', function (data) {
			jsonString += data
		});

		req.on('end', function() {
			var jsonObj = JSON.parse(jsonString)
			inserts = [jsonObj.value, jsonObj.name]

			if (inserts[0] && inserts[1]) {		// ensure values not undefined
				console.log(inserts)
				database.query("UPDATE parameters SET value = ? WHERE name = ?", inserts)
			}

			res.redirect('/')
		});
	});

	// Ask the server for the current set of parameters.
	app.get("/params/", function(req, res) {
		database.query('SELECT ?? FROM ??', [['name','value'],'parameters'], function(data) {
			res.send(data)
		})
	})	
};

// send parameters to client
