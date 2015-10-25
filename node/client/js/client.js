/* client side javascript functions */
var socket = io();

// on document ready
$(document).ready(function() {
  // fill all fields from database
  getParams();

  // listen for field changes and POST
  $('#pidControl :input').change(function () {
    var param = JSON.stringify({name: $(this).attr('id'), value: $(this).val()})
    // POST data, GET parameters as callback	
    $.post("/params/", param, getParams) 
  })
})

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
        // insert values into form
        document.getElementById(data[obj].name).value = data[obj].value;
      } catch (err) {
        // getElementById(...) is null
      }
    }
  })
}
