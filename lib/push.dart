import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core.dart';

/// Push notifications. Stays switched off until the FIREBASE_* values are supplied at build time.
class Push {
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static bool ready = false, _listening = false;

  static Future<void> init() async {
    if (_appId.isEmpty || !Platform.isAndroid) return;
    try {
      await Firebase.initializeApp(options: const FirebaseOptions(apiKey: String.fromEnvironment('FIREBASE_API_KEY'), appId: _appId, messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'), projectId: String.fromEnvironment('FIREBASE_PROJECT_ID')));
      ready = true;
    } catch (_) { ready = false; }
  }

  static Future<void> register() async {
    if (!ready) return;
    try {
      final m = FirebaseMessaging.instance;
      final p = await m.requestPermission();
      if (p.authorizationStatus == AuthorizationStatus.denied) return;
      final t = await m.getToken();
      if (t != null) await _save(t);
      if (!_listening) { _listening = true; m.onTokenRefresh.listen(_save); }
    } catch (_) {}
  }

  static Future<void> _save(String t) async {
    try { await sb.rpc('register_device', params: {'t': t, 'p': Platform.isIOS ? 'ios' : 'android'}); } catch (_) {}
  }

  static Future<void> unregister() async {
    if (!ready) return;
    try { final t = await FirebaseMessaging.instance.getToken(); if (t != null) await sb.from('device_tokens').delete().eq('token', t); } catch (_) {}
  }
}
