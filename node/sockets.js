//
// functions to handle sockets
//
(function () {
	// Load socket specific configs.
	var configs 		= require('./configs').sockets,
	    database 		= require('./database'),
	    connectionsArray	= [],
	    isPolling		= false,
	    pollingTimer, inserts;

	// query MySQL database
	var queryData = function() {
		switch(configs.dataFormat) {
		  case "0":	// time - dac
		    inserts = ([['time', 'dac'], 'data']);
		    break;
		  case "1":	// time - adc
		    inserts = ([['time', 'adc'], 'data']);
		    break;
		  default:	// dac - adc
		    inserts = ([['dac', 'adc'], 'data']);
		    break;
		}		  

		// query database
		database.query('SELECT ?? FROM ??', inserts, updateSockets)
	}

	// push data to clients
	var updateSockets = function(data) {
		if(connectionsArray.length) {

			// format data as array for flot
			var flotData = []
			var row, array
			for (var rows in data) {
				row = data[rows]
			    	array = []
				for (var key in row) {
					array.push(row[key])
				}
				flotData.push(array)
			}

			// set timer to repeat function
			pollingTimer = setTimeout(queryData, configs.pollingInterval)

			// push data to sockets
			connectionsArray.forEach(function(tmpSocket) {
				tmpSocket.volatile.emit('data', {data:flotData})
			})

		} else {
			console.log('Sockets: No more socket connections')
			isPolling = false;
		}
	}

	// client has connected
	var connect = function(socket) {
		console.log('Sockets: Number of connections %s', connectionsArray.length)
		if (!connectionsArray.length) {
			if (!isPolling) {
				isPolling = true;
				queryData()
			}
		}		

		// socket listeners
		socket
		// disconnect
		.on('disconnect', function() {
			var socketIndex = connectionsArray.indexOf(socket)
			console.log('Sockets: socket %s disconnected', socketIndex)
			if (~socketIndex) {
			  	connectionsArray.splice(socketIndex, 1);
			}
		})
		// run (temporary for debug, will use routes)
		.on('run', function() {
			console.log('Sockets: Number of connections %s', connectionsArray.length)
		})

		console.log('Sockets: New socket connected')
		connectionsArray.push(socket);
	}

	// export functions
	module.exports.connect 	= connect
}())
