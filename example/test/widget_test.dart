import 'package:flutter_test/flutter_test.dart';
import 'package:soap_dart_example/main.dart';

void main() {
  testWidgets('calls generated SOAP calculator client', (tester) async {
    await tester.pumpWidget(const SoapDartExampleApp());

    expect(find.text('No request sent'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add result: 9'), findsOneWidget);
    expect(find.textContaining('<Add'), findsOneWidget);
    expect(find.textContaining('<a>4</a>'), findsOneWidget);
    expect(find.textContaining('<b>5</b>'), findsOneWidget);
  });
}
