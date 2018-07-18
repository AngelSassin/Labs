ruleset sensor_profile {
  meta {
    shares getProfile
    provides getProfile
  }
  
  global {
    getProfile = function() {
      prof = [].append(ent:profile);
      prof
    }
  }
  
  rule update_profile {
    select when sensor profile_updated
    pre {
      location = event:attr("location");
      name = event:attr("name");
      threshold = event:attr("threshold");
      number = event:attr("number");
    }
    
    fired {
      ent:profile := ent:profile.defaultsTo({"name": "Sensor", "location": "Somewhere", "threshold": 77.5, "number": "N/A"});
      ent:profile := {"name": name, "location": location, "threshold": threshold, "number": number};
    }
  }
}
