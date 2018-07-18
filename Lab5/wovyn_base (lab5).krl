ruleset wovyn_base {
  meta {
    shares __testing
  }
  
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ { "domain": "wovyn", "type": "heartbeat" },
                                { "domain": "wovyn", "type": "heartbeat",
                                "attrs": [ "genericThing" ] }] }
    
    fromNumber = "+13852090373";
    toNumber = "+18018357906";
  }
  
  rule process_heartbeat {
    select when wovyn heartbeat where event:attr("genericThing")
    pre {
      data = event:attr("genericThing");
      temp = data["data"]["temperature"][0]["temperatureF"];
    }
    if data then
      send_directive("Heartbeat");
    fired {
      raise wovyn event "new_temperature_reading"
        attributes { "temperature": temp, "timestamp": time:now()  }
    }
  }
  
  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre {
      temperature = event:attr("temperature");
      timestamp = event:attr("timestamp");
    }
    send_directive("READING", {"TEMP": temperature, "TIME": timestamp});
    fired {
      ent:threshold := ent:threshold.defaultsTo(77.5);
      raise wovyn event "threshold_violation"
        attributes { "temperature": temperature, "timestamp": timestamp  }
        if temperature > ent:threshold;
    }
  }
  
  rule threshold_notification  {
    select when wovyn threshold_violation
    pre {
      temperature = event:attr("temperature");
      timestamp = event:attr("timestamp");
    }
    send_directive("THRESHOLD", {"TEMP": temperature, "TIME": timestamp});
    fired {
      raise twilio event "send"
        attributes { "from": fromNumber, "to": toNumber, "message": "The temperature is high: " + temperature + "F" }
    }
  }
  
  rule change_threshold {
    select when sensor profile_updated
    pre {
      location = event:attr("location");
      name = event:attr("name");
      threshold = event:attr("threshold");
      number = event:attr("number");
    }
    
    fired {
      ent:threshold := threshold.decode();
    }
  }
}
