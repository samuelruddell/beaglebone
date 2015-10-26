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
    },
    grid: {
      clickable: true	// Allow mouse click to determine lock point
    }
  });
});

// handle oscilloscope mouse click
$(function() {
  $("#oscilloscope").bind("plotclick", function (event, pos, item) {
    document.getElementById('XLOCK').value = pos.x.toFixed(0);
    $('#XLOCK').trigger('change')
    document.getElementById('YLOCK').value = pos.y.toFixed(0);
    $('#YLOCK').trigger('change')
  });
})

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
