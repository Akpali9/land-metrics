import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core.dart';

class UserShell extends StatelessWidget {
  final Json me;
  const UserShell({super.key, required this.me});
  @override
  Widget build(BuildContext c) => Shell(tabs: [
        ('Explore', Icons.explore_rounded, () => Explore(me: me)),
        ('Sell', Icons.add_business_rounded, () => Sell(me: me)),
        ('Services', Icons.verified_rounded, () => Services(me: me)),
        ('Dashboard', Icons.insights_rounded, () => Dash(me: me)),
        ('Chat', Icons.chat_bubble_rounded, () => Column(children: [head(c, 'Chat with support'), Expanded(child: ChatView(me: me, uid: me['id']))])),
        ('Profile', Icons.account_circle_rounded, () => ProfilePage(me: me)),
      ]);
}

// ---------- Explore ----------
class Explore extends StatefulWidget {
  final Json me;
  const Explore({super.key, required this.me});
  @override
  State<Explore> createState() => _ExploreState();
}

class _ExploreState extends State<Explore> {
  String kind = 'all', q = '';
  Future<Json> _load() async {
    final r = await Future.wait<dynamic>([
      sb.from('lands').select().eq('status', 'live').order('created_at', ascending: false),
      sb.from('ads').select().order('created_at', ascending: false).limit(6),
      sb.from('notifications').select().order('created_at', ascending: false).limit(3),
      sb.from('lands').select('id').eq('seller_id', widget.me['id']),
    ]);
    return {'lands': r[0], 'ads': r[1], 'notes': r[2], 'mine': r[3]};
  }

  @override
  Widget build(BuildContext c) => Q<Json>(load: _load, builder: (c, d, reload) {
        final ql = q.toLowerCase();
        final lands = rows(d['lands']).where((l) => (kind == 'all' || l['kind'] == kind) && (ql.isEmpty || '${l['title']} ${l['location']}'.toLowerCase().contains(ql))).toList();
        final ads = rows(d['ads']);
        final seller = rows(d['mine']).isNotEmpty;
        return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 24), children: [
          if (ads.isNotEmpty) AdCarousel(ads: ads),
          StreamBuilder<Rows>(stream: sb.from('notifications').stream(primaryKey: ['id']).order('created_at', ascending: false), builder: (c, snap) { final notes = snap.data ?? rows(d['notes']); return Column(children: [for (final n in notes.take(5)) Surface(color: const Color(0x1AD9A520), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.notifications_active_rounded, color: K.gold), const SizedBox(width: 10), Expanded(child: Text('${n['body']}'))]))]); }),
          TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: 'Search by title or location', prefixIcon: Icon(Icons.search_rounded))),
          const SizedBox(height: 10),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final k in ['all', 'land', 'property']) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(k == 'all' ? 'All' : '${k[0].toUpperCase()}${k.substring(1)}s'), selected: kind == k, onSelected: (_) => setState(() => kind = k)))])),
          const SizedBox(height: 12),
          if (lands.isEmpty) empty(Icons.landscape_outlined, 'No listings found yet.\nPull down to refresh.'),
          for (final l in lands) LandCard(land: l, me: widget.me, onBack: reload),
        ]);
      });
}

class AdCarousel extends StatefulWidget {
  final Rows ads;
  const AdCarousel({super.key, required this.ads});
  @override
  State<AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<AdCarousel> {
  final pc = PageController(); int i = 0; Timer? t;
  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 5), (_) { if (pc.hasClients && widget.ads.length > 1) pc.animateToPage((i + 1) % widget.ads.length, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut); });
  }
  @override
  void dispose() { t?.cancel(); pc.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(children: [
        SizedBox(height: 176, child: PageView.builder(controller: pc, itemCount: widget.ads.length, onPageChanged: (v) => setState(() => i = v), itemBuilder: (_, k) {
          final a = widget.ads[k];
          return Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: ClipRRect(borderRadius: BorderRadius.circular(22), child: Stack(fit: StackFit.expand, children: [
            NetImg(a['image_url'] as String?),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xCC000000)]))),
            Positioned(left: 16, right: 16, bottom: 14, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: K.lime, borderRadius: BorderRadius.circular(99)), child: const Text('SPONSORED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: K.deep, letterSpacing: .8))),
              const SizedBox(height: 6),
              Text('${a['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
              if ((a['body'] ?? '').toString().isNotEmpty) Text('${a['body']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
            ])),
          ])));
        })),
        if (widget.ads.length > 1) Padding(padding: const EdgeInsets.only(top: 8), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var k = 0; k < widget.ads.length; k++) AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 2), width: k == i ? 18 : 6, height: 6, decoration: BoxDecoration(color: k == i ? K.green : Colors.grey.shade400, borderRadius: BorderRadius.circular(9)))])),
      ]));
}

