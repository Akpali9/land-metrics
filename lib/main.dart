import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const brand = Color(0xFF176B4D);
const ink = Color(0xFF17231D);
const canvas = Color(0xFFF6F8F5);

// ---------------------------------------------------------------------------
// Configuration (supply with --dart-define, see notes at the bottom)
// ---------------------------------------------------------------------------
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// True only when the app was compiled with real Supabase credentials.
/// When false the app runs in local-preview mode (no cloud calls at all).
bool get cloudEnabled => _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

SupabaseClient get sb => Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (cloudEnabled) {
    // ignore: deprecated_member_use
    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  }
  runApp(const LandMetricsApp());
}

class LandMetricsApp extends StatelessWidget {
  const LandMetricsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'LAND METRICS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: canvas,
          colorScheme: ColorScheme.fromSeed(seedColor: brand),
          appBarTheme:
              const AppBarTheme(backgroundColor: canvas, foregroundColor: ink),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
        home: const HomePage(),
      );
}

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------
class AdListing {
  final String? id;
  final String title;
  final String description;
  final String location;
  final String price;
  final File? image; // local file (offline preview / just picked)
  final String? imageUrl; // remote public URL
  final String status;

  AdListing({
    this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.price,
    this.image,
    this.imageUrl,
    this.status = 'pending',
  });

  factory AdListing.fromRow(Map<String, dynamic> row) => AdListing(
        id: row['id']?.toString(),
        title: (row['title'] ?? '').toString(),
        description: (row['description'] ?? '').toString(),
        location: (row['location'] ?? '').toString(),
        price: (row['price'] ?? '').toString(),
        imageUrl: row['image_url'] as String?,
        status: (row['status'] ?? 'pending').toString(),
      );
}

/// Result returned by [CreateAdPage].
class SubmitOutcome {
  /// Set only in local-preview mode (no cloud configured).
  final AdListing? localAd;

  /// True when the ad was written to Supabase and is awaiting review.
  final bool submitted;

  const SubmitOutcome({this.localAd, this.submitted = false});
}

// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  int feedVersion = 0;
  final ads = <AdListing>[];
  StreamSubscription<AuthState>? _authSub;

  bool get _isAdmin {
    if (!cloudEnabled) return false;
    final user = sb.auth.currentUser;
    return user?.appMetadata['role'] == 'admin';
  }

  @override
  void initState() {
    super.initState();
    if (cloudEnabled) {
      _authSub = sb.auth.onAuthStateChange.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ExplorePage(
        localAds: ads,
        onCreate: _createAd,
        version: feedVersion,
      ),
      const SavedPage(),
      const ProfilePage(),
      if (_isAdmin) const AdminPage(),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore),
          label: 'Explore'),
      const NavigationDestination(
          icon: Icon(Icons.bookmark_border),
          selectedIcon: Icon(Icons.bookmark),
          label: 'Saved'),
      const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile'),
      if (_isAdmin)
        const NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'Admin'),
    ];

    final safeTab = tab.clamp(0, pages.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.landscape_rounded, color: brand, size: 30),
          SizedBox(width: 9),
          Text('LAND ',
              style:
                  TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          Text('METRICS',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: brand,
                  letterSpacing: 1.2)),
        ]),
        actions: [
          IconButton(
              onPressed: _createAd,
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Create advertisement'),
        ],
      ),
      body: pages[safeTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeTab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: destinations,
      ),
      floatingActionButton: safeTab == 0
          ? FloatingActionButton.extended(
              onPressed: _createAd,
              backgroundColor: brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Post an ad'))
          : null,
    );
  }

  Future<void> _createAd() async {
    // Posting requires an account when cloud mode is on.
    if (cloudEnabled && sb.auth.currentUser == null) {
      final signedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (signedIn != true || !mounted) return;
    }

    final outcome = await Navigator.push<SubmitOutcome>(
      context,
      MaterialPageRoute(builder: (_) => const CreateAdPage()),
    );
    if (outcome == null || !mounted) return;

    if (outcome.localAd != null) {
      setState(() {
        ads.insert(0, outcome.localAd!);
        feedVersion++;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ad added to your preview feed. '
              'Configure Supabase to publish it online.')));
    } else if (outcome.submitted) {
      setState(() => feedVersion++);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Submitted for review. An admin will approve it.')));
    }
  }
}

// ---------------------------------------------------------------------------
// Explore
// ---------------------------------------------------------------------------
class ExplorePage extends StatefulWidget {
  const ExplorePage({
    super.key,
    required this.localAds,
    required this.onCreate,
    required this.version,
  });

