import 'package:flutter_test/flutter_test.dart';
import 'package:tincan/src/app.dart';

void main() {
  testWidgets('boots to the onboarding screen', (tester) async {
    await tester.pumpWidget(const TincanApp());

    // The onboarding screen offers to create a new identity or restore one.
    expect(find.text('Generate recovery phrase'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
  });
}
