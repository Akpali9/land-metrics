import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin.dart';
import 'auth.dart';
import 'fx.dart';
import 'push.dart';
import 'package:sentry_flutter/sentry_flutter.dart' as sentry;
import 'core.dart';
import 'user.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://znughsflubewjpojsvip.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpudWdoc2ZsdWJld2pwb2pzdmlwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMyNzUxMjQsImV4cCI6MjEwODg1MTEyNH0.ekm81T4H1WxmnA8ZGGBR4Cm5nMfY-92wby1cSMnco6g',
  );
  await Push.init();
  ErrorWidget.builder = (d) => const Material(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Something went wrong. Please go back and try again.', textAlign: TextAlign.center))));
  const dsn = String.fromEnvironment('SENTRY_DSN');
  if (dsn.isEmpty) { runApp(const App()); return; }
  await sentry.SentryFlutter.init((o) {
    o.dsn = dsn;
    o.sendDefaultPii = false;
    o.tracesSampleRate = 0.2;
    o.environment = kReleaseMode ? 'production' : 'debug';
  }, appRunner: () => runApp(const App()));
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(title: 'LAND METRICS', debugShowCheckedModeBanner: false, theme: theme(Brightness.light), darkTheme: theme(Brightness.dark), home: const Gate());
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  @override
  void dispose() { ctl.dispose(); super.dispose(); }
  Widget _ring(double t) => Opacity(opacity: (1 - t).clamp(0.0, 1.0) * .5, child: Container(width: 150 + 130 * t, height: 150 + 130 * t, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: K.lime, width: 2))));
  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: K.deep,
        body: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(animation: ctl, builder: (_, __) => Stack(alignment: Alignment.center, children: [_ring(ctl.value), _ring((ctl.value + .5) % 1)])),
          TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 900), curve: Curves.easeOut, builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: .8 + .2 * v, child: child)), child: const Logo(s: 150)),
          Positioned(bottom: 70, child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 1400), curve: Curves.easeIn, builder: (_, v, child) => Opacity(opacity: v, child: child), child: const Text('LAND · VERIFIED · TRUSTED', style: TextStyle(color: K.lime, letterSpacing: 3, fontSize: 11, fontWeight: FontWeight.w700)))),
        ]),
      );
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  Json? me; Object? loadErr; bool ready = false; StreamSubscription<AuthState>? sub;
  @override
  void initState() {
    super.initState();
    Future.wait([_load(), Future.delayed(const Duration(milliseconds: 1600))]).then((_) { if (mounted) setState(() => ready = true); });
    sub = sb.auth.onAuthStateChange.listen((_) => _load());
  }
  @override
  void dispose() { sub?.cancel(); super.dispose(); }
  Future<void> _load() async {
    final u = sb.auth.currentUser;
    Json? p; Object? err;
    if (u != null) {
      try { p = await sb.from('profiles').select().eq('id', u.id).single(); } catch (e) { err = e; }
    }
    if (p != null && u != null) sentry.Sentry.configureScope((sc) => sc.setUser(sentry.SentryUser(id: u.id)));
    if (mounted) setState(() { me = p; loadErr = err; });
  }
  Widget _screen() {
    if (!ready) return const KeyedSubtree(key: ValueKey('splash'), child: Splash());
    if (sb.auth.currentUser == null) return const KeyedSubtree(key: ValueKey('auth'), child: AuthScreen());
    final m = me;
    if (m == null) {
      return KeyedSubtree(key: const ValueKey('err'), child: Scaffold(body: SafeArea(child: Column(children: [
        const OfflineBanner(),
        Expanded(child: NoNet(offline: loadErr == null || isOffline(loadErr!), onRetry: _load)),
        TextButton(onPressed: () => sb.auth.signOut(), child: const Text('Log out')),
        const SizedBox(height: 16),
      ]))));
    }
    return KeyedSubtree(key: ValueKey(m['role'] == 'admin' ? 'admin' : 'user'), child: m['role'] == 'admin' ? AdminShell(me: m) : UserShell(me: m));
  }
  @override
  Widget build(BuildContext c) => AnimatedSwitcher(duration: const Duration(milliseconds: 500), switchInCurve: Curves.easeOut, child: _screen());
}