  final List<AdListing> localAds;
  final VoidCallback onCreate;
  final int version;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  List<AdListing> remote = [];
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ExplorePage old) {
    super.didUpdateWidget(old);
    if (old.version != widget.version) _load();
  }

  Future<void> _load() async {
    if (!cloudEnabled) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await sb
          .from('advertisements')
          .select()
          .eq('status', 'approved');
      final list = (rows as List)
          .map((e) => AdListing.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (!mounted) return;
      setState(() {
        remote = list;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.localAds, ...remote];

    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF124C38), Color(0xFF21815B)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FIND LAND.\nBUILD YOUR FUTURE.',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        height: 1.15,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text('Discover verified opportunities and property listings.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: .85))),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: brand),
                  onPressed: widget.onCreate,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Advertise a property'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text('Explore properties',
              style: TextStyle(
                  fontSize: 21, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                CategoryChip(label: 'All properties', selected: true),
                CategoryChip(label: 'Land'),
                CategoryChip(label: 'Residential'),
                CategoryChip(label: 'Commercial'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          if (error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F0),
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Color(0xFFB3261E)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('Could not load listings: $error',
                        style: const TextStyle(fontSize: 12))),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ]),
            ),
          if (all.isNotEmpty) ...[
            const Text('Recent ads',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 10),
            ...all.map((a) => AdCard(ad: a)),
          ],
          const PropertyCard(
              title: 'Residential land opportunity',
              location: 'Awka, Anambra State',
              price: 'Contact for price',
              icon: Icons.landscape_outlined,
              tag: 'LAND'),
          const PropertyCard(
              title: 'Modern family home',
              location: 'Enugu, Enugu State',
              price: 'Contact for price',
              icon: Icons.house_outlined,
              tag: 'HOUSE'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: const Row(children: [
              Icon(Icons.verified_user_outlined, color: brand, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Make informed property decisions',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                          'Verify ownership and documents independently before making payments.',
                          style: TextStyle(color: Colors.black54)),
                    ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  const CategoryChip({super.key, required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Chip(
          label: Text(label),
          backgroundColor: selected ? brand : Colors.white,
          labelStyle: TextStyle(
              color: selected ? Colors.white : ink,
              fontWeight: FontWeight.w600),
          side: BorderSide.none,
        ),
      );
}

class PropertyCard extends StatelessWidget {
  final String title, location, price, tag;
  final IconData icon;
  const PropertyCard({
    super.key,
    required this.title,
    required this.location,
    required this.price,
    required this.icon,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Container(
            width: 90,
            height: 100,
            decoration: BoxDecoration(
                color: const Color(0xFFE4EEE7),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, size: 42, color: brand),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tag,
                  style: const TextStyle(
                      color: brand,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
              const SizedBox(height: 5),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(location, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 7),
              Text(price,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: brand)),
            ]),
          ),
        ]),
      );
}

class AdCard extends StatelessWidget {
  final AdListing ad;
  const AdCard({super.key, required this.ad});

  Widget _image() {
    const fallback = ColoredBox(
      color: Color(0xFFE4EEE7),
      child: Center(child: Icon(Icons.image_outlined, size: 44, color: brand)),
    );

    if (ad.image != null) {
      return Image.file(ad.image!,
          height: 190, width: double.infinity, fit: BoxFit.cover);
    }
    if (ad.imageUrl != null && ad.imageUrl!.isNotEmpty) {
      return Image.network(
        ad.imageUrl!,
        height: 190,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const SizedBox(height: 130, child: fallback),
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const SizedBox(
                height: 190,
                child: Center(
                    child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2)))),
      );
    }
    return const SizedBox(height: 130, child: fallback);
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _image(),
          Padding(
            padding: const EdgeInsets.all(15),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('LISTING',
                  style: TextStyle(
                      color: brand,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1)),
              const SizedBox(height: 5),
              Text(ad.title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              Text(ad.location, style: const TextStyle(color: Colors.black54)),
              if (ad.price.isNotEmpty)
                Text(ad.price,
                    style: const TextStyle(
                        color: brand, fontWeight: FontWeight.bold)),
              if (ad.description.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(ad.description)),
            ]),
          ),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Create ad
// ---------------------------------------------------------------------------
class CreateAdPage extends StatefulWidget {
  const CreateAdPage({super.key});
  @override
  State<CreateAdPage> createState() => _CreateAdPageState();
}

