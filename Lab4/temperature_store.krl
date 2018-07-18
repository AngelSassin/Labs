ruleset temperature_store {
  
  meta {
    shares temperatures, threshold_violations, inrange_temperatures
    provides temperatures, threshold_violations, inrange_temperatures
  }
  
  global {
    temperatures = function() {
      ent:temps;
    }
    
    threshold_violations = function() {
      ent:violations;
    }
    
    inrange_temperatures = function() {
			temperatures().filter(function(x) {
				threshold_violations().none(function(y) {
					x{"time"} == y{"time"};
				});
			});
    }
  }
  
  rule collect_temperatures {
    select when wovyn new_temperature_reading
    pre {
      temperature = event:attr("temperature");
      timestamp = event:attr("timestamp");
    }
    if temperature then
      send_directive("New reading. ", {"TEMP": temperature, "TIME": timestamp});
    fired {
      ent:temps := ent:temps.defaultsTo([]).append({"time": timestamp, "temp": temperature});
    }
  }
  
  rule collect_threshold_violations {
    select when wovyn threshold_violation
    pre {
      temperature = event:attr("temperature");
      timestamp = event:attr("timestamp");
    }
    if temperature then
      send_directive("New reading.", {"TEMP": temperature, "TIME": timestamp});
    fired {
      ent:violations := ent:violations.defaultsTo([]).append({"time": timestamp, "temp": temperature});
    }
  }
  
  rule clear_temeratures {
    select when sensor reading_reset
    send_directive("All temperatures cleared.");
    always {
      ent:temps := [];
      ent:violations := [];
    }
  }
  
}
