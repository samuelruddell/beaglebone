//
// gpio.js
//
// handles beaglebone gpio pins
//


(function () {
	var 	b		= require('bonescript'),
    		database 	= require('./database')

	var     setup = function(row) {
		// initial setup of multiplexer pins

		var pinName;

		if (row.name == 'IN1') {
			pinName = 'P8_9'
		} else if (row.name == 'IN2') {
			pinName = 'P8_34'
		} else if (row.name == 'IN3') {
			pinName = 'P8_32'	
		} else if (row.name == 'IN4') {
			pinName = 'P8_7'
		} else if (row.name == 'FAST1') {
			pinName = 'P8_11'
		} else if (row.name == 'FAST2') {
			pinName = 'P8_13'
		} else if (row.name == 'SLOW1') {
			pinName = 'P8_15'
		} else if (row.name == 'SLOW2') {
			pinName = 'P8_17'
		}

		if (row.value) {
			b.digitalWrite(pinName, b.HIGH)
		} else {
			b.digitalWrite(pinName, b.LOW)
		}


	}

	module.exports = {
		// initialise GPIO pins
		init: function () {
			// initialise hardware

			b.pinMode('P8_9', b.OUTPUT)
			b.pinMode('P8_34', b.OUTPUT)
			b.pinMode('P8_32', b.OUTPUT)
			b.pinMode('P8_7', b.OUTPUT)
			b.pinMode('P8_11', b.OUTPUT)
			b.pinMode('P8_13', b.OUTPUT)
			b.pinMode('P8_15', b.OUTPUT)
			b.pinMode('P8_17', b.OUTPUT) 

			database.query('SELECT ?? FROM ?? WHERE ?? > 100 AND ?? < 109', [['name','value'],'parameters','addr','addr'], function(data) {
				var row, array
				for (var rows in data) {
					
					setup(data[rows])
				}

			})

		}
	}	
}())
