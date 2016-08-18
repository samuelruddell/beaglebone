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
			pinName = 'P9_24'
		} else if (row.name == 'IN2') {
			pinName = 'P9_26'
		} else if (row.name == 'IN3') {
			pinName = 'P9_25'	
		} else if (row.name == 'IN4') {
			pinName = 'P9_23'
		} else if (row.name == 'SLOW1') {
			pinName = 'P8_7'
		} else if (row.name == 'SLOW2') {
			pinName = 'P8_9'
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

			b.pinMode('P9_24', b.OUTPUT)
			b.pinMode('P9_26', b.OUTPUT)
			b.pinMode('P9_25', b.OUTPUT)
			b.pinMode('P9_23', b.OUTPUT)
			b.pinMode('P8_7', b.OUTPUT)
			b.pinMode('P8_9', b.OUTPUT) 

			//database.query('SELECT ?? FROM ?? WHERE ?? > 100 AND ?? < 109', [['name','value'],'parameters','addr','addr'], function(data) {
		//		var row, array
		//		for (var rows in data) {
		//			
		//			setup(data[rows])
		//		}
//
//			})

		}
	}	
}())
