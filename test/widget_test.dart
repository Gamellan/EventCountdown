import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:event_countdown/main.dart';

void main() {
  testWidgets('Shows empty state when there are no events', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const EventCountdownApp());
    await tester.pumpAndSettle();

    expect(find.text('Event Countdown'), findsOneWidget);
    expect(find.text('Start your first countdown'), findsOneWidget);
    expect(find.text('Add Event'), findsOneWidget);
  });
}
