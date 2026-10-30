import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final sb = Supabase.instance.client;
typedef Json = Map<String, dynamic>;
typedef Rows = List<Json>;
Rows rows(dynamic v) => (v as List).cast<Json>();
String naira(num? n) => '₦${NumberFormat('#,##0').format((n ?? 0).round())}';
num numOf(dynamic v) => v is num ? v : (num.tryParse('$v') ?? 0);

class K {
  static const deep = Color(0xFF06402A), green = Color(0xFF0F7A47), lime = Color(0xFF7ED957), gold = Color(0xFFD9A520);
}

const kGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [K.deep, K.green]);

ThemeData theme(Brightness b) {
  final dark = b == Brightness.dark;
  final cs = ColorScheme.fromSeed(seedColor: K.green, brightness: b).copyWith(primary: dark ? K.lime : K.green, onPrimary: dark ? K.deep : Colors.white);
  final base = ThemeData(useMaterial3: true, colorScheme: cs);
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: dark ? const Color(0xFF2A3A30) : const Color(0xFFDCE5DE)));
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  const txt = TextStyle(fontWeight: FontWeight.w700, fontSize: 15);
  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xFF0B1410) : const Color(0xFFF3F7F4),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, foregroundColor: cs.onSurface),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: dark ? const Color(0xFF16221B) : Colors.white, border: border, enabledBorder: border, focusedBorder: border.copyWith(borderSide: BorderSide(color: cs.primary, width: 1.6)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: shape, textStyle: txt)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: shape, textStyle: txt)),
  );
}

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

Future<bool> confirm(BuildContext c, String t) async =>
    (await showDialog<bool>(context: c, builder: (ctx) => AlertDialog(title: const Text('Please confirm'), content: Text(t), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(90, 44)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes'))]))) == true;

final _picker = ImagePicker();
Future<List<XFile>> pickImages({bool multi = true}) async {
  if (multi) return _picker.pickMultiImage(imageQuality: 70, limit: 8);
  final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
  return x == null ? [] : [x];
}

Future<String> uploadImage(XFile f) async {
  final uid = sb.auth.currentUser!.id;
  final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : 'jpg';
  final path = '$uid/${DateTime.now().microsecondsSinceEpoch}.$ext';
  await sb.storage.from('land-images').uploadBinary(path, await f.readAsBytes(), fileOptions: FileOptions(contentType: ext == 'png' ? 'image/png' : 'image/jpeg'));
  return sb.storage.from('land-images').getPublicUrl(path);
}

Widget head(BuildContext c, String t) => Padding(padding: const EdgeInsets.only(top: 6, bottom: 12), child: Text(t, style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)));
Widget sub(String t) => Padding(padding: const EdgeInsets.only(top: 8, bottom: 10), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)));
Widget grey(String t) => Text(t, style: const TextStyle(color: Colors.grey, fontSize: 13));
Widget empty(IconData i, String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 28), child: Center(child: Column(children: [Icon(i, size: 42, color: Colors.grey), const SizedBox(height: 8), Text(t, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))])));
Widget field(TextEditingController c, String label, {TextInputType? kb, int lines = 1, bool obscure = false, IconData? icon}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c, keyboardType: kb, maxLines: obscure ? 1 : lines, obscureText: obscure, decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon, size: 20))));

class Logo extends StatelessWidget {
  final double s;
  const Logo({super.key, this.s = 40});
  @override
  Widget build(BuildContext c) => ClipRRect(borderRadius: BorderRadius.circular(s * .22), child: Image.asset('assets/icon.png', width: s, height: s, fit: BoxFit.cover));
}

class Pill extends StatelessWidget {
  final String t; final bool warn;
  const Pill(this.t, {super.key, this.warn = false});
  @override
  Widget build(BuildContext c) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: warn ? const Color(0x33D9A520) : const Color(0x220F7A47), borderRadius: BorderRadius.circular(99)), child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: warn ? const Color(0xFFB58200) : K.green)));
}

class Surface extends StatelessWidget {
  final Widget child; final EdgeInsets? pad; final VoidCallback? onTap; final Color? color; final Gradient? gradient;
  const Surface({super.key, required this.child, this.pad, this.onTap, this.color, this.gradient});
  @override
  Widget build(BuildContext c) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 14), clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: gradient == null ? (color ?? (dark ? const Color(0xFF16221B) : Colors.white)) : null, gradient: gradient, borderRadius: BorderRadius.circular(20), border: Border.all(color: dark ? const Color(0xFF243329) : const Color(0xFFE2EAE4)), boxShadow: dark ? null : const [BoxShadow(color: Color(0x0D000000), blurRadius: 14, offset: Offset(0, 6))]),
      child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, child: Padding(padding: pad ?? const EdgeInsets.all(16), child: child))),
    );
  }
}

