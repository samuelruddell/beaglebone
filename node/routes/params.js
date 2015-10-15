//
// routes/params.js
//
// Routes for working with experiment parameters. Pass in the express app instance.
//
module.exports = function (app) {
	
	// Ask the server for the current set of parameters.
	app.get("/params/", function (req, res) {
		// TODO:
	});

	// Ask the server to update the current set of params.
	app.post("/params/", function (req, res) {
		// TODO:
	});

};
