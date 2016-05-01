/* client side javascript functions */
var socket = io();

/* on document ready */
$(document).ready(function() {
  // fill all fields from database
  getParams();

  // listen for checkbox changes and POST
  $('#tabs :input[type="checkbox"]').change(function () {
    if(this.checked) {
      var param = JSON.stringify({name: $(this).attr('id'), value: "1"})
    } else {
      var param = JSON.stringify({name: $(this).attr('id'), value: "0"})
    }
    // POST data, GET parameters as callback	
    $.post("/params/", param, getParams) 
  });

  // listen for form field changes and POST
  $('#tabs :input[type="number"]').change(function () {
    if ($(this).attr('id') == 'PGAIN' | $(this).attr('id') == 'IGAIN' | $(this).attr('id') == 'DGAIN' | $(this).attr('id') == 'PGAIN2') {
      var param = JSON.stringify({name: $(this).attr('id'), value: ($(this).val()*32768).toFixed(0)})
    } else {
      var param = JSON.stringify({name: $(this).attr('id'), value: $(this).val()})
    }
    // POST data, GET parameters as callback	
    $.post("/params/", param, getParams) 
  });

  // listen for dropdown changes and POST
  $('select').change(function() {
    var param = JSON.stringify({name: $(this).attr('id'), value: $(this).val()})
    // POST data, GET parameters as callback	
    $.post("/control/mode/", param, getParams) 
  });
});

/* Plot data with flot */
socket.on('data', function (data) {
  if($('#MODE').val() == "2"){
    // plot lockpoint as red circle
    var lockPoint = [[$('#XLOCK').val(), $('#YLOCK').val()]];
    $.plot("#oscilloscope", [data.data, {data:lockPoint, points:{show:true}, color:"#ff0000"}, {
      series: {
        shadowSize: 0     // Drawing is faster without shadows
      },
      grid: {
        clickable: true	// Allow mouse click to determine lock point
      }
    });
  } else {
    // just plot line series
    $.plot("#oscilloscope", [data.data], {
      series: {
        shadowSize: 0     // Drawing is faster without shadows
      },
      grid: {
        clickable: true	// Allow mouse click to determine lock point
      }
    });
  }

});

/* handle oscilloscope mouse click */
$(function() {
  $("#oscilloscope").bind("plotclick", function (event, pos, item) {
    if($('#MODE').val() == "2"){
      // only update XLOCK when X-Y mode
      document.getElementById('XLOCK').value = pos.x.toFixed(0);
      $('#XLOCK').trigger('change')
    }
    if($('#MODE').val() == "1" | $('#MODE').val() == "2"){
      // only update YLOCK on TIME-Y or X-Y mode
      document.getElementById('YLOCK').value = pos.y.toFixed(0);
      $('#YLOCK').trigger('change')
    }
  });
});


/* only to test for now */
function openClose()  {
  if($('#OPENCLOSE').attr("value") == "1"){
    // toggle to closed loop
    var param = JSON.stringify({name: "OPENCLOSE", value: "0"})
  } else {
    // toggle to open loop
    var param = JSON.stringify({name: "OPENCLOSE", value: "1"})
  }
  $.post("/params/", param, getParams) 
}

/* GET parameters and insert into form */
function getParams() {
  $.get("/params/", function(data) {
    for (var obj in data) {
      try {
        // insert values into form
	var element = document.getElementById(data[obj].name)
	if(element.type == 'checkbox') {
	  element.checked = data[obj].value	// checkbox
	} else if (data[obj].name == 'PGAIN' | data[obj].name == 'IGAIN' | data[obj].name == 'DGAIN' | data[obj].name == 'PGAIN2'){
      	  element.value = (data[obj].value/16384).toFixed(4)/2	// represent number in decimal notation
	} else if (data[obj].name == 'OPENCLOSE'){
	  if(data[obj].value){
	    $('#OPENCLOSE').text('OPEN LOOP').addClass("btn-success").removeClass("btn-danger").val("1");
	  } else {
	    $('#OPENCLOSE').text('CLOSED LOOP').addClass("btn-danger").removeClass("btn-success").val("0");
	  }
	} else { 
      	  element.value = data[obj].value	// number field
	}
      } catch (err) {
        // getElementById(...) is null
      }
    }
  });
}
