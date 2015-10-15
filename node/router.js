//
// Express wrapper. Defines usable routes that can be hooked into by severside functionality.
//
// Usage - load through the Commonjs require module pattrern:
//		var router = require("router");
//		var success = router.initialize();
//
(function () {
	// Load the route-specific configurations.
	var configs = require("./configs").route;

	// Load the filesystem module.
	var fs = require("fs");

	// Initialize the router by loading all the routes contained in the /routes directory.
	module.exports.loadRoutes = function (app) {
		// Load each file in the route directory.
		fs.readdirSync(configs.routeDirectory).forEach(
			function(file) {
		        var name = file.substr(0, file.indexOf('.'));
		        require('./routes/' + name)(app);
		    });
	}

}());
