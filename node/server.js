var server		= require('http').createServer(handler),
    io			= require('socket.io').listen(server),
    fs			= require('fs'),
    mysql		= require('mysql'),
    connectionsArray 	= [],
    connection		= mysql.createConnection({
	host	 : 'localhost',
	user	 : 'samuel',
	password : '',
	database : 'scope',
	port	 : 3306
    }),
    POLLING_INTERVAL = 200,
    pollingTimer;

// connect to MySQL database
connection.connect(function(err) {
  if(err) {
    console.log(err);
  } else {
    console.log('Connected to MySQL database');
  }
});

// create web server
server.listen(8133);

// when server ready, load main.html page
function handler(request, response) {
  var file = undefined;
  if(request.url === '/js/jquery.js' || request.url === '/js/jquery.flot.js') {
    file = request.url;
  } else {
    file = '/main.html';
  }
  fs.readFile( __dirname + file, function( err, data) {
    if (err) {
      console.log(err);
      response.writeHead(500);	// internal error
      return response.end('Error with request');
    }
    response.writeHead(200); 	// request OK
    response.end(data);		// respond with html page
  });
}


// polling loop
var pollingLoop = function() {
  // query database
  var query = connection.query('SELECT time,adc FROM data'),
    theData = [];
    
  // set up query listeners
  query
  .on('error', function(err) {
    // error
    console.log(err);
    updateSockets(err);
  })
  .on('result', function(data) {
    // fill array with the data
    theData.push([data.time, data.adc]); 
  })
  .on('end', function() {
    // loop only if there are sockets still connected
    if(connectionsArray.length) {
      pollingTimer = setTimeout(pollingLoop, POLLING_INTERVAL);
      updateSockets({
        theData:theData
      });
    } else {
      console.log('No more socket connections')
    }
  });
};

// create websocket connection to keep content updated
io.sockets.on('connection', function(socket) {
  console.log('Number of connections:' + connectionsArray.length);
  // only if at least one connection
  if (!connectionsArray.length) {
    pollingLoop();
  }

  socket.on('disconnect', function() {
    var socketIndex = connectionsArray.indexOf(socket);
    console.log('socketID %s disconnected', socketIndex);
    if (~socketIndex) {
      connectionsArray.splice(socketIndex, 1);
    }
  });

  console.log('New socket connected');
  connectionsArray.push(socket);
});

var updateSockets = function(data) {
  connectionsArray.forEach(function(tmpSocket) {
    tmpSocket.volatile.emit('notification', data);
  });
};
