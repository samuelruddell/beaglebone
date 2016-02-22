//
// routes/params.js
//
// Routes for working with PID parameters. Pass in the express app instance.
//

var database = require('../database')
var b = require('bonescript')

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
					mux(inserts)
					
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

mux = function(val, callback) {
	if (val[1] == 'IN1'){
		if (val[0] == 1){
			b.digitalWrite('P8_9', b.HIGH)
		} else {
			b.digitalWrite('P8_9', b.LOW)
		}
	} else if (val[1] == 'IN2'){
		if (val[0] == 1){
			b.digitalWrite('P8_34', b.HIGH)
		} else {
			b.digitalWrite('P8_34', b.LOW)
		}
	} else if (val[1] == 'IN3'){
		if (val[0] == 1){
			b.digitalWrite('P8_32', b.HIGH)
		} else {
			b.digitalWrite('P8_32', b.LOW)
		}
	} else if (val[1] == 'IN4'){
		if (val[0] == 1){
			b.digitalWrite('P8_7', b.HIGH)
		} else {
			b.digitalWrite('P8_7', b.LOW)
		}
	} else if (val[1] == 'FAST1'){
		if (val[0] == 1){
			b.digitalWrite('P8_11', b.HIGH)
		} else {
			b.digitalWrite('P8_11', b.LOW)
		}
	} else if (val[1] == 'FAST2'){
		if (val[0] == 1){
			b.digitalWrite('P8_13', b.HIGH)
		} else {
			b.digitalWrite('P8_13', b.LOW)
		}
	} else if (val[1] == 'SLOW1'){
		if (val[0] == 1){
			b.digitalWrite('P8_15', b.HIGH)
		} else {
			b.digitalWrite('P8_15', b.LOW)
		}
	} else if (val[1] == 'SLOW2'){
		if (val[0] == 1){
			b.digitalWrite('P8_17', b.HIGH)
		} else {
			b.digitalWrite('P8_17', b.LOW)
		}
	}
};
