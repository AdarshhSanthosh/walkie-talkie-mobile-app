import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/channels/channel_screen.dart';
import '../features/channels/create_channel_screen.dart';
import '../features/home/home_shell.dart';

/// App routes (spec §11 main user flow: Login → Home → Channel → Talk).
final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
    GoRoute(
      path: '/create-channel',
      builder: (context, state) => const CreateChannelScreen(),
    ),
    GoRoute(
      path: '/channel/:id',
      builder: (context, state) => ChannelScreen(channelId: state.pathParameters['id']!),
    ),
  ],
);
