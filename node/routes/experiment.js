//
// routes/experiment.js
//
// Routes for working with historical experiment data. Pass in the express app instance.
//
module.exports = function (app) {

	// Ask the server to retrieve a list of experiments from the database.
	app.get("/experiment/", function (req, res) {
		// TODO:
	});

	// Ask the server to retrieve detailed experiment data for the passed experiment ID.
	app.post("/experiment/detail/:id", function (req, res) {
		// TODO:
	});
};
