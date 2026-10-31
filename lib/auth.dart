import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) { final e = p.getString('last_email'); if (e != null && mounted) setState(() => email.text = e); });
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
        final r = await sb.auth.signUp(email: em, password: pw.text, data: {'full_name': name.text.trim(), 'phone': phone.text.trim()});
        if (r.session == null) throw 'Account created. Please confirm your email, then log in.';
      }
      final p = await SharedPreferences.getInstance();
      await p.setString('last_email', em);
      TextInput.finishAutofillContext();
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
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(26)), child: AutofillGroup(child: Column(children: [
            SegmentedButton<bool>(showSelectedIcon: false, segments: const [ButtonSegment(value: true, label: Text('Log in')), ButtonSegment(value: false, label: Text('Register'))], selected: {login}, onSelectionChanged: (s) => setState(() => login = s.first)),
            const SizedBox(height: 18),
            if (!login) ...[field(name, 'Full name', icon: Icons.person_outline, hints: const [AutofillHints.name]), field(phone, 'Phone number', kb: TextInputType.phone, icon: Icons.phone_outlined, hints: const [AutofillHints.telephoneNumber])],
            field(email, 'Email', kb: TextInputType.emailAddress, icon: Icons.mail_outline, hints: const [AutofillHints.email]),
            Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: pw, obscureText: hide, autofillHints: [login ? AutofillHints.password : AutofillHints.newPassword], onSubmitted: (_) => _go(), decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline, size: 20), suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => hide = !hide))))),
            if (login) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ResetScreen(email: email.text))), child: const Text('Forgot password?'))),
            const SizedBox(height: 6),
            Btn(login ? 'Log in' : 'Create account', busy: busy, onTap: _go),
          ]))),
        ]))))),
      ),
    );
  }
}

class ResetScreen extends StatefulWidget {
  final String email;
  const ResetScreen({super.key, required this.email});
  @override
  State<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends State<ResetScreen> {
  late final em = TextEditingController(text: widget.email);
  final code = TextEditingController(), pw = TextEditingController();
  bool sent = false, busy = false;
  Future<void> _send() async {
    final e = em.text.trim().toLowerCase();
    if (e.isEmpty) { toast(context, 'Enter your email address.'); return; }
    setState(() => busy = true);
    try {
      await sb.auth.resetPasswordForEmail(e);
      if (mounted) { setState(() => sent = true); toast(context, 'We emailed you a code.'); }
    } on AuthException catch (x) { if (mounted) toast(context, x.message); }
    if (mounted) setState(() => busy = false);
  }
  Future<void> _confirm() async {
    if (code.text.trim().isEmpty || pw.text.length < 6) { toast(context, 'Enter the code and a new password of 6+ characters.'); return; }
    setState(() => busy = true);
    try {
      await sb.auth.verifyOTP(email: em.text.trim().toLowerCase(), token: code.text.trim(), type: OtpType.recovery);
      await sb.auth.updateUser(UserAttributes(password: pw.text));
      if (mounted) { toast(context, 'Password updated. You are logged in.'); Navigator.of(context).popUntil((r) => r.isFirst); }
      return;
    } on AuthException catch (x) { if (mounted) toast(context, x.message); }
    if (mounted) setState(() => busy = false);
  }
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Reset password')),
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: ListView(padding: const EdgeInsets.all(24), children: [
          const Center(child: Logo(s: 72)), const SizedBox(height: 16),
          Text(sent ? 'Enter the code from your email and choose a new password.' : 'Enter your account email and we will send you a code.', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          field(em, 'Email', kb: TextInputType.emailAddress, icon: Icons.mail_outline),
          if (!sent) Btn('Send code', busy: busy, onTap: _send) else ...[
            field(code, 'Code from email', kb: TextInputType.number, icon: Icons.pin_outlined),
            field(pw, 'New password', obscure: true, icon: Icons.lock_outline),
            Btn('Update password', busy: busy, onTap: _confirm),
            TextButton(onPressed: busy ? null : _send, child: const Text('Resend code')),
          ],
        ]))),
      );
}
