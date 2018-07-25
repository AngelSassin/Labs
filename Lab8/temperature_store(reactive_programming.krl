ruleset temperature_store {
  
  meta {
    shares temperatures, threshold_violations, inrange_temperatures, current, __testing
    provides temperatures, threshold_violations, inrange_temperatures, current, __testing
  }
  
  global {
    __testing = { "queries": [ { "name": "current" },
                               { "name": "temperatures", "args":[] },
                               { "name": "threshold_violations", "args":[] },
                               { "name": "inrange_temperatures", "args":[] } ],
                               
                  "events": [ { "domain": "wovyn", "type": "new_temperature_reading", "attrs": [ "temperature", "timestamp" ] },
                              { "domain": "sensor", "type": "reading_reset", "attrs": [ ] }
                            ] }
    
    current = function() {
      c = [].append(ent:temps[ent:temps.length()-1]);
      c;
    }
    
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
      temperature = event:attr("temperature").decode();
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
  
  rule generate_report {
    select when sensor report_request
    pre {
      from = event:attr("originator");
      temp = current()[0];
      name = event:attr("sensor");
      id = event:attr("id");
    }
    event:send({
        "eci": from, "eid": "sending_report",
        "domain": "sensor", "type": "report_returned",
        "attrs": { "temperature": temp, "sensor": name, "id": id} } )
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
