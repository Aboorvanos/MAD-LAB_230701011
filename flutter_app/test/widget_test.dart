import 'package:flutter_test/flutter_test.dart';
import 'package:fatigue_dashboard/main.dart';

void main() {
  testWidgets('App smoke test - renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FatigueDashboardApp());
    await tester.pumpAndSettle();

    // Verify login screen is shown
    expect(find.text('Fatigue Monitor'), findsWidgets);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