class _CreateAdPageState extends State<CreateAdPage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final location = TextEditingController();
  final price = TextEditingController();
  File? image;
  bool busy = false;

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    location.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 1800);
    if (x != null) setState(() => image = File(x.path));
  }

  AdListing _localListing() => AdListing(
        title: title.text.trim(),
        description: description.text.trim(),
        location: location.text.trim(),
        price: price.text.trim(),
        image: image,
      );

  Future<void> submit() async {
    if (!(form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => busy = true);

    try {
      if (cloudEnabled) {
        String? publicUrl;
        if (image != null) {
          final ext = image!.path.contains('.')
              ? image!.path.split('.').last
              : 'jpg';
          final name = 'ad_${DateTime.now().millisecondsSinceEpoch}.$ext';
          await sb.storage.from('ad-images').upload(name, image!);
          publicUrl = sb.storage.from('ad-images').getPublicUrl(name);
        }
        await sb.from('advertisements').insert({
          'title': title.text.trim(),
          'description': description.text.trim(),
          'location': location.text.trim(),
          'price': price.text.trim(),
          'image_url': publicUrl,
          'status': 'pending',
        });
        if (!mounted) return;
        Navigator.pop(context, const SubmitOutcome(submitted: true));
        return;
      }

      // Local-preview mode: no cloud configured.
      if (!mounted) return;
      Navigator.pop(context, SubmitOutcome(localAd: _localListing()));
    } catch (e) {
      // Do NOT pop here — a failed upload must not look like a success.
      if (!mounted) return;
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFFB3261E),
        content: Text('Publish failed: $e'),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: submit,
        ),
      ));
      return;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Create an advertisement',
                style: TextStyle(fontWeight: FontWeight.w800))),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text('Showcase your property',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text(
                  'Add a great photo and clear details to help buyers discover your listing.'),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: busy ? null : pick,
                child: Container(
                  height: 210,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: brand.withValues(alpha: .35))),
                  child: image == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 45, color: brand),
                              SizedBox(height: 10),
                              Text('Add photos for your ad',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800)),
                              Text('Tap to choose an image from your device',
                                  style:
                                      TextStyle(color: Colors.black54)),
                            ])
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(image!,
                              fit: BoxFit.cover, width: double.infinity)),
                ),
              ),
              const SizedBox(height: 18),
              _field(title, 'Ad headline', required: true),
              const SizedBox(height: 12),
              _field(location, 'Location', required: true),
              const SizedBox(height: 12),
              _field(price, 'Price (optional)'),
              const SizedBox(height: 12),
              _field(description, 'Description', lines: 4),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: busy ? null : submit,
                  style: FilledButton.styleFrom(backgroundColor: brand),
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.campaign_outlined),
                  label: Text(busy
                      ? 'Publishing…'
                      : cloudEnabled
                          ? 'Submit for review'
                          : 'Preview and publish ad'),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                cloudEnabled
                    ? 'Your ad is submitted as “pending” and appears in Explore only after an admin approves it.'
                    : 'Online publishing is disabled — Supabase credentials were not supplied at build time.',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      );

  Widget _field(TextEditingController c, String label,
          {bool required = false, int lines = 1}) =>
      TextFormField(
        controller: c,
        maxLines: lines,
        enabled: !busy,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter ${label.toLowerCase()}'
                : null
            : null,
        decoration: InputDecoration(
            labelText: label, alignLabelWithHint: lines > 1),
      );
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool signUp = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });

    try {
      if (signUp) {
        final res = await sb.auth.signUp(
            email: email.text.trim(), password: password.text);
        if (res.session == null) {
          if (!mounted) return;
          setState(() {
            busy = false;
            signUp = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Account created. Confirm your email, then sign in.')));
          return;
        }
      } else {
        await sb.auth.signInWithPassword(
            email: email.text.trim(), password: password.text);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sign in')),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 10),
              const Icon(Icons.landscape_rounded, size: 52, color: brand),
              const SizedBox(height: 12),
              Text(signUp ? 'Create an account' : 'Welcome back',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                  signUp
                      ? 'Create an account to publish property listings.'
                      : 'Sign in to publish and manage listings.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 24),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Enter your email';
                  if (!s.contains('@') || !s.contains('.')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: password,
                obscureText: true,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) {
                  if ((v ?? '').isEmpty) return 'Enter your password';
                  if (signUp && v!.length < 6) {
                    return 'Use at least 6 characters';
                  }
                  return null;
                },
              ),
              if (error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F0),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFB3261E), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(error!,
                            style: const TextStyle(fontSize: 13))),
                  ]),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: busy ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: brand),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(signUp ? 'Create account' : 'Sign in'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                          signUp = !signUp;
                          error = null;
                        }),
                child: Text(signUp
                    ? 'Already have an account? Sign in'
                    : 'No account? Create one'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Admin accounts are provisioned in the Supabase dashboard '
                '(Authentication → Users → Add user, with app_metadata '
                '{"role": "admin"}).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black45, fontSize: 12),
              ),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Admin
