import 'package:flutter_test/flutter_test.dart';

import 'package:meowpay/main.dart';

void main() {
  testWidgets('renders the Send treats page', (WidgetTester tester) async {
    await tester.pumpWidget(const MeowPayApp());

    expect(find.text('MeowPay'), findsOneWidget);
    expect(find.text('Send treats'), findsOneWidget);
  });
}
