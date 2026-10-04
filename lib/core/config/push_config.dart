/// Public identifiers for phone and browser alerts.
///
/// Everything here ships inside the app and is safe to expose. Private keys
/// (VAPID private key, Firebase service account) live only in Supabase
/// function secrets and are used by the `send-push` edge function.
///
/// The Firebase values identify the `aess-alumni` Android app (they are the
/// same values found in `google-services.json`). Override them for another
/// Firebase project with `--dart-define=FIREBASE_...=...`.
class PushConfig {
  const PushConfig._();

  static const webVapidPublicKey = String.fromEnvironment(
    'WEB_PUSH_VAPID_PUBLIC_KEY',
    defaultValue:
        'BEDS_aV68cEu67QB25xGPXOl6cUOjAkhUByCMdjUznX8SIBozI6O3N23vFGKy-AnqkD0IESK1Hl4d2mmmNeCQvA',
  );

  static const firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyCp28AariNuYyAlIPVH1RkcpYKpsUwvr30',
  );
  static const firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:275163491963:android:1b43ef794561458642fcde',
  );
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '275163491963',
  );
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'aess-alumni',
  );

  static bool get webPushConfigured => webVapidPublicKey.isNotEmpty;

  static bool get fcmConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;
}
