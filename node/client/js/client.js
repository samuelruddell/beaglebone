/* client side javascript functions */
var socket = io();

// Plot data with flot
socket.on('data', function (data) {
  $.plot("#oscilloscope", [data.data], {
    series: {
      shadowSize: 0     // Drawing is faster without shadows
    }
  });
});

// only to test for now
function run()  {
  socket.emit('run');
}

// GET parameters and insert into form
function getParams() {
  $.get("/params/", function(data) {
    for (var obj in data) {
      try {
        var elem = document.getElementById(data[obj].name).value = data[obj].value;
      } catch (err) {
        // getElementById(...) is null
      }
    }
  })
}