// ---------------------------------------------------------------------------
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<AdListing> all = [];
  bool loading = true;
  String? error;
  String filter = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await sb.from('advertisements').select();
      final list = (rows as List)
          .map((e) => AdListing.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (!mounted) return;
      setState(() {
        all = list;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _setStatus(AdListing ad, String status) async {
    if (ad.id == null) return;
    try {
      await sb
          .from('advertisements')
          .update({'status': status}).eq('id', ad.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ad marked “$status”.')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFFB3261E),
        content: Text('Update failed: $e'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = all.where((a) => a.status == filter).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
        child: Row(children: [
          const Icon(Icons.admin_panel_settings, color: brand),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('Advertisements',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          IconButton(
              onPressed: loading ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload'),
        ]),
      ),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          children: [
            for (final f in const ['pending', 'approved', 'rejected'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                      '${f[0].toUpperCase()}${f.substring(1)} '
                      '(${all.where((a) => a.status == f).length})'),
                  selected: filter == f,
                  onSelected: (_) => setState(() => filter = f),
                  selectedColor: brand,
                  labelStyle: TextStyle(
                      color: filter == f ? Colors.white : ink,
                      fontWeight: FontWeight.w600),
                  side: BorderSide.none,
                  backgroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Expanded(child: _body(visible)),
    ]);
  }

  Widget _body(List<AdListing> visible) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 44, color: Color(0xFFB3261E)),
            const SizedBox(height: 10),
            Text('Could not load advertisements.\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }
    if (visible.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.inbox_outlined, size: 48, color: brand),
          const SizedBox(height: 8),
          Text('No $filter advertisements',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
    }
    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final ad = visible[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ad.title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                  '${ad.location}  •  ${ad.price.isEmpty ? "No price" : ad.price}',
                  style: const TextStyle(color: Colors.black54, fontSize: 13)),
              if (ad.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(ad.description,
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              Row(children: [
                _statusPill(ad.status),
                const Spacer(),
                if (ad.status != 'approved')
                  TextButton.icon(
                    onPressed: () => _setStatus(ad, 'approved'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: TextButton.styleFrom(foregroundColor: brand),
                  ),
                if (ad.status != 'rejected')
                  TextButton.icon(
                    onPressed: () => _setStatus(ad, 'rejected'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB3261E)),
                  ),
              ]),
            ]),
          );
        },
      ),
    );
  }

  Widget _statusPill(String status) {
    final color = switch (status) {
      'approved' => brand,
      'rejected' => const Color(0xFFB3261E),
      _ => const Color(0xFF8A6D00),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile / Saved
// ---------------------------------------------------------------------------
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!cloudEnabled) {
      return _shell(context, _signedOut(context, localMode: true));
    }

    return StreamBuilder<AuthState>(
      stream: sb.auth.onAuthStateChange,
      builder: (context, _) {
        final user = sb.auth.currentUser;
        if (user == null) return _shell(context, _signedOut(context));
        return _shell(context, _signedIn(context, user));
      },
    );
  }

  Widget _shell(BuildContext context, Widget child) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
              radius: 36,
              backgroundColor: Color(0xFFDDECE2),
              child: Icon(Icons.person_outline, size: 38, color: brand)),
          const SizedBox(height: 12),
          child,
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.campaign_outlined, color: brand),
              title: const Text('My advertisements'),
              subtitle: const Text('Create and manage property ads'),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Use “Post an ad” from Explore to create a listing.'))),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.verified_outlined, color: brand),
              title: Text('Property verification'),
              subtitle:
                  Text('Confirm ownership and documents before purchase.'),
            ),
          ),
        ],
      );

  Widget _signedOut(BuildContext context, {bool localMode = false}) => Column(
        children: [
          const Center(
              child: Text('Welcome to LAND METRICS',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          const SizedBox(height: 6),
          Center(
            child: Text(
              localMode
                  ? 'Local preview mode — no Supabase configuration.'
                  : 'Sign in to publish listings and manage your ads.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          if (!localMode) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: brand),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LoginPage())),
                child: const Text('Sign in or create an account'),
              ),
            ),
          ],
        ],
      );

  Widget _signedIn(BuildContext context, User user) {
    final isAdmin = user.appMetadata['role'] == 'admin';
    return Column(children: [
      Center(
          child: Text(user.email ?? 'Signed in',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
      const SizedBox(height: 6),
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: isAdmin
                  ? brand.withValues(alpha: .12)
                  : Colors.black.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(20)),
          child: Text(isAdmin ? 'ADMINISTRATOR' : 'MEMBER',
              style: TextStyle(
                  color: isAdmin ? brand : Colors.black54,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1)),
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () async {
          await sb.auth.signOut();
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Signed out.')));
          }
        },
        icon: const Icon(Icons.logout, size: 18),
        label: const Text('Sign out'),
      ),
    ]);
  }
}

class SavedPage extends StatelessWidget {
  const SavedPage({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bookmark_border, size: 54, color: brand),
          SizedBox(height: 10),
          Text('Your saved properties',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text('Save listings you want to revisit.'),
        ]),
      );
}
