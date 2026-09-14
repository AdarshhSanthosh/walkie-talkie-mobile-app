// Basic smoke test: the app boots to the splash screen without throwing.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkie_talkie/app/app.dart';

void main() {
  testWidgets('App boots to splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WalkieTalkieApp()));
    await tester.pump();

    expect(find.text('Walkie Talkie'), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);

    // Let the splash screen's redirect timer fire before the test ends.
    await tester.pump(const Duration(seconds: 1));
  });
}
