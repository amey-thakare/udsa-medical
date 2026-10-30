import 'package:flutter_test/flutter_test.dart';
import 'package:medrecord/main.dart';

void main() {
  testWidgets('App should render MedRecordApp', (WidgetTester tester) async {
    await tester.pumpWidget(const MedRecordApp());
    await tester.pump();
    // Splash screen should show the app name
    expect(find.text('MyHealthMitra'), findsOneWidget);
  });
}
