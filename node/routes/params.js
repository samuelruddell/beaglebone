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

	// Ask the server to update the current set of params.
	app.post("/params/", function (req, res) {
		// TODO:
	});

};
