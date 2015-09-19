var app			= require('express')(),
    http		= require('http').Server(app),
    io			= require('socket.io')(http),
    mysql		= require('mysql'),
    connectionsArray 	= [],
    connection		= mysql.createConnection({
	host	 : 'localhost',
	user	 : 'samuel',
	password : '',
	database : 'scope',
	port	 : 3306
    }),
    POLLING_INTERVAL = 500,
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
http.listen(8133);

// serve static content
app.get('/', function (req, res) {
  res.sendFile(__dirname + '/main.html');
});
	
app.get('/js/jquery.flot.js', function (req, res) {
  res.sendFile(__dirname + '/js/jquery.flot.js');
});

app.use(function(req, res, next) {
  res.status(404).send('<html><h3>There is nothing here...</h3></html>');
});

// polling loop
var pollingLoop = function() {
  // query database
  var query = connection.query('SELECT time,adc FROM data'),
    theData = [];
    
  // set up query listeners
  query
  .on('error', function(err) {
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

  socket.on('run', function() {
    // run button pressed
    // connection.query('REPLACE INTO parameters (name, value) VALUES ("RUN", 1)');
    connection.query('UPDATE parameters SET value = value XOR 1 WHERE name = "RUN"');
    return;
  });

  console.log('Number of connections:' + connectionsArray.length);
  // only if at least one connection
  if (!connectionsArray.length) {
    pollingLoop();
  }

  socket.on('disconnect', function() {
    var socketIndex = connectionsArray.indexOf(socket);
    console.log('socket %s disconnected', socketIndex);
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
