import 'dart:math';
import 'package:flutter/material.dart';
import 'core.dart';
import 'fx.dart';
import 'legal_text.dart';

void openLegal(BuildContext c, String title, List<(String, String)> sections) => Navigator.push(c, MaterialPageRoute(builder: (_) => LegalScreen(title: title, sections: sections)));

class LegalScreen extends StatelessWidget {
  final String title; final List<(String, String)> sections;
  const LegalScreen({super.key, required this.title, required this.sections});
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
          grey('Version $kTermsVersion · Last updated $kLegalDate'),
          const SizedBox(height: 18),
          for (var i = 0; i < sections.length; i++)
            FadeSlide(delay: min(i, 5) * 60, child: Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sections[i].$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              SelectableText(sections[i].$2, style: const TextStyle(height: 1.55)),
            ]))),
        ]))),
      );
}

class LegalAgree extends StatelessWidget {
  final bool value; final ValueChanged<bool> onChanged;
  const LegalAgree({super.key, required this.value, required this.onChanged});
  Widget _link(BuildContext c, String t, List<(String, String)> s) => InkWell(onTap: () => openLegal(c, t, s), child: Text(t, style: const TextStyle(color: K.green, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)));
  @override
  Widget build(BuildContext c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
        Expanded(child: Padding(padding: const EdgeInsets.only(top: 12), child: Wrap(children: [const Text('I agree to the '), _link(c, 'Terms of Service', kTerms), const Text(' and '), _link(c, 'Privacy Policy', kPrivacy)]))),
      ]));
}
