import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core.dart';

DateTime _t(dynamic v) => DateTime.tryParse('$v')?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

class Avatar extends StatelessWidget {
  final String? url; final String name; final double r;
  const Avatar({super.key, this.url, this.name = '', this.r = 18});
  @override
  Widget build(BuildContext c) => CircleAvatar(radius: r, backgroundColor: K.green, backgroundImage: url == null ? null : CachedNetworkImageProvider(url!), child: url == null ? Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: r * .9)) : null);
}

class NotifBell extends StatefulWidget {
  final Json me;
  const NotifBell({super.key, required this.me});
  @override
  State<NotifBell> createState() => _NotifBellState();
}

class _NotifBellState extends State<NotifBell> {
  late DateTime seen = _t(widget.me['notif_seen_at']);
  final start = DateTime.now().toUtc();
  Rows items = []; Object? lastId; StreamSubscription<Rows>? sub;
  @override
  void initState() {
    super.initState();
    sub = sb.from('notifications').stream(primaryKey: ['id']).order('created_at', ascending: false).listen((r) {
      if (!mounted) return;
      setState(() => items = r);
      if (r.isEmpty) return;
      final n = r.first, at = _t(n['created_at']);
      if (at.isAfter(start) && at.isAfter(seen) && n['id'] != lastId) {
        lastId = n['id'];
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 6), content: Text('${n['title'] ?? 'LAND METRICS'}: ${n['body']}', maxLines: 3, overflow: TextOverflow.ellipsis), action: SnackBarAction(label: 'View', onPressed: _open)));
      }
    }, onError: (_) {});
  }
  @override
  void dispose() { sub?.cancel(); super.dispose(); }
  Future<void> _open() async {
    final before = seen;
    final now = DateTime.now().toUtc();
    setState(() => seen = now);
    try { await sb.from('profiles').update({'notif_seen_at': now.toIso8601String()}).eq('id', widget.me['id']); } catch (_) {}
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NotifScreen(items: items, seen: before)));
  }
  @override
  Widget build(BuildContext c) {
    final unread = items.where((n) => _t(n['created_at']).isAfter(seen)).length;
    return IconButton(tooltip: 'Notifications', onPressed: _open, icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_rounded)));
  }
}

class NotifScreen extends StatelessWidget {
  final Rows items; final DateTime seen;
  const NotifScreen({super.key, required this.items, required this.seen});
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: items.isEmpty
            ? empty(Icons.notifications_none_rounded, 'No notifications yet.')
            : ListView(padding: const EdgeInsets.all(16), children: [
                for (final n in items)
                  Surface(color: _t(n['created_at']).isAfter(seen) ? const Color(0x2A7ED957) : null, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const CircleAvatar(radius: 18, backgroundColor: K.green, child: Icon(Icons.notifications_active_rounded, size: 18, color: Colors.white)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${n['title'] ?? 'LAND METRICS'}', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text('${n['body']}'), const SizedBox(height: 4), grey(DateFormat('d MMM, h:mm a').format(_t(n['created_at']).toLocal()))])),
                  ])),
              ]))),
      );
}

class ProfileScreen extends StatefulWidget {
  final Json me;
  const ProfileScreen({super.key, required this.me});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final name = TextEditingController(text: '${widget.me['full_name'] ?? ''}');
  late final phone = TextEditingController(text: '${widget.me['phone'] ?? ''}');
  late String? avatar = widget.me['avatar_url'] as String?;
  bool busy = false;
  Future<void> _pic() async {
    final f = await pickImages(multi: false);
    if (f.isEmpty) return;
    setState(() => busy = true);
    try {
      final url = await uploadImage(f.first);
      await sb.from('profiles').update({'avatar_url': url}).eq('id', widget.me['id']);
      await sb.auth.updateUser(UserAttributes(data: {'avatar_url': url}));
      if (mounted) { setState(() => avatar = url); toast(context, 'Profile picture updated.'); }
    } catch (e) { if (mounted) toast(context, 'Could not update picture: ${e is PostgrestException ? e.message : e}'); }
    if (mounted) setState(() => busy = false);
  }
  Future<void> _save() async {
    setState(() => busy = true);
    try {
      await sb.from('profiles').update({'full_name': name.text.trim(), 'phone': phone.text.trim()}).eq('id', widget.me['id']);
      await sb.auth.updateUser(UserAttributes(data: {'full_name': name.text.trim()}));
      if (mounted) toast(context, 'Profile saved.');
    } catch (e) { if (mounted) toast(context, 'Could not save: $e'); }
    if (mounted) setState(() => busy = false);
  }
  Future<void> _pw() async {
    final p = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Change password'), content: TextField(controller: p, obscureText: true, decoration: const InputDecoration(labelText: 'New password (6+ characters)')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(90, 44)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))]));
    if (ok != true || !mounted) return;
    if (p.text.length < 6) { toast(context, 'Password must be at least 6 characters.'); return; }
    try { await sb.auth.updateUser(UserAttributes(password: p.text)); if (mounted) toast(context, 'Password updated.'); } on AuthException catch (e) { if (mounted) toast(context, e.message); }
  }
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('My profile')),
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: ListView(padding: const EdgeInsets.all(20), children: [
          Center(child: Stack(children: [
            Avatar(url: avatar, name: name.text, r: 56),
            Positioned(right: 0, bottom: 0, child: InkWell(onTap: busy ? null : _pic, borderRadius: BorderRadius.circular(99), child: CircleAvatar(radius: 18, backgroundColor: K.lime, child: busy ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.photo_camera_rounded, size: 18, color: K.deep)))),
          ])),
          const SizedBox(height: 12),
          Center(child: grey(sb.auth.currentUser?.email ?? '')),
          const SizedBox(height: 6),
          Center(child: Pill('${widget.me['role']}'.toUpperCase())),
          const SizedBox(height: 22),
          field(name, 'Full name', icon: Icons.person_outline), field(phone, 'Phone number', kb: TextInputType.phone, icon: Icons.phone_outlined),
          Btn('Save changes', busy: busy, onTap: _save),
          Btn('Change password', outline: true, icon: Icons.lock_reset_rounded, onTap: _pw),
          Btn('Log out', outline: true, icon: Icons.logout_rounded, onTap: () { Navigator.of(context).popUntil((r) => r.isFirst); sb.auth.signOut(); }),
        ]))),
      );
}
