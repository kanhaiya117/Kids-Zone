import 'package:flutter_test/flutter_test.dart';

import 'package:kidszone/src/app.dart';

void main() {
  testWidgets('KidsZone app widget is defined', (WidgetTester tester) async {
    expect(const KidsZoneApp(), isA<KidsZoneApp>());
  });
}
