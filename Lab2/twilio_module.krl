ruleset twilio_module {
  
  meta {
    use module twilio_keys
    use module twilio_conf alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
    shares
        messages
  }
  
  global {
    messages = function(to, from, page) {
      page = page.defaultsTo(0);
      content = twilio:messages(to, from, page);
      messages = content{"messages"};
      content;
    }
  }
 
  rule sms {
    select when twilio send
    every {
      twilio:send_sms(event:attr("to"),
                     event:attr("from"),
                     event:attr("message").klog("MESSAGE SENT")
                    )
      send_directive("say", {"response": "Sent to " + event:attr("to") + " from " + event:attr("from") + ": " + event:attr("message")})
    }
  }
}