import 'package:flutter_test/flutter_test.dart';
import 'package:land_metrics/core.dart';

void main() {
  test('naira formats amounts', () {
    expect(naira(1500000), '₦1,500,000');
    expect(naira(null), '₦0');
  });
}
