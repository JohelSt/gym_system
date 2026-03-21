importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyANcaMjPNb41Ge9RnR6R5kEeEZu7OmTIio',
  authDomain: 'gym-database01.firebaseapp.com',
  projectId: 'gym-database01',
  storageBucket: 'gym-database01.firebasestorage.app',
  messagingSenderId: '242030683456',
  appId: '1:242030683456:web:5173d237ea89a79e1106a5',
  measurementId: 'G-VHWVMSETZC',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle =
    payload.notification?.title ?? 'Nueva notificacion del sistema';
  const notificationOptions = {
    body: payload.notification?.body ?? 'Tienes una novedad disponible.',
    icon: '/icons/Icon-192.png',
    data: payload.data ?? {},
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      if (clientList.length > 0) {
        return clientList[0].focus();
      }
      return clients.openWindow('/');
    }),
  );
});
