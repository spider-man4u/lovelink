import 'package:flutter_test/flutter_test.dart';

import 'package:lovelink/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const LoveLinkApp());
    expect(find.text('LoveLink'), findsOneWidget);
  });
}