class LandCard extends StatelessWidget {
  final Json land, me; final Future<void> Function() onBack;
  const LandCard({super.key, required this.land, required this.me, required this.onBack});
  @override
  Widget build(BuildContext c) {
    final imgs = (land['images'] as List?) ?? [];
    return Surface(pad: EdgeInsets.zero, onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => LandDetail(land: land, me: me))).then((_) => onBack()), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(height: 190, width: double.infinity, child: Stack(fit: StackFit.expand, children: [
        NetImg(imgs.isEmpty ? null : imgs.first as String),
        const Positioned(top: 12, left: 12, child: Pill('✓ Verified')),
        Positioned(top: 12, right: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)), child: Text('${land['kind']}'.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)))),
      ])),
      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${land['title']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 4),
        Row(children: [const Icon(Icons.place_outlined, size: 15, color: Colors.grey), const SizedBox(width: 4), Expanded(child: grey('${land['location'] ?? ''} · ${land['size_sqm'] ?? '—'} sqm'))]),
        const SizedBox(height: 8),
        Text(naira(numOf(land['price'])), style: const TextStyle(color: K.green, fontWeight: FontWeight.w900, fontSize: 21)),
      ])),
    ]));
  }
}

class LandDetail extends StatelessWidget {
  final Json land, me;
  const LandDetail({super.key, required this.land, required this.me});
  @override
  Widget build(BuildContext c) {
    final p = numOf(land['price']);
    final own = land['seller_id'] == me['id'];
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: ListView(padding: const EdgeInsets.all(16), children: [
        Gallery(imgs: (land['images'] as List?) ?? [], h: 260),
        const SizedBox(height: 16),
        Row(children: [Pill('${land['kind']}'.toUpperCase()), const SizedBox(width: 8), const Pill('✓ Verified')]),
        const SizedBox(height: 10),
        Text('${land['title']}', style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        grey('${land['location'] ?? ''} · ${land['size_sqm'] ?? '—'} sqm'),
        const SizedBox(height: 10),
        Text(naira(p), style: const TextStyle(color: K.green, fontWeight: FontWeight.w900, fontSize: 28)),
        const SizedBox(height: 14),
        if ('${land['description'] ?? ''}'.isNotEmpty) Surface(child: Text('${land['description']}')),
        Surface(child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Land price'), Text(naira(p), style: const TextStyle(fontWeight: FontWeight.w700))]),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('LAND METRICS fee (10%)'), Text(naira(p * .1), style: const TextStyle(fontWeight: FontWeight.w700))]),
          const Divider(height: 22),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('You pay', style: TextStyle(fontWeight: FontWeight.w800)), Text(naira(p * 1.1), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: K.green))]),
        ])),
        grey('Pay by bank transfer. Our admins verify your payment before the sale is completed.'),
      ]))),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: own
          ? const Center(heightFactor: 2, child: Text('This is your listing'))
          : Btn('Buy now · ${naira(p * 1.1)}', icon: Icons.lock_outline_rounded, onTap: () => showModalBottomSheet<bool>(context: c, isScrollControlled: true, useSafeArea: true, builder: (_) => PaySheet(land: land, type: 'purchase')).then((ok) { if (ok == true && c.mounted) Navigator.pop(c); })))),
    );
  }
}

