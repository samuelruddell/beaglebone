/* client side javascript functions */
var socket = io();

socket.on('data', function (data) {
  $.plot("#oscilloscope", [data.data], {
    series: {
    	shadowSize: 0 		// Drawing is faster without shadows
    }
  });
});

function run(){
  socket.emit('run');
}
