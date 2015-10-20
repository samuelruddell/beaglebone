//
// routes/params.js
//
// Routes for working with experiment parameters. Pass in the express app instance.
//
module.exports = function (app) {
	var database = require('../database')

	// Ask the server for the current set of parameters.
	app.get("/params/", function (req, res) {
		database.query('SELECT ?? FROM ??', [['name','value'],'parameters'], function(data) {
			res.send(data)
		})
	});

	// Ask the server to update the current set of parameters.
	app.post("/params/", function (req, res) {
		var jsonString = ''

		req.on('data', function (data) {
			jsonString += data
		});

		req.on('end', function() {
			var jsonObj = JSON.parse(jsonString)
			console.log(jsonObj)
		})

		var queryString = "UPDATE ?? SET value = ? WHERE name = ?";
		var inserts = ['parameters', '0', 'IRESET']
		database.query(queryString, inserts, function() {})

		res.send('hi\n')
		//var inserts = [1,'TEST']
		//database.query('UPDATE parameters SET value = ?? WHERE name = ??', inserts)
	});

};
