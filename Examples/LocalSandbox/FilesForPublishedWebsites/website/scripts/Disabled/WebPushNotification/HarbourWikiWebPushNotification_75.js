//'use strict';

const applicationServerPublicKey = 'BHs3CwdJ-p3qQ-zBUXXYbEkp_7kzeXT8agdEymB4DPBF83WQ2gNyNMIu9tR9GY4p9lY2JzeJREhLSWGP0IXOLg4';

var WPNCurrentSubscription="";

let isSubscribed = false;
let swRegistration = null;

function urlB64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - base64String.length % 4) % 4);
  const base64 = (base64String + padding)
    .replace(/\-/g, '+')
    .replace(/_/g, '/');

  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);

  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

function updateBtn() {
  if (Notification.permission === 'denied') {
    $("#WPNButton").text("Push Messaging Blocked!");
    $("#WPNButton").prop('disabled', true);
    updateSubscriptionOnServer(null);
    return;
  }

  if (isSubscribed) {
    $("#WPNButton").text("Disable Push Messaging");
  } else {
    $("#WPNButton").text("Enable Push Messaging");
  }

  $("#WPNButton").prop('disabled', false);
}

function updateSubscriptionOnServer(subscription) {
  if (subscription) {
    $("#WPNSubscriptionInfo").show();
  } else {
    $("#WPNSubscriptionInfo").hide();
  }
}

function subscribeUser() {
  var j_subscription_info = '';
  
  console.log('Wants to subscribed 75.');
  
  const applicationServerKey = urlB64ToUint8Array(applicationServerPublicKey);
  swRegistration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: applicationServerKey
  })
  .then(function(subscription) {
	j_subscription_info = JSON.stringify(subscription);
	
    console.log('User is subscribed 75.');

    updateSubscriptionOnServer(subscription);

    isSubscribed = true;

    updateBtn();
  })
  .catch(function(err) {
    console.log('Failed to subscribe the user: ', err);
    updateBtn();
  })
  .then(function() {
    console.log("Did Subscribe "+j_subscription_info);
    
    WPNCurrentSubscription = j_subscription_info;
    
    $.ajax({url:"index.asp?page=wpnsubscription",
  		    type:"POST",
  		    data:j_subscription_info.replace('{"endpoint":','{"action":"subscribe","endpoint":'),
  		    contentType:"application/json; charset=utf-8",
  		    dataType:"json",
  		    success: function(){
  		    }
		  });
    
  });

}

function unsubscribeUser() {
  var j_subscription_info = '';
  swRegistration.pushManager.getSubscription()
  .then(function(subscription) {
    if (subscription) {
	  
	  //Will Unsuscibe
	  j_subscription_info = JSON.stringify(subscription);
	  //console.log("Will Unsubscribe "+j_subscription_info);
	  
      return subscription.unsubscribe();
    }
  })
  .catch(function(error) {
    console.log('Error unsubscribing', error);
  })
  .then(function() {
    console.log("Did Unsubscribe "+j_subscription_info);
    
    $.ajax({url:"index.asp?page=wpnsubscription",
  		    type:"POST",
  		    data:j_subscription_info.replace('{"endpoint":','{"action":"unsubscribe","endpoint":'),
  		    contentType:"application/json; charset=utf-8",
  		    dataType:"json",
  		    success: function(){
  		    }
		  });
	
    updateSubscriptionOnServer(null);
    WPNCurrentSubscription = "";

    //console.log('User is unsubscribed.');
    isSubscribed = false;

    updateBtn();
  });
}

function initializeUI() {
  $("#WPNButton").click(function() {
    $("#WPNButton").prop('disabled', true);
    if (isSubscribed) {
      unsubscribeUser();
    } else {
      subscribeUser();
    };
    return false;
    });

  $("#WPNSendTest").click(function() {

	$("#WPNSendTest").prop('disabled', true);
    $.ajax({url:"index.asp?page=wpnsubscription",
  		    type:"POST",
  		    data:WPNCurrentSubscription.replace('{"endpoint":','{"action":"SendTestNotification","endpoint":'),
  		    contentType:"application/json; charset=utf-8",
  		    dataType:"json",
  		    success: function(){
  		    }
		  });

	$("#WPNSendTest").prop('disabled', false);

	var j_Now = new Date();
	var j_Now_String = j_Now.toLocaleTimeString();

	$("#WPNSubscriptionSentText").text('You requested a "Test Notification". It should arrive on your device within 5 minutes from '+j_Now_String);
	
	$("#WPNSubscriptionSent").show();

    return false;
    });
  

  // Set the initial subscription value
  swRegistration.pushManager.getSubscription()
  .then(function(subscription) {
    isSubscribed = !(subscription === null);

    updateSubscriptionOnServer(subscription);

    if (isSubscribed) {
	  const j_subscription_info = JSON.stringify(subscription);
	  WPNCurrentSubscription = j_subscription_info;
	  
      console.log('User IS subscribed. '+j_subscription_info);
    } else {
      console.log('User is NOT subscribed.');
	  WPNCurrentSubscription = "";
    }

    updateBtn();
  });
}


