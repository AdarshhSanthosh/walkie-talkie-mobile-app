import 'package:flutter/material.dart';

/// Shown instead of the real app when Supabase credentials haven't been
/// supplied yet — see README "Running it" for the exact steps.
class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_suggest_outlined, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'Supabase isn\'t configured',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Copy env.example.json to env.json\n'
                    '2. Fill in your Supabase project URL + anon key\n'
                    '3. Run: flutter run --dart-define-from-file=env.json\n\n'
                    'See README.md for full setup steps.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
