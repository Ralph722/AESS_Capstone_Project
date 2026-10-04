// Browser alerts for the Alumni Portal.
//
// Registered with its own scope ("aess-push/") so it never controls or caches
// the app itself. It only shows pushed alerts and routes taps back to the app.

const appBase = self.registration.scope.replace(/aess-push\/$/, '');
const appIcon = new URL('icons/Icon-192.png', appBase).href;

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { body: event.data ? event.data.text() : '' };
  }

  const title = data.title || 'Alumni Portal';
  const options = {
    body: data.body || '',
    icon: appIcon,
    badge: appIcon,
    tag: data.tag || undefined,
    renotify: Boolean(data.tag),
    data: { route: data.route || '', notificationId: data.notificationId || '' },
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const route = (event.notification.data && event.notification.data.route) || '';
  const appUrl = new URL(appBase);

  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const appWindow = windows.find((client) => client.url.startsWith(appUrl.href));
    if (appWindow) {
      appWindow.postMessage({ type: 'aess-notification-open', route });
      return appWindow.focus();
    }
    const target = new URL(appUrl.href);
    if (route) target.searchParams.set('notification_route', route);
    return self.clients.openWindow(target.href);
  })());
});

self.addEventListener('pushsubscriptionchange', (event) => {
  // The app re-registers the new subscription the next time it opens.
  const options = event.oldSubscription && event.oldSubscription.options;
  if (!options) return;
  event.waitUntil(self.registration.pushManager.subscribe(options).catch(() => {}));
});
