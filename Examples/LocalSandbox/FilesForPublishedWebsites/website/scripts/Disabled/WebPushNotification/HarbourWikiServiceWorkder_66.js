const applicationServerPublicKey = 'BHs3CwdJ-p3qQ-zBUXXYbEkp_7kzeXT8agdEymB4DPBF83WQ2gNyNMIu9tR9GY4p9lY2JzeJREhLSWGP0IXOLg4';

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

self.addEventListener('push', function(event) {
  const j_received_data = event.data.json();
  const j_url = j_received_data.url;
  const j_title = j_received_data.title;
  const j_options = {
    body: j_received_data.body,
    icon: 'https://harbour.wiki/images/Harbour_logo_64.png',
    badge: 'https://harbour.wiki/images/Harbour_logo_64.png',
    data: {
      url: j_url
    }
 };
 event.waitUntil(self.registration.showNotification(j_title, j_options));
});

self.addEventListener('notificationclick', function(event) {
  const j_url = event.notification.data.url;
  event.notification.close();
  event.waitUntil(
    clients.openWindow(j_url)
  );
});
