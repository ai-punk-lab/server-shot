import 'package:flutter_test/flutter_test.dart';
import 'package:servershot/main.dart';

void main() {
  testWidgets('App launches and shows splash', (WidgetTester tester) async {
    await tester.pumpWidget(const ServerShotApp());

    // Pump one frame to trigger animation
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ServerShot'), findsOneWidget);
    expect(find.text('Deploy your stack anywhere'), findsOneWidget);

    // Pump past the 2-second splash delay to trigger navigation
    await tester.pump(const Duration(seconds: 3));

    // Pump the transition animation
    await tester.pump(const Duration(milliseconds: 500));

    // Should now be on HomeScreen
    expect(find.text('Deploy your stack anywhere'), findsWidgets);
  });
}
