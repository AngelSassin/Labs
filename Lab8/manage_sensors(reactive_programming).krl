ruleset manage_sensors {
  
  meta {
    shares sensors, getSensor, getTemperatures, __testing, latestReports
    provides sensors, getSensor, getTemperatures, __testing, latestReports
    use module io.picolabs.wrangler alias Wrangler
    use module io.picolabs.subscription alias Subscriptions
  }
  
  global {
    __testing = { "queries": [ { "name": "sensors" },
                               { "name": "latestReports" },
                               { "name": "getSensor", "args":["name"]},
                               { "name": "getTemperatures", "args":[]}   ],
                               
                  "events": [ { "domain": "sensor", "type": "new_sensor", "attrs": [ "name" ] },
                              { "domain": "sensor", "type": "reports" },
                              { "domain": "sensor", "type": "report_deletion" },
                              { "domain": "sensor", "type": "add_sensor", "attrs": [ "name", "eci" ] },
                              { "domain": "sensor", "type": "unneeded_sensor", "attrs": [ "name" ] }
                            ] }
    
    
    
    default_threshold = 78;
    
    sensors = function() {
      ent:sensors;
    }
    
    getSensor = function(name) {
      ent:sensors{name};
    }
    
    getTemperatures = function() {
      keys = ent:sensors.keys();
      loopSensorTemperatures(keys);
    }
    
    latestReports = function() {
      reports = ent:reports.keys();
      latest = reports.reverse().map(function(report) {
        {"report_id": report, "report": ent:reports{report}};
      });
      latest.slice(0,latest.length() >= 5 => 4 | latest.length()-1);
    }
    
    loopSensorTemperatures = function(keys) {
      eci = ent:sensors{keys[0]}{"Tx"};
      return = {"name": keys[0], "eci": eci, "temperatures": Wrangler:skyQuery(eci,"temperature_store","temperatures")};
      keys = keys.slice(1,keys.length()-1);
      (keys.length() == 0) => return | return.union(loopSensorTemperatures(keys));
    }
  }
  
  rule create_sensor {
    select when sensor new_sensor 
    pre {
      name = event:attr("name")
      exists = ent:sensors{name}
    }
    if exists then
      send_directive("Sensor already exists", {"name": name})
    notfired {
      ent:sensors := ent:sensors.defaultsTo({});
      raise wrangler event "child_creation"
        attributes { "name": name, "color": "#ffff00", "rids": ["io.picolabs.subscription", "temperature_store", "wovyn_base", "sensor_profile"]}
    }
  }
  
  rule subscribe_to_sensor {
    select when sensor add_sensor 
    pre {
      name = event:attr("name");
      eci = event:attr("eci");
    }
    send_directive("Subscribing to sensor", {"name": name, "eci": eci})
    fired {
      ent:sensors := ent:sensors.defaultsTo({});
      raise wrangler event "subscription" 
        attributes { 
          "name" : name,
          "Rx_role": "sensor manager",
          "Tx_role": "sensor",
          "channel_type": "subscription",
          "wellKnown_Tx" : eci
       }
    }
  }
  
  rule store_new_sensor {
    select when wrangler child_initialized
    pre {
      parent = event:attr("parent_eci");
      eci = event:attr("eci");
      name = event:attr("name");
    }
    if parent == meta:eci then
    every {
      event:send({
        "eci": eci, "eid": "update_profile",
        "domain": "sensor", "type": "profile_updated",
        "attrs": { "name": name, "location": "BYU", "threshold": default_threshold, "number": "+18018357906" } } )
      send_directive("New sensor created", {"name": name, "eci": eci});
    }
    fired {
      raise wrangler event "subscription" 
        attributes { 
          "name" : name,
          "Rx_role": "sensor manager",
          "Tx_role": "sensor",
          "channel_type": "subscription",
          "wellKnown_Tx" : eci
       }
    }
  }
  
  rule store_pending_subscription {
    select when wrangler outbound_pending_subscription_added
    pre {
      attrs = event:attrs;
      Rx = event:attr("Rx");
      name = event:attr("name");
    }
    send_directive("Attributes", {"attrs": attrs, "Rx": Rx, "name": name});
    fired {
      ent:sensors := ent:sensors.defaultsTo({}).put(name, ent:sensors{name}.defaultsTo({}).put({"Rx": Rx}));
    }
  }

  rule store_new_subscription {
    select when wrangler subscription_added
    pre {
      attrs = event:attrs;
      Tx = event:attr("_Tx");
      name = Wrangler:skyQuery(Tx, "io.picolabs.wrangler", "nameFromEci", {"eci": Tx});
    }
    send_directive("Attributes", {"attrs": attrs, "Tx": Tx, "name": name});
    fired {
      ent:sensors := ent:sensors.defaultsTo({}).put(name, ent:sensors{name}.defaultsTo({}).put({"Tx": Tx}));
    }
  }
  
  rule init_reports {
    select when sensor reports
    pre {
      id = random:uuid();
    }
    always {
      raise sensor event "get_reports"
        attributes {"id": id}
    }
  }
  
  rule get_reports {
    select when sensor get_reports
      foreach ent:sensors setting(value, sensor)
    pre {
      id = event:attr("id");
    }
    every {
      send_directive("GET REPORTS NOW", value);
      event:send({
        "eci": value{"Tx"}, "eid": "getting_report",
        "domain": "sensor", "type": "report_request",
        "attrs": { "originator": value{"Rx"}, "sensor": sensor, "id": id } } )
    }
  }
  
  rule compile_report {
    select when sensor report_returned
    pre {
      id = event:attr("id");
      sensor = event:attr("sensor");
      temp = event:attr("temperature"){"temp"};
      time = event:attr("temperature"){"time"};
    }
    send_directive("Received report", {"sensor": sensor});
    fired {
      ent:reports := ent:reports.defaultsTo({}).put(id, {"time": time:now(), "reports": ent:reports{id}{"reports"}.defaultsTo([]).append({"sensor": sensor, "temperature": temp, "time": time })})
    }
  }
  
  rule clear_reports {
    select when sensor report_deletion
    always {
      ent:reports := {};
    }
  }
  
  rule remove_sensor {
    select when sensor unneeded_sensor
    pre {
      name = event:attr("name");
      eci = ent:sensors{name}{"Tx"};
      subscription = ent:sensors{name}{"Rx"};
      exists = ent:sensors{name} != null;
    }
    if exists then
      send_directive("Deleting sensor", {"name": name, "eci": eci})
    fired {
      raise wrangler event "subscription_cancellation"
        attributes {"Rx": subscription};
      ent:sensors := ent:sensors.delete(name);
      raise wrangler event "child_deletion"
        attributes {"name": name};
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
}
