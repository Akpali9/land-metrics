import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core.dart';
import 'user.dart';
import 'dart:io';

class AdminShell extends StatelessWidget {
  final Json me;
  const AdminShell({super.key, required this.me});
  @override
  Widget build(BuildContext c) => Shell(admin: true, tabs: [
        ('Review', Icons.fact_check_rounded, () => const Review()),
        ('Broadcast', Icons.campaign_rounded, () => const Broadcast()),
        ('Chats', Icons.forum_rounded, () => AdminChats(me: me)),
      ]);
}

Future<void> run(BuildContext c, Future<dynamic> f, Future<void> Function() reload) async {
  try { await f; } on PostgrestException catch (e) { if (c.mounted) toast(c, e.message); }
  await reload();
}

Widget who(Json? p) => grey('${p?['full_name'] ?? 'User'} · ${p?['phone'] ?? ''}');

class Review extends StatelessWidget {
  const Review({super.key});
  @override
  Widget build(BuildContext c) => Q<Json>(
      load: () async {
        final r = await Future.wait<dynamic>([
          sb.from('payments').select('*, lands(title,price), profiles(full_name,phone)').eq('status', 'pending').order('created_at'),
          sb.from('lands').select('*, profiles(full_name,phone)').eq('status', 'pending').order('created_at'),
          sb.from('requests').select('*, profiles(full_name,phone)').neq('status', 'done').order('created_at'),
          sb.from('sales').select('buyer_fee,seller_fee'),
          sb.from('payments').select('amount').eq('type', 'subscription').eq('status', 'verified'),
        ]);
        return {'pay': r[0], 'lands': r[1], 'req': r[2], 'sales': r[3], 'subs': r[4]};
      },
      builder: (c, d, reload) {
        final fees = rows(d['sales']).fold<num>(0, (a, x) => a + numOf(x['buyer_fee']) + numOf(x['seller_fee']));
        final subs = rows(d['subs']).fold<num>(0, (a, x) => a + numOf(x['amount']));
        return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 24), children: [
          head(c, 'Admin review'),
          Surface(gradient: kGradient, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Platform revenue', style: TextStyle(color: Colors.white70)), Text(naira(fees + subs), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text('Fees ${naira(fees)} · Subscriptions ${naira(subs)}', style: const TextStyle(color: K.lime, fontSize: 12))])),
          sub('Payments to verify'),
          if (rows(d['pay']).isEmpty) empty(Icons.task_alt_rounded, 'Nothing waiting.'),
          for (final p in rows(d['pay']))
            Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text('${(p['lands'] as Json?)?['title'] ?? 'Land'}', style: const TextStyle(fontWeight: FontWeight.w800))), Pill('${p['type']}', warn: true)]),
              who(p['profiles'] as Json?),
              Text('Expect ${naira(numOf(p['amount']))}', style: const TextStyle(color: K.green, fontWeight: FontWeight.w900, fontSize: 18)),
              if (p['proof_url'] != null) GestureDetector(onTap: () => showDialog(context: c, builder: (_) => Dialog(child: InteractiveViewer(child: CachedNetworkImage(imageUrl: p['proof_url'] as String)))), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(height: 150, width: double.infinity, child: NetImg(p['proof_url'] as String))))) else grey('No receipt attached'),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Btn('Verify', onTap: () async { if (await confirm(c, 'Confirm that ${naira(numOf(p['amount']))} has arrived in your bank account.') && c.mounted) await run(c, sb.rpc('verify_payment', params: {'pid': p['id'], 'ok': true}), reload); })),
                const SizedBox(width: 8),
                Expanded(child: Btn('Reject', outline: true, onTap: () => run(c, sb.rpc('verify_payment', params: {'pid': p['id'], 'ok': false}), reload))),
              ]),
            ])),
          sub('Listings to confirm'),
          if (rows(d['lands']).isEmpty) empty(Icons.task_alt_rounded, 'Nothing waiting.'),
          for (final l in rows(d['lands']))
            Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${l['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              grey('${l['kind']} · ${l['location'] ?? ''} · ${naira(numOf(l['price']))}'), who(l['profiles'] as Json?),
              if (((l['images'] as List?) ?? []).isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: SizedBox(height: 84, child: ListView(scrollDirection: Axis.horizontal, children: [for (final u in l['images'] as List) Padding(padding: const EdgeInsets.only(right: 8), child: SizedBox(width: 110, child: ClipRRect(borderRadius: BorderRadius.circular(10), child: NetImg(u as String))))]))),
              Row(children: [
                Expanded(child: Btn('Confirm', onTap: () => run(c, sb.from('lands').update({'status': 'approved'}).eq('id', l['id']), reload))),
                const SizedBox(width: 8),
                Expanded(child: Btn('Reject', outline: true, onTap: () => run(c, sb.from('lands').update({'status': 'rejected'}).eq('id', l['id']), reload))),
              ]),
            ])),
          sub('Verification and construction requests'),
          if (rows(d['req']).isEmpty) empty(Icons.task_alt_rounded, 'No open requests.'),
          for (final x in rows(d['req']))
            Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text('${x['kind']}'.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800))), Pill('${x['status']}', warn: true)]),
              who(x['profiles'] as Json?), Text('${x['details']}${x['budget'] != null ? ' · ${naira(numOf(x['budget']))}' : ''}'),
              const SizedBox(height: 8), Btn('Mark done', onTap: () => run(c, sb.from('requests').update({'status': 'done'}).eq('id', x['id']), reload)),
            ])),
        ]);
      });
}

