import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core.dart';
import 'fx.dart';

Future<String> askAI(Json body) async {
  final r = await sb.functions.invoke('ai', body: body);
  final d = r.data;
  if (d is Map && d['text'] is String) return (d['text'] as String).trim();
  throw 'The AI assistant is unavailable right now. Please try again.';
}

class AiFab extends StatefulWidget {
  const AiFab({super.key});
  @override
  State<AiFab> createState() => _AiFabState();
}

class _AiFabState extends State<AiFab> with SingleTickerProviderStateMixin {
  late final ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  @override
  void dispose() { ctl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) => AnimatedBuilder(animation: ctl, builder: (_, child) => Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: K.lime.withAlpha(40 + (70 * ctl.value).toInt()), blurRadius: 12 + 14 * ctl.value, spreadRadius: 1)]), child: child),
      child: FloatingActionButton.extended(heroTag: 'ai', backgroundColor: K.deep, foregroundColor: K.lime, icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Ask AI', style: TextStyle(fontWeight: FontWeight.w800)), onPressed: () { HapticFeedback.selectionClick(); Navigator.push(c, MaterialPageRoute(fullscreenDialog: true, builder: (_) => const AiScreen())); }));
}

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final tc = TextEditingController(), sc = ScrollController();
  final List<Json> m = [{'role': 'assistant', 'content': 'Hi, I’m Metrics AI. Ask me about buying or selling land and property, checking documents, or how fees and payments work here.'}];
  bool busy = false;
  static const hints = ['How do I verify a land title?', 'How do the 10% fees work?', 'Which documents should I ask for?', 'Is it safe to pay cash?'];

  void _down() => WidgetsBinding.instance.addPostFrameCallback((_) { if (sc.hasClients) sc.animateTo(sc.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); });

  Future<void> _send([String? t]) async {
    final text = (t ?? tc.text).trim();
    if (text.isEmpty || busy) return;
    tc.clear();
    setState(() { m.add({'role': 'user', 'content': text}); busy = true; });
    _down();
    try {
      final r = await askAI({'mode': 'chat', 'messages': [for (final x in m) if (x['err'] != true) {'role': x['role'], 'content': x['content']}]});
      if (mounted) setState(() => m.add({'role': 'assistant', 'content': r}));
    } catch (e) {
      if (mounted) setState(() => m.add({'role': 'assistant', 'content': msg(e), 'err': true}));
    }
    if (mounted) setState(() => busy = false);
    _down();
  }

  Widget _spark() => Container(width: 28, height: 28, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: kGradient), child: const Icon(Icons.auto_awesome_rounded, size: 15, color: K.lime));

  Widget _bubble(Json x, int k) {
    final me = x['role'] == 'user', err = x['err'] == true;
    final cs = Theme.of(context).colorScheme;
    return FadeSlide(key: ValueKey('b$k'), dy: 12, child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(mainAxisAlignment: me ? MainAxisAlignment.end : MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.end, children: [
      if (!me) ...[_spark(), const SizedBox(width: 8)],
      Flexible(child: Container(constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), decoration: BoxDecoration(color: me ? K.green : (err ? const Color(0x22B3261E) : cs.surfaceContainerHighest), borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(me ? 18 : 4), bottomRight: Radius.circular(me ? 4 : 18))), child: SelectableText('${x['content']}', style: TextStyle(color: me ? Colors.white : cs.onSurface, height: 1.4)))),
    ])));
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Row(children: [_spark(), const SizedBox(width: 10), const Text('Metrics AI', style: TextStyle(fontWeight: FontWeight.w800))])),
        body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 6), child: grey('AI can make mistakes and is not legal advice. For big decisions, speak to a lawyer or use our verification service.')),
          Expanded(child: ListView(controller: sc, padding: const EdgeInsets.all(16), children: [
            for (var k = 0; k < m.length; k++) _bubble(m[k], k),
            if (m.length == 1) FadeSlide(delay: 250, child: Wrap(spacing: 8, runSpacing: 8, children: [for (final h in hints) ActionChip(label: Text(h), avatar: const Icon(Icons.north_east_rounded, size: 14), onPressed: () => _send(h))])),
            if (busy) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [_spark(), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: Theme.of(c).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)), child: const TypingDots())])),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 10), child: Row(children: [Expanded(child: TextField(controller: tc, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Ask Metrics AI…'))), const SizedBox(width: 8), IconButton.filled(tooltip: 'Send', onPressed: busy ? null : _send, icon: const Icon(Icons.arrow_upward_rounded))])),
        ]))))
      );
}

void aiReviewSheet(BuildContext c, Json l) {
  final f = askAI({'mode': 'review', 'listing': {'kind': l['kind'], 'title': l['title'], 'location': l['location'], 'size_sqm': l['size_sqm'], 'price': l['price'], 'description': l['description'], 'details': l['details'], 'photos': ((l['images'] as List?) ?? []).length}});
  showModalBottomSheet(context: c, isScrollControlled: true, showDragHandle: true, builder: (_) => Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.auto_awesome_rounded, color: K.green), SizedBox(width: 8), Text('AI risk check', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))]),
        const SizedBox(height: 4), grey('Advisory only. You make the final decision.'), const SizedBox(height: 16),
        FutureBuilder<String>(future: f, builder: (_, s) {
          if (s.connectionState != ConnectionState.done) return const Row(children: [TypingDots(), SizedBox(width: 10), Text('Checking this listing…', style: TextStyle(color: Colors.grey))]);
          if (s.hasError) return Text(msg(s.error!));
          return SelectableText(s.data ?? '', style: const TextStyle(height: 1.45));
        }),
      ])));
}
