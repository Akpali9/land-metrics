import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core.dart';

class _Delayed extends StatefulWidget {
  final int delay; final Widget Function(double) builder;
  const _Delayed({required this.delay, required this.builder});
  @override
  State<_Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<_Delayed> with SingleTickerProviderStateMixin {
  late final ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final curve = CurvedAnimation(parent: ctl, curve: Curves.easeOutCubic);
  @override
  void initState() { super.initState(); Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) ctl.forward(); }); }
  @override
  void dispose() { ctl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) => AnimatedBuilder(animation: curve, builder: (_, __) => widget.builder(curve.value));
}

class FadeSlide extends StatelessWidget {
  final Widget child; final int delay; final double dy;
  const FadeSlide({super.key, required this.child, this.delay = 0, this.dy = 22});
  @override
  Widget build(BuildContext c) => _Delayed(delay: delay, builder: (v) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, (1 - v) * dy), child: child)));
}

class Pressable extends StatefulWidget {
  final Widget child; final bool enabled;
  const Pressable({super.key, required this.child, this.enabled = true});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool down = false;
  @override
  Widget build(BuildContext c) => Listener(
        onPointerDown: (_) { if (widget.enabled) setState(() => down = true); },
        onPointerUp: (_) => setState(() => down = false),
        onPointerCancel: (_) => setState(() => down = false),
        child: AnimatedScale(scale: down ? .975 : 1, duration: const Duration(milliseconds: 130), curve: Curves.easeOut, child: widget.child),
      );
}

class Skeleton extends StatefulWidget {
  final double h; final double r;
  const Skeleton({super.key, this.h = 120, this.r = 20});
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() { ctl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) => AnimatedBuilder(animation: ctl, builder: (_, __) => Container(height: widget.h, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(borderRadius: BorderRadius.circular(widget.r), gradient: LinearGradient(begin: Alignment(-1.6 + 3.2 * ctl.value, 0), end: Alignment(-0.6 + 3.2 * ctl.value, 0), colors: const [Color(0x14808080), Color(0x2E808080), Color(0x14808080)]))));
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key});
  @override
  Widget build(BuildContext c) => ListView(physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.only(top: 8), children: const [Skeleton(h: 150), Skeleton(h: 44, r: 14), Skeleton(h: 250), Skeleton(h: 250)]);
}

class BobIcon extends StatefulWidget {
  final IconData icon; final double size;
  const BobIcon(this.icon, {super.key, this.size = 48});
  @override
  State<BobIcon> createState() => _BobIconState();
}

class _BobIconState extends State<BobIcon> with SingleTickerProviderStateMixin {
  late final ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  @override
  void dispose() { ctl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) => AnimatedBuilder(animation: ctl, builder: (_, __) => Transform.translate(offset: Offset(0, -6 * Curves.easeInOut.transform(ctl.value)), child: Icon(widget.icon, size: widget.size, color: Colors.grey)));
}

class TypingDots extends StatefulWidget {
  const TypingDots({super.key});
  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  @override
  void dispose() { ctl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) => AnimatedBuilder(animation: ctl, builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [for (var k = 0; k < 3; k++) Container(margin: const EdgeInsets.symmetric(horizontal: 2), width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: K.green.withAlpha((90 + 165 * math.max(0, math.sin((ctl.value * 2 - k * .35) * math.pi))).toInt().clamp(0, 255))))]));
}

class CountUp extends StatelessWidget {
  final double v; final TextStyle? style;
  const CountUp(this.v, {super.key, this.style});
  @override
  Widget build(BuildContext c) => TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: v), duration: const Duration(milliseconds: 1200), curve: Curves.easeOutCubic, builder: (_, x, __) => Text(naira(x), style: style));
}

class Bar extends StatelessWidget {
  final double h; final Decoration decoration;
  const Bar({super.key, required this.h, required this.decoration});
  @override
  Widget build(BuildContext c) => TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: h), duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic, builder: (_, v, __) => Container(height: v, decoration: decoration));
}

class NoNet extends StatelessWidget {
  final bool offline; final VoidCallback onRetry;
  const NoNet({super.key, required this.offline, required this.onRetry});
  @override
  Widget build(BuildContext c) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        BobIcon(offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded, size: 64),
        const SizedBox(height: 18),
        Text(offline ? 'No internet connection' : 'Something went wrong', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(offline ? 'Check your Wi-Fi or mobile data, then try again.' : 'We could not load this right now. Please try again.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 22),
        SizedBox(width: 200, child: FilledButton.icon(onPressed: () { HapticFeedback.lightImpact(); onRetry(); }, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again'))),
      ])));
}

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});
  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool off = false; StreamSubscription<List<ConnectivityResult>>? sub;
  void _set(List<ConnectivityResult> r) { final o = r.isEmpty || r.every((x) => x == ConnectivityResult.none); if (mounted && o != off) setState(() => off = o); }
  @override
  void initState() { super.initState(); Connectivity().checkConnectivity().then(_set); sub = Connectivity().onConnectivityChanged.listen(_set); }
  @override
  void dispose() { sub?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext c) => AnimatedSize(duration: const Duration(milliseconds: 300), curve: Curves.easeOut, child: off
      ? Container(width: double.infinity, color: const Color(0xFFB3261E), padding: const EdgeInsets.symmetric(vertical: 8), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white), SizedBox(width: 8), Text('No internet connection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))]))
      : const SizedBox(width: double.infinity));
}

class Orbs extends StatefulWidget {
  const Orbs({super.key});
  @override
  State<Orbs> createState() => _OrbsState();
}

class _OrbsState extends State<Orbs> with SingleTickerProviderStateMixin {
  late final ctl = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat(reverse: true);
  @override
  void dispose() { ctl.dispose(); super.dispose(); }
  Widget _o(double s, Color col) => Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: col));
  @override
  Widget build(BuildContext c) => AnimatedBuilder(animation: ctl, builder: (_, __) {
        final t = Curves.easeInOut.transform(ctl.value);
        return Stack(children: [Positioned(top: -70 + 50 * t, right: -50, child: _o(240, K.lime.withAlpha(38))), Positioned(bottom: 90 - 60 * t, left: -80, child: _o(280, Colors.white.withAlpha(16)))]);
      });
}

Future<void> showSuccess(BuildContext c, String title, String body) {
  HapticFeedback.mediumImpact();
  return showDialog(context: c, builder: (ctx) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 800), curve: Curves.elasticOut, builder: (_, v, child) => Transform.scale(scale: v, child: child), child: Container(width: 84, height: 84, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: kGradient), child: const Icon(Icons.check_rounded, color: Colors.white, size: 48))),
        const SizedBox(height: 18),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))),
      ]))));
}