class Btn extends StatelessWidget {
  final String t; final VoidCallback? onTap; final bool busy, outline; final IconData? icon;
  const Btn(this.t, {super.key, this.onTap, this.busy = false, this.outline = false, this.icon});
  @override
  Widget build(BuildContext c) {
    final label = Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)], Flexible(child: Text(t, overflow: TextOverflow.ellipsis))]);
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: outline
        ? OutlinedButton(onPressed: busy ? null : onTap, child: label)
        : FilledButton(onPressed: busy ? null : onTap, child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4)) : label));
  }
}

class Ph extends StatelessWidget {
  const Ph({super.key});
  @override
  Widget build(BuildContext c) => Container(decoration: const BoxDecoration(gradient: kGradient), child: const Center(child: Icon(Icons.landscape_rounded, color: Colors.white54, size: 44)));
}

class NetImg extends StatelessWidget {
  final String? url;
  const NetImg(this.url, {super.key});
  @override
  Widget build(BuildContext c) {
    final u = url;
    return u == null ? const Ph() : CachedNetworkImage(imageUrl: u, fit: BoxFit.cover, width: double.infinity, height: double.infinity, placeholder: (_, __) => Container(color: const Color(0x14000000)), errorWidget: (_, __, ___) => const Ph());
  }
}

class Gallery extends StatefulWidget {
  final List imgs; final double h;
  const Gallery({super.key, required this.imgs, this.h = 220});
  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  int i = 0;
  @override
  Widget build(BuildContext c) {
    final n = widget.imgs.length;
    return ClipRRect(borderRadius: BorderRadius.circular(20), child: SizedBox(height: widget.h, child: Stack(fit: StackFit.expand, children: [
      n == 0 ? const Ph() : PageView.builder(itemCount: n, onPageChanged: (v) => setState(() => i = v), itemBuilder: (_, k) => NetImg(widget.imgs[k] as String)),
      if (n > 1) Positioned(bottom: 10, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var k = 0; k < n; k++) AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 2), width: k == i ? 18 : 6, height: 6, decoration: BoxDecoration(color: k == i ? Colors.white : Colors.white60, borderRadius: BorderRadius.circular(9)))])),
    ])));
  }
}

class Q<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, Future<void> Function()) builder;
  const Q({super.key, required this.load, required this.builder});
  @override
  State<Q<T>> createState() => _QState<T>();
}

class _QState<T> extends State<Q<T>> {
  T? data; Object? err; bool has = false;
  @override
  void initState() { super.initState(); reload(); }
  Future<void> reload() async {
    try { final d = await widget.load(); if (mounted) setState(() { data = d; has = true; err = null; }); }
    catch (e) { if (mounted) setState(() => err = e); }
  }
  @override
  Widget build(BuildContext c) {
    if (!has) {
      if (err != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_rounded, size: 42), const SizedBox(height: 8), Text(err is PostgrestException ? (err as PostgrestException).message : 'Could not load. Check your connection.', textAlign: TextAlign.center), TextButton(onPressed: reload, child: const Text('Retry'))]));
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(onRefresh: reload, child: widget.builder(c, data as T, reload));
  }
}

class Shell extends StatefulWidget {
  final bool admin; final List<(String, IconData, Widget Function())> tabs;
  const Shell({super.key, required this.tabs, this.admin = false});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(titleSpacing: 16, title: Row(children: [const Logo(s: 34), const SizedBox(width: 10), const Text('LAND METRICS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 17)), if (widget.admin) ...[const SizedBox(width: 8), const Pill('ADMIN', warn: true)]]), actions: [IconButton(tooltip: 'Log out', icon: const Icon(Icons.logout_rounded), onPressed: () => sb.auth.signOut())]),
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: widget.tabs[i].$3()))),
        bottomNavigationBar: NavigationBar(selectedIndex: i, onDestinationSelected: (v) => setState(() => i = v), destinations: [for (final t in widget.tabs) NavigationDestination(icon: Icon(t.$2), label: t.$1)]),
      );
}

Future<void> openPrivateFile(String path, BuildContext context) async {
  try {
    final url = await sb.storage.from('land-documents').createSignedUrl(path, 600);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    if (context.mounted) toast(context, 'Could not open document: $e');
  }
}