class PaySheet extends StatefulWidget {
  final Json land; final String type;
  const PaySheet({super.key, required this.land, required this.type});
  @override
  State<PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<PaySheet> {
  Json s = {}; XFile? proof; bool busy = false;
  @override
  void initState() {
    super.initState();
    sb.from('settings').select().then((r) { if (mounted) setState(() => s = {for (final x in r) x['key'] as String: x['value']}); });
  }
  Future<void> _send() async {
    setState(() => busy = true);
    try {
      final url = proof == null ? null : await uploadImage(proof!);
      await sb.from('payments').insert({'land_id': widget.land['id'], 'type': widget.type, 'proof_url': url, 'bank_name_snapshot': s['bank_name'], 'account_name_snapshot': s['account_name'], 'account_number_snapshot': s['account_number']});
      if (!mounted) return;
      toast(context, 'Payment submitted. An admin will verify it shortly.');
      Navigator.pop(context, true);
      return;
    } catch (e) {
      if (mounted) toast(context, 'Could not submit: ${e is PostgrestException ? e.message : e}');
    }
    if (mounted) setState(() => busy = false);
  }
  @override
  Widget build(BuildContext c) {
    final sub = widget.type == 'subscription';
    final p = numOf(widget.land['price']);
    final amt = sub ? numOf(s['subscription_fee']) : p * 1.1;
    return SingleChildScrollView(padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(sub ? 'Pay listing subscription' : 'Complete your purchase', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      if (!sub) ...[Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Land price'), Text(naira(p))]), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Fee (10%)'), Text(naira(p * .1))]), const SizedBox(height: 6)],
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Amount to transfer', style: TextStyle(fontWeight: FontWeight.w800)), Text(naira(amt), style: const TextStyle(color: K.green, fontWeight: FontWeight.w900, fontSize: 20))]),
      const SizedBox(height: 12),
      Surface(gradient: kGradient, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Transfer to', style: TextStyle(color: Colors.white70)),
        Text('${s['bank_name'] ?? ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        Row(children: [Expanded(child: Text('${s['account_number'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.5))), IconButton(tooltip: 'Copy', icon: const Icon(Icons.copy_rounded, color: Colors.white), onPressed: () { Clipboard.setData(ClipboardData(text: '${s['account_number'] ?? ''}')); toast(c, 'Account number copied'); })]),
        Text('${s['account_name'] ?? ''}', style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 6),
        Text('Narration: LAND-${widget.land['id']}', style: const TextStyle(color: K.lime, fontWeight: FontWeight.w700)),
      ])),
      Btn(proof == null ? 'Attach payment receipt' : 'Receipt attached ✓ (change)', outline: true, icon: Icons.receipt_long_rounded, onTap: () async { final f = await pickImages(multi: false); if (f.isNotEmpty) setState(() => proof = f.first); }),
      Btn('I have paid', busy: busy, onTap: _send),
    ]));
  }
}

// ---------- Sell ----------
class Sell extends StatelessWidget {
  final Json me;
  const Sell({super.key, required this.me});
  @override
  Widget build(BuildContext c) => Q<Json>(
      load: () async {
        final r = await Future.wait<dynamic>([
          sb.from('lands').select().eq('seller_id', me['id']).order('created_at', ascending: false),
          sb.from('payments').select('land_id,type,status').eq('user_id', me['id']),
        ]);
        return {'lands': r[0], 'pays': r[1]};
      },
      builder: (c, d, reload) {
        final pays = rows(d['pays']);
        const st = {'pending': 'In review', 'approved': 'Approved', 'live': 'Live', 'sold': 'Sold', 'rejected': 'Rejected'};
        return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 24), children: [
          head(c, 'Sell land or property'),
          Surface(gradient: kGradient, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('List a property with confidence', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 5), const Text('Choose the listing type below. Add clear photos, ownership details and an asking price.', style: TextStyle(color: Colors.white70))])),
          NewListing(onDone: reload),
          sub('My listings'),
          if (rows(d['lands']).isEmpty) empty(Icons.sell_outlined, 'No listings yet.'),
          for (final l in rows(d['lands']))
            Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SizedBox(width: 56, height: 56, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: NetImg(((l['images'] as List?) ?? []).isEmpty ? null : (l['images'] as List).first as String))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${l['title']}', style: const TextStyle(fontWeight: FontWeight.w800)), grey('${naira(numOf(l['price']))} · you receive ${naira(numOf(l['price']) * .9)}')])),
                Pill(st[l['status']] ?? '${l['status']}', warn: l['status'] != 'live' && l['status'] != 'sold'),
              ]),
              if (((l['documents'] as List?) ?? []).isNotEmpty) ...[for (final doc in l['documents'] as List) TextButton.icon(onPressed: () => openPrivateFile(doc.toString(), c), icon: const Icon(Icons.download), label: Text('Download ${doc.toString().split('/').last}', maxLines: 1, overflow: TextOverflow.ellipsis))],
              if (l['status'] == 'approved') ...[
                const SizedBox(height: 12),
                pays.any((p) => p['land_id'] == l['id'] && p['type'] == 'subscription' && p['status'] == 'pending')
                    ? grey('Subscription payment is under review…')
                    : Btn('Pay subscription to go live', icon: Icons.bolt_rounded, onTap: () => showModalBottomSheet<bool>(context: c, isScrollControlled: true, useSafeArea: true, builder: (_) => PaySheet(land: l, type: 'subscription')).then((_) => reload())),
              ],
            ])),
        ]);
      });
}

