// Firebase Cloud Messaging service worker for web.
// Handles background messages when the app tab is not focused.
// Config must match your Firebase web app (see lib/firebase_options.dart).

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCF4ZM4xeFZZ2vXupc9GZWMe31O9tvB3Rs',
  authDomain: 'awdacenter-eb0a8.firebaseapp.com',
  projectId: 'awdacenter-eb0a8',
  storageBucket: 'awdacenter-eb0a8.firebasestorage.app',
  messagingSenderId: '43994021992',
  appId: '1:43994021992:web:339cbc481d1f1c9e79bbdd',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification && payload.notification.title
    ? payload.notification.title
    : 'Awda Center';
  const notificationOptions = {
    body: payload.notification && payload.notification.body
      ? payload.notification.body
      : '',
    icon: '/icons/Icon-192.png',
  };
  return self.registration.showNotification(notificationTitle, notificationOptions);
});
