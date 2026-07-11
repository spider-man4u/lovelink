import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../splash/presentation/splash_screen.dart';
import '../../auth/presentation/login_screen.dart';
import '../../chat/presentation/chat_list_screen.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../memory/presentation/timeline_screen.dart';
import '../../settings/presentation/settings_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/splash';

      if (!isLoggedIn && !isAuthRoute) return '/splash';
      if (isLoggedIn && isAuthRoute) return '/chats';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/chats',
        builder: (context, state) => const ChatListScreen(),
        routes: [
          GoRoute(
            path: ':conversationId',
            builder: (context, state) => ChatScreen(
              conversationId: state.pathParameters['conversationId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/timeline',
        builder: (context, state) => const TimelineScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});