class NewListing extends StatefulWidget {
  final Future<void> Function() onDone;
  const NewListing({super.key, required this.onDone});
  @override
  State<NewListing> createState() => _NewListingState();
}

class _NewListingState extends State<NewListing> {
  String kind = 'land';
  final t = TextEditingController(), loc = TextEditingController(), size = TextEditingController(), price = TextEditingController(), desc = TextEditingController();
  List<XFile> imgs = []; final List<String> docs = []; bool busy = false;
  Future<void> _addLandDocs() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true, type: FileType.custom, allowedExtensions: ['pdf','doc','docx','jpg','jpeg','png']);
    if (result == null) return;
    try {
      for (final f in result.files) {
        if (f.bytes == null) continue;
        final path = '${sb.auth.currentUser!.id}/land-title/${DateTime.now().microsecondsSinceEpoch}_${f.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
        await sb.storage.from('land-documents').uploadBinary(path, f.bytes!);
        docs.add(path);
      }
      if (mounted) setState(() {});
    } catch (e) { if (mounted) toast(context, 'Could not upload land document: $e'); }
  }
  Future<void> _submit() async {
    final p = double.tryParse(price.text.replaceAll(',', ''));
    if (t.text.trim().isEmpty || p == null || p <= 0) { toast(context, 'Add a title and a valid price.'); return; }
    setState(() => busy = true);
    try {
      final urls = <String>[];
      for (final x in imgs) { urls.add(await uploadImage(x)); }
      await sb.from('lands').insert({'kind': kind, 'title': t.text.trim(), 'location': loc.text.trim(), 'size_sqm': double.tryParse(size.text), 'price': p, 'description': desc.text.trim(), 'images': urls, 'documents': docs});
      for (final x in [t, loc, size, price, desc]) { x.clear(); }
      if (mounted) { setState(() { imgs = []; docs.clear(); }); toast(context, 'Submitted. We will confirm your listing shortly.'); }
      await widget.onDone();
    } catch (e) {
      if (mounted) toast(context, 'Could not submit: ${e is PostgrestException ? e.message : e}');
    }
    if (mounted) setState(() => busy = false);
  }
  @override
  Widget build(BuildContext c) => Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: InkWell(onTap: () => setState(() => kind = 'land'), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: kind == 'land' ? const Color(0x1A0F7A47) : Colors.transparent, border: Border.all(color: kind == 'land' ? K.green : Colors.grey.shade400, width: kind == 'land' ? 2 : 1), borderRadius: BorderRadius.circular(16)), child: Column(children: [Icon(Icons.landscape_rounded, size: 30, color: kind == 'land' ? K.green : Colors.grey), const SizedBox(height: 5), const Text('Sell land', style: TextStyle(fontWeight: FontWeight.w800)), grey('Plot, estate or farmland')])))),
          const SizedBox(width: 10),
          Expanded(child: InkWell(onTap: () => setState(() => kind = 'property'), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: kind == 'property' ? const Color(0x1AD9A520) : Colors.transparent, border: Border.all(color: kind == 'property' ? K.gold : Colors.grey.shade400, width: kind == 'property' ? 2 : 1), borderRadius: BorderRadius.circular(16)), child: Column(children: [Icon(Icons.apartment_rounded, size: 30, color: kind == 'property' ? K.gold : Colors.grey), const SizedBox(height: 5), const Text('Sell property', style: TextStyle(fontWeight: FontWeight.w800)), grey('House, flat or building')])))),
        ]),
        const SizedBox(height: 14),
        field(t, 'Title', icon: Icons.title_rounded), field(loc, 'Location', icon: Icons.place_outlined),
        Row(children: [Expanded(child: field(size, kind == 'land' ? 'Land size (sqm)' : 'Building size (sqm)', kb: TextInputType.number)), const SizedBox(width: 10), Expanded(child: field(price, 'Price (₦)', kb: TextInputType.number))]),
        field(desc, 'Description', lines: 3),
        if (imgs.isNotEmpty) SizedBox(height: 82, child: ListView(scrollDirection: Axis.horizontal, children: [for (final x in imgs) Padding(padding: const EdgeInsets.only(right: 8, bottom: 4), child: Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(x.path), width: 76, height: 76, fit: BoxFit.cover)), Positioned(top: 2, right: 2, child: GestureDetector(onTap: () => setState(() => imgs.remove(x)), child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 12, color: Colors.white))))]))])),
        Btn('Add pictures (${imgs.length}/8)', outline: true, icon: Icons.add_photo_alternate_outlined, onTap: () async { final f = await pickImages(); setState(() => imgs = [...imgs, ...f].take(8).toList()); }),
         Btn('Upload ownership / survey documents (${docs.length})', outline: true, icon: Icons.folder_open, onTap: _addLandDocs),
         if (docs.isNotEmpty) ...[for (final doc in docs) ListTile(dense: true, leading: const Icon(Icons.verified_user_outlined), title: Text(doc.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => docs.remove(doc))))],
        Btn('Submit for confirmation', busy: busy, onTap: _submit),
        grey('You pay 10% only when it sells. After approval, a listing subscription activates it.'),
      ]));
}

