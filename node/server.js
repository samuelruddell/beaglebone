//
// Node.js server
//

// Load the server-specific configurations.
var express 		= require("express"),
    app 		= express(),
    configs 		= require("./configs").server,
    router 		= require("./router"),
    database 		= require("./database")

// Attempt to open a connection to the configured database.
if (database.connect()) {
  console.log("Server: failed to establish database connection. Exiting.")
  return
}

// Load and initialize our API router module.
router.loadRoutes(app)

// Create our HTTP server to serve our static client content.
app.use(express.static(configs.clientContentPath))

// Serve the client start page at the root address.
app.get("/", function (req, res) {
  res.sendFile(configs.clientStartPage)
})

// Create our HTTP socket.
var server = app.listen(configs.port, function () {
  console.log("Server is now listening at http://%s:%s",
    server.address().address, 
    server.address().port)
})

// test database querying
function queryDebug(data) {
	console.log(data)
}

function queryTest(callback) {
	var inserts = [["name","value"], "parameters"]

	database.query("SELECT ?? FROM ??", inserts, callback)
}  

queryTest(queryDebug)
