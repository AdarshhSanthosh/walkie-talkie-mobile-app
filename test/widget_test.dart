// Basic smoke test: the app boots to the splash screen without throwing.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:walkie_talkie/app/app.dart';

void main() {
  setUpAll(() async {
    // supabase_flutter persists the session via shared_preferences; give it
    // a mocked backend so it doesn't hit a real platform channel in tests.
    SharedPreferences.setMockInitialValues({});
    // Dummy project: enough for AuthService to construct without a real
    // network call (no request is made until sign-in/sign-up is invoked).
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('App boots to splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WalkieTalkieApp()));
    await tester.pump();

    expect(find.text('Walkie Talkie'), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);

    // Let the splash screen's redirect timer fire before the test ends.
    await tester.pump(const Duration(seconds: 1));
  });
}