// ---------- Services ----------
class Services extends StatefulWidget {
  final Json me;
  const Services({super.key, required this.me});
  @override
  State<Services> createState() => _ServicesState();
}

class _ServicesState extends State<Services> {
  final v = TextEditingController(), cd = TextEditingController(), cb = TextEditingController();
  String type = 'Residential building';
  final List<String> attachments = [];
  Future<void> _addDocuments() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true, type: FileType.custom, allowedExtensions: ['pdf','doc','docx','jpg','jpeg','png']);
    if (result == null) return;
    try {
      for (final f in result.files) {
        if (f.bytes == null) continue;
        final ext = (f.extension ?? 'bin').toLowerCase();
        final path = '${sb.auth.currentUser!.id}/construction/${DateTime.now().microsecondsSinceEpoch}_${f.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
        await sb.storage.from('land-documents').uploadBinary(path, f.bytes!, fileOptions: FileOptions(contentType: ext == 'pdf' ? 'application/pdf' : 'application/octet-stream'));
        attachments.add(path);
      }
      if (mounted) setState(() {});
    } catch (e) { if (mounted) toast(context, 'Document upload failed: $e'); }
  }
  Future<void> _send(String kind, String details, num? budget, Future<void> Function() reload) async {
    if (details.trim().isEmpty) { toast(context, 'Please add the details.'); return; }
    try {
      await sb.from('requests').insert({'kind': kind, 'details': details.trim(), 'budget': budget, 'attachments': kind == 'construction' ? attachments : <String>[]});
      v.clear(); cd.clear(); cb.clear(); attachments.clear();
      if (mounted) toast(context, 'Request sent. We will contact you.');
      await reload();
    } catch (e) { if (mounted) toast(context, '$e'); }
  }
  @override
  Widget build(BuildContext c) => Q<Rows>(load: () => sb.from('requests').select().eq('user_id', widget.me['id']).order('created_at', ascending: false), builder: (c, rq, reload) => ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 24), children: [
        head(c, 'Services'),
        Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.verified_rounded, color: K.green), SizedBox(width: 8), Text('Verify land', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]),
          const SizedBox(height: 4), grey('Surveyors check title, boundaries and ownership.'), const SizedBox(height: 12),
          field(v, 'Plot / survey number and location', lines: 2),
          Btn('Request verification', onTap: () => _send('verification', v.text, null, reload)),
        ])),
        Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.construction_rounded, color: K.gold), SizedBox(width: 8), Text('Apply for construction', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]),
          const SizedBox(height: 8),
          grey('Useful documents (as applicable): C of O, Deed of Assignment, Survey Plan, Governor’s Consent, Gazette / Excision evidence, allocation letter, building approval and land search report.'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: type, items: [for (final x in ['Residential building', 'Duplex', 'Commercial', 'Fencing and foundation']) DropdownMenuItem(value: x, child: Text(x))], onChanged: (x) => setState(() => type = x ?? type)),
          const SizedBox(height: 12),
          field(cd, 'Property and location', lines: 2), field(cb, 'Budget (₦)', kb: TextInputType.number),
          Btn('Upload plans, survey/title documents and site images (${attachments.length})', outline: true, icon: Icons.upload_file, onTap: _addDocuments),
          if (attachments.isNotEmpty) ...[for (final a in attachments) ListTile(dense: true, leading: const Icon(Icons.description_outlined), title: Text(a.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => attachments.remove(a))))],
          Btn('Apply for construction', onTap: () => _send('construction', '$type — ${cd.text}', num.tryParse(cb.text), reload)),
        ])),
        sub('My requests'),
        if (rq.isEmpty) empty(Icons.assignment_outlined, 'No requests yet.'),
        for (final r in rq) Surface(child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${r['kind']}'.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), grey('${r['details']}'), if (((r['attachments'] as List?) ?? []).isNotEmpty) ...[for (final a in r['attachments'] as List) TextButton.icon(onPressed: () => openPrivateFile(a.toString(), c), icon: const Icon(Icons.download), label: Text(a.toString().split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis))]])), Pill('${r['status']}', warn: r['status'] != 'done')])),
      ]));
}

