import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin.dart';
import 'auth.dart';
import 'core.dart';
import 'user.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://znughsflubewjpojsvip.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpudWdoc2ZsdWJld2pwb2pzdmlwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMyNzUxMjQsImV4cCI6MjEwODg1MTEyNH0.ekm81T4H1WxmnA8ZGGBR4Cm5nMfY-92wby1cSMnco6g',
  );
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(title: 'LAND METRICS', debugShowCheckedModeBanner: false, theme: theme(Brightness.light), darkTheme: theme(Brightness.dark), home: const Gate());
}

class Splash extends StatelessWidget {
  const Splash({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: K.deep,
        body: Center(child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 900), curve: Curves.easeOut, builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: .85 + .15 * v, child: child)), child: const Logo(s: 150))),
      );
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  Json? me; bool ready = false; StreamSubscription<AuthState>? sub;
  @override
  void initState() {
    super.initState();
    Future.wait([_load(), Future.delayed(const Duration(milliseconds: 1300))]).then((_) { if (mounted) setState(() => ready = true); });
    sub = sb.auth.onAuthStateChange.listen((_) => _load());
  }
  @override
  void dispose() { sub?.cancel(); super.dispose(); }
  Future<void> _load() async {
    final u = sb.auth.currentUser;
    Json? p;
    if (u != null) {
      try { p = await sb.from('profiles').select().eq('id', u.id).single(); } catch (_) { p = null; }
    }
    if (mounted) setState(() => me = p);
  }
  @override
  Widget build(BuildContext c) {
    if (!ready) return const Splash();
    if (sb.auth.currentUser == null) return const AuthScreen();
    final m = me;
    if (m == null) {
      return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [const Logo(s: 80), const SizedBox(height: 16), const Text('We could not load your profile. Make sure the database setup (schema.sql) has been run.', textAlign: TextAlign.center), const SizedBox(height: 16), Btn('Try again', onTap: _load), Btn('Log out', outline: true, onTap: () => sb.auth.signOut())]))));
    }
    return m['role'] == 'admin' ? AdminShell(me: m) : UserShell(me: m);
  }
}
