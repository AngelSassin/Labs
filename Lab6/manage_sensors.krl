ruleset manage_sensors {
  
  meta {
    shares sensors, getSensor, getTemperatures, __testing
    provides sensors, getSensor, getTemperatures, __testing
    use module io.picolabs.wrangler alias Wrangler
  }
  
  global {
    __testing = { "queries": [ { "name": "sensors" },
                               { "name": "getSensor", "args":["name"]},
                               { "name": "getTemperatures", "args":[]}   ],
                               
                  "events": [ { "domain": "sensor", "type": "new_sensor", "attrs": [ "name" ] },
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
    
    loopSensorTemperatures = function(keys) {
      return = {"name": keys[0], "eci": ent:sensors{keys[0]}, "temperatures": Wrangler:skyQuery(ent:sensors{keys[0]},"temperature_store","temperatures")};
      keys = keys.slice(1,keys.length()-1);
      (keys.length() == 0) => return | return.union(loopSensorTemperatures(keys));
    }
  }
  
  rule create_sensor {
    select when sensor new_sensor 
    pre {
      name = event:attr("name")
      owner = meta:eci
      exists = ent:sensors{name}
    }
    if exists then
      send_directive("Sensor already exists", {"name": name})
    notfired {
      ent:sensors := ent:sensors.defaultsTo({});
      raise wrangler event "child_creation"
        attributes { "name": name, "owner": owner, "color": "#ffff00", "rids": ["temperature_store", "wovyn_base", "sensor_profile"]}
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
      ent:sensors := ent:sensors.defaultsTo({}).put(name, eci);
    }
  }
  
  rule delete_sensor {
    select when sensor unneeded_sensor
    pre {
      name = event:attr("name");
      eci = ent:sensors{name}
      exists = eci != null;
    }
    if exists then
      send_directive("Deleting sensor", {"name": name})
    fired {
      ent:sensors := ent:sensors.delete(name);
      raise wrangler event "child_deletion"
        attributes {"name": name};
    }
  }
}