// ---------- Dashboard ----------
class Dash extends StatelessWidget {
  final Json me;
  const Dash({super.key, required this.me});
  Widget _k(IconData i, String a, String b) => Expanded(child: Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(i, color: K.green), const SizedBox(height: 8), grey(a), Text(b, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20))])));
  @override
  Widget build(BuildContext c) => Q<Json>(
      load: () async {
        final r = await Future.wait<dynamic>([sb.from('sales').select().order('created_at'), sb.from('lands').select('id').eq('seller_id', me['id']).eq('status', 'live')]);
        return {'sales': r[0], 'live': r[1]};
      },
      builder: (c, d, reload) {
        final all = rows(d['sales']);
        final sold = all.where((x) => x['seller_id'] == me['id']).toList();
        final bought = all.where((x) => x['buyer_id'] == me['id']).length;
        final net = sold.fold<num>(0, (a, x) => a + numOf(x['seller_net']));
        final fees = sold.fold<num>(0, (a, x) => a + numOf(x['seller_fee']));
        final last = sold.length > 8 ? sold.sublist(sold.length - 8) : sold;
        final mx = last.fold<double>(1, (a, x) => max(a, numOf(x['seller_net']).toDouble()));
        return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 24), children: [
          head(c, 'Your dashboard'),
          Surface(gradient: kGradient, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Net gains', style: TextStyle(color: Colors.white70)), Text(naira(net), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)), const Text('After the 10% LAND METRICS fee', style: TextStyle(color: K.lime, fontSize: 12))])),
          Row(children: [_k(Icons.handshake_outlined, 'Lands sold', '${sold.length}'), const SizedBox(width: 12), _k(Icons.storefront_outlined, 'Active listings', '${rows(d['live']).length}')]),
          Row(children: [_k(Icons.percent_rounded, 'Fees paid (10%)', naira(fees)), const SizedBox(width: 12), _k(Icons.shopping_bag_outlined, 'Bought', '$bought')]),
          Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Earnings per sale', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 14),
            if (last.isEmpty) grey('Your earnings will appear here after your first sale.') else SizedBox(height: 120, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [for (final x in last) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Container(height: max(8.0, 120 * numOf(x['seller_net']).toDouble() / mx), decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [K.green, K.lime]), borderRadius: const BorderRadius.vertical(top: Radius.circular(8))))))])),
          ])),
        ]);
      });
}

