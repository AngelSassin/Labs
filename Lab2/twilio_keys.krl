ruleset twilio_keys {
  meta {
    key twilio {
          "account_sid": "SID HERE", 
          "auth_token" : "TOKEN HERE"
    }
    provides keys twilio to twilio_module
  }
}
