import 'package:flutter_test/flutter_test.dart';
import 'package:land_metrics/main.dart';

void main() {
  testWidgets('renders the LAND METRICS home screen', (tester) async {
    await tester.pumpWidget(const LandMetricsApp());
    await tester.pump();

    expect(find.text('LAND '), findsOneWidget);
    expect(find.text('METRICS'), findsOneWidget);
  });
}