// ---------- Chat ----------
class ChatView extends StatefulWidget {
  final Json me; final String uid;
  const ChatView({super.key, required this.me, required this.uid});
  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final tc = TextEditingController();
  late final Stream<Rows> stream = sb.from('messages').stream(primaryKey: ['id']).eq('thread_user', widget.uid).order('created_at', ascending: false);
  Future<void> _send() async {
    final b = tc.text.trim();
    if (b.isEmpty) return;
    tc.clear();
    try { await sb.from('messages').insert({'thread_user': widget.uid, 'body': b}); } catch (e) { if (mounted) toast(context, 'Message not sent: $e'); }
  }
  Future<void> _attach() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf','doc','docx','jpg','jpeg','png','xlsx','xls'], withData: true);
    if (picked == null || picked.files.single.bytes == null) return;
    final f = picked.files.single;
    try {
      final path = '${sb.auth.currentUser!.id}/chat/${DateTime.now().microsecondsSinceEpoch}_${f.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
      await sb.storage.from('land-documents').uploadBinary(path, f.bytes!);
      await sb.from('messages').insert({'thread_user': widget.uid, 'body': 'Shared a file: ${f.name}', 'attachment_path': path, 'attachment_name': f.name});
    } catch (e) { if (mounted) toast(context, 'Could not send file: $e'); }
  }
  @override
  Widget build(BuildContext c) {
    final cs = Theme.of(c).colorScheme;
    return Column(children: [
      Expanded(child: StreamBuilder<Rows>(stream: stream, builder: (c, s) {
        final m = s.data ?? [];
        if (s.connectionState == ConnectionState.waiting && m.isEmpty) return const Center(child: CircularProgressIndicator());
        if (m.isEmpty) return empty(Icons.forum_outlined, 'Say hello. Only our admins can see this chat.');
        return ListView.builder(reverse: true, itemCount: m.length, itemBuilder: (_, k) {
          final x = m[k]; final mine = x['sender_id'] == widget.me['id'];
          return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: BoxConstraints(maxWidth: MediaQuery.of(c).size.width * .75), margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: mine ? K.green : cs.surfaceContainerHighest, borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(mine ? 18 : 4), bottomRight: Radius.circular(mine ? 4 : 18))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text('${x['body']}', style: TextStyle(color: mine ? Colors.white : cs.onSurface)), if (x['attachment_path'] != null) TextButton.icon(onPressed: () => openPrivateFile(x['attachment_path'].toString(), c), icon: Icon(Icons.download, color: mine ? Colors.white : K.green), label: Text('Download ${x['attachment_name'] ?? 'file'}', style: TextStyle(color: mine ? Colors.white : K.green))) ])));
        });
      })),
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [IconButton(tooltip: 'Attach document or image', onPressed: _attach, icon: const Icon(Icons.attach_file)), Expanded(child: TextField(controller: tc, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Type a message'))), const SizedBox(width: 8), IconButton.filled(tooltip: 'Send', onPressed: _send, icon: const Icon(Icons.send_rounded))])),
    ]);
  }
}


class ProfilePage extends StatefulWidget {
  final Json me;
  const ProfilePage({super.key, required this.me});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}
class _ProfilePageState extends State<ProfilePage> {
  late final name = TextEditingController(text: widget.me['full_name'] ?? '');
  late final phone = TextEditingController(text: widget.me['phone'] ?? '');
  bool busy = false;
  String? avatar;
  @override void initState() { super.initState(); avatar = widget.me['avatar_url'] as String?; }
  Future<void> _photo() async {
    final fs = await pickImages(multi: false);
    if (fs.isEmpty) return;
    setState(() => busy = true);
    try {
      final url = await uploadImage(fs.first);
      await sb.from('profiles').update({'avatar_url': url}).eq('id', widget.me['id']);
      if (mounted) setState(() => avatar = url);
      if (mounted) toast(context, 'Profile picture updated.');
    } catch (e) { if (mounted) toast(context, 'Could not update picture: $e'); }
    if (mounted) setState(() => busy = false);
  }
  Future<void> _save() async {
    setState(() => busy = true);
    try {
      await sb.from('profiles').update({'full_name': name.text.trim(), 'phone': phone.text.trim()}).eq('id', widget.me['id']);
      if (mounted) toast(context, 'Profile updated.');
    } catch (e) { if (mounted) toast(context, 'Could not save profile: $e'); }
    if (mounted) setState(() => busy = false);
  }
  @override
  Widget build(BuildContext c) => ListView(padding: const EdgeInsets.only(bottom: 24), children: [
    head(c, 'My profile'),
    Center(child: Column(children: [
      CircleAvatar(radius: 48, backgroundImage: avatar == null ? null : NetworkImage(avatar!), child: avatar == null ? const Icon(Icons.person, size: 44) : null),
      TextButton.icon(onPressed: busy ? null : _photo, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Update profile picture')),
    ])),
    Surface(child: Column(children: [
      field(name, 'Full name'), field(phone, 'Phone number', kb: TextInputType.phone),
      Btn('Save profile', busy: busy, onTap: _save),
      grey('Email: ${sb.auth.currentUser?.email ?? ''}'),
      grey('Login sessions are securely maintained by Supabase. Never share your password or reset code.'),
    ])),
  ]);
}