class Broadcast extends StatelessWidget {
  const Broadcast({super.key});
  @override
  Widget build(BuildContext c) => Q<Rows>(load: () => sb.from('ads').select().order('created_at', ascending: false), builder: (c, ads, reload) => ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 24), children: [
        head(c, 'Post an ad'),
        AdForm(onDone: reload),
        sub('Live ads (${ads.length})'),
        if (ads.isEmpty) empty(Icons.campaign_outlined, 'No ads yet.'),
        for (final a in ads) Surface(pad: const EdgeInsets.all(10), child: Row(children: [
          SizedBox(width: 72, height: 54, child: ClipRRect(borderRadius: BorderRadius.circular(10), child: NetImg(a['image_url'] as String?))),
          const SizedBox(width: 12),
          Expanded(child: Text('${a['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
          IconButton(tooltip: 'Delete ad', icon: const Icon(Icons.delete_outline_rounded), onPressed: () async { if (await confirm(c, 'Delete this ad for all users?') && c.mounted) await run(c, sb.from('ads').delete().eq('id', a['id']), reload); }),
        ])),
        head(c, 'Notify sellers'),
        const NotifyForm(),
      ]));
}

class AdForm extends StatefulWidget {
  final Future<void> Function() onDone;
  const AdForm({super.key, required this.onDone});
  @override
  State<AdForm> createState() => _AdFormState();
}

class _AdFormState extends State<AdForm> {
  final t = TextEditingController(), b = TextEditingController();
  XFile? img; bool busy = false;
  Future<void> _publish() async {
    if (t.text.trim().isEmpty) { toast(context, 'Add a headline.'); return; }
    setState(() => busy = true);
    try {
      final url = img == null ? null : await uploadImage(img!);
      await sb.from('ads').insert({'title': t.text.trim(), 'body': b.text.trim(), 'image_url': url});
      t.clear(); b.clear();
      if (mounted) { setState(() => img = null); toast(context, 'Ad is live for all users.'); }
      await widget.onDone();
    } catch (e) { if (mounted) toast(context, 'Could not publish: ${e is PostgrestException ? e.message : e}'); }
    if (mounted) setState(() => busy = false);
  }
  @override
  Widget build(BuildContext c) => Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(onTap: () async { final f = await pickImages(multi: false); if (f.isNotEmpty) setState(() => img = f.first); }, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(height: 150, width: double.infinity, child: img == null ? Container(color: const Color(0x140F7A47), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_outlined, size: 34, color: K.green), SizedBox(height: 6), Text('Add banner image', style: TextStyle(color: K.green, fontWeight: FontWeight.w700))])) : Image.file(File(img!.path), fit: BoxFit.cover)))),
        const SizedBox(height: 12),
        field(t, 'Headline', icon: Icons.title_rounded), field(b, 'Short text (optional)', lines: 2),
        Btn('Publish to all users', icon: Icons.campaign_rounded, busy: busy, onTap: _publish),
      ]));
}

class NotifyForm extends StatefulWidget {
  const NotifyForm({super.key});
  @override
  State<NotifyForm> createState() => _NotifyFormState();
}

class _NotifyFormState extends State<NotifyForm> {
  final n = TextEditingController(); bool busy = false;
  @override
  Widget build(BuildContext c) => Surface(child: Column(children: [
        field(n, 'Message to all land and property sellers', lines: 4),
        Btn('Send notification', icon: Icons.notifications_active_rounded, busy: busy, onTap: () async {
          if (n.text.trim().isEmpty) return;
          setState(() => busy = true);
          try { await sb.from('notifications').insert({'body': n.text.trim()}); n.clear(); if (mounted) toast(context, 'Sent to sellers.'); } catch (e) { if (mounted) toast(context, '$e'); }
          if (mounted) setState(() => busy = false);
        }),
      ]));
}

class AdminChats extends StatelessWidget {
  final Json me;
  const AdminChats({super.key, required this.me});
  @override
  Widget build(BuildContext c) => Q<Json>(
      load: () async {
        final r = await Future.wait<dynamic>([sb.from('messages').select('thread_user,body,created_at').order('created_at', ascending: false), sb.from('profiles').select('id,full_name')]);
        return {'m': r[0], 'p': r[1]};
      },
      builder: (c, d, reload) {
        final seen = <String>{}; final threads = <Json>[];
        for (final m in rows(d['m'])) { if (m['thread_user'] != me['id'] && seen.add('${m['thread_user']}')) threads.add(m); }
        final names = {for (final p in rows(d['p'])) '${p['id']}': '${p['full_name'] ?? 'User'}'};
        return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          head(c, 'User chats'),
          if (threads.isEmpty) empty(Icons.forum_outlined, 'No conversations yet.'),
          for (final m in threads) Surface(onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(names['${m['thread_user']}'] ?? 'User')), body: SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ChatView(me: me, uid: '${m['thread_user']}')))))).then((_) => reload()), child: Row(children: [const CircleAvatar(backgroundColor: K.green, child: Icon(Icons.person, color: Colors.white)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(names['${m['thread_user']}'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.w800)), Text('${m['body']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey))])), const Icon(Icons.chevron_right_rounded)])),
        ]);
      });
}
