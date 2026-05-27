import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/app/app.dart';

void main() {
  testWidgets('Login screen loads successfully',
      (WidgetTester tester) async {

    // Load app
    await tester.pumpWidget(
      const SolarSalesApp(),
    );

    // Check welcome text
    expect(find.text('Welcome Back'), findsOneWidget);

    // Check sign in button
    expect(find.text('Sign in'), findsOneWidget);
  });
}