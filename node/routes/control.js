//
// routes/control.js
//
// Routes for working with experiment control. Pass in the express app instance.
//
module.exports = function (app) {

	// Ask the server to run the experiment.
	app.post("/control/run/", function (req, res) {
		// TODO:
	});

	// Ask the server to stop running the experiment.
	app.post("/control/stop/", function (req, res) {
		// TODO:
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
