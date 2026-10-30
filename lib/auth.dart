import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool login = true, busy = false, hide = true;
  final name = TextEditingController(), phone = TextEditingController(), email = TextEditingController(), pw = TextEditingController();

  Future<void> _reset() async {
    final em = email.text.trim().toLowerCase();
    if (em.isEmpty) { toast(context, 'Enter your registered email first.'); return; }
    setState(() => busy = true);
    try {
      if (phone.text.trim().isEmpty) {
        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Phone number for support'),
          content: TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Registered phone number')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue'))],
        ));
        if (ok != true || phone.text.trim().isEmpty) { if (mounted) setState(() => busy = false); return; }
      }
      await sb.from('password_reset_requests').insert({
        'email': em,
        'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
      });
      await sb.auth.resetPasswordForEmail(em);
      if (mounted) toast(context, 'Reset instructions sent to your registered email. Our support team can contact you on your registered phone.');
    } on AuthException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (e) {
      if (mounted) toast(context, 'Could not submit reset request: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _go() async {
    final em = email.text.trim().toLowerCase();
    if (em.isEmpty || pw.text.length < 6) { toast(context, 'Enter your email and a password of at least 6 characters.'); return; }
    setState(() => busy = true);
    try {
      if (login) {
        await sb.auth.signInWithPassword(email: em, password: pw.text);
      } else {
        if (name.text.trim().isEmpty) throw 'Please enter your full name.';
        if (phone.text.trim().isEmpty) throw 'Please enter your phone number.';
        final r = await sb.auth.signUp(email: em, password: pw.text, data: {'full_name': name.text.trim(), 'phone': phone.text.trim()});
        if (r.session == null) throw 'Account created. Please confirm your email, then log in.';
      }
    } on AuthException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    final cs = Theme.of(c).colorScheme;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [K.deep, K.green])),
        child: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(children: [
          const Logo(s: 104), const SizedBox(height: 14),
          const Text('LAND METRICS', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2.5)),
          const SizedBox(height: 4),
          const Text('Buy and sell verified land and property.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 24),
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(26)), child: Column(children: [
            SegmentedButton<bool>(showSelectedIcon: false, segments: const [ButtonSegment(value: true, label: Text('Log in')), ButtonSegment(value: false, label: Text('Register'))], selected: {login}, onSelectionChanged: (s) => setState(() => login = s.first)),
            const SizedBox(height: 18),
            if (!login) ...[field(name, 'Full name', icon: Icons.person_outline), field(phone, 'Phone number', kb: TextInputType.phone, icon: Icons.phone_outlined)],
            field(email, 'Email', kb: TextInputType.emailAddress, icon: Icons.mail_outline),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: pw, obscureText: hide, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline, size: 20), suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => hide = !hide))))),
            if (login) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : _reset, child: const Text('Reset password'))),
            const SizedBox(height: 6),
            Btn(login ? 'Log in' : 'Create account', busy: busy, onTap: _go),
            if (login) Padding(padding: const EdgeInsets.only(top: 8), child: grey('Your secure login session stays signed in on this device until you log out.')),
          ])),
        ]))))),
      ),
    );
  }
}
