//
// functions to handle sockets
//
(function () {
	// Load socket specific configs.
	var configs 		= require('./configs').sockets,
	    database 		= require('./database'),
	    connectionsArray	= [],
	    isPolling		= false;

	// query MySQL database
	var pollingLoop = function() {
		var inserts = ([['time', 'adc'], 'data']); // temporary *************************
		// query database
		database.query('SELECT ?? FROM ??', inserts, updateSockets)
	}

	// push data to clients
	var updateSockets = function(data) {
		if(connectionsArray.length) {

			// set timer to repeat function
			pollingTimer = setTimeout(pollingLoop, configs.pollingInterval)

			// push data to sockets
			connectionsArray.forEach(function(tmpSocket) {
				tmpSocket.volatile.emit('notification', {data:data})
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
				pollingLoop()
				isPolling = true;
			}
		}		

		// socket listeners
		socket
		.on('disconnect', function() {
			var socketIndex = connectionsArray.indexOf(socket)
			console.log('Sockets: socket %s disconnected', socketIndex)
			if (~socketIndex) {
			  	connectionsArray.splice(socketIndex, 1);
			}
		})
		.on('run', function() {
			console.log('Sockets: Number of connections %s', connectionsArray.length)
		})

		console.log('Sockets: New socket connected')
		connectionsArray.push(socket);
	}

	// export functions
	module.exports.connect 	= connect
}())
