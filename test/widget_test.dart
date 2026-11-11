import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landmetrics/core.dart';
import 'package:landmetrics/fx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('naira formats amounts', () {
    expect(naira(1500000), '₦1,500,000');
    expect(naira(null), '₦0');
  });

  test('offline errors are detected', () {
    expect(isOffline(Exception('SocketException: Failed host lookup')), isTrue);
    expect(isOffline(Exception('boom')), isFalse);
  });

  test('error messages never leak internals', () {
    expect(msg(AuthException('Invalid login credentials')), 'Incorrect email or password.');
    expect(msg(Exception('relation "profiles" does not exist')).contains('profiles'), isFalse);
  });

  test('listing chips differ for land and property', () {
    expect(chips({'kind': 'property', 'details': {'ptype': 'Duplex', 'beds': 4, 'baths': 3, 'furnished': true}}), ['Duplex', '4 bed', '3 bath', 'Furnished']);
    expect(chips({'kind': 'land', 'details': {'doc': 'Deed of Assignment'}}), ['Deed of Assignment']);
  });

  testWidgets('offline screen shows a friendly message', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: NoNet(offline: true, onRetry: () {}))));
    await t.pump();
    expect(find.text('No internet connection'), findsOneWidget);
  });
}
