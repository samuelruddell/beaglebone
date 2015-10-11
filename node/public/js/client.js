/* client side javascript functions */
var socket = io();

socket.on('notification', function (data) {
  $.plot("#oscilloscope", [data.theData], {
    series: {
    	shadowSize: 0 		// Drawing is faster without shadows
    }
  });
});

function run(){
  socket.emit('run');
}
