import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories.dart';
import '../domain/models.dart';
import '../features/admin/admin_panel_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/child/child_home_screen.dart';
import '../features/parent/parent_dashboard_screen.dart';
import '../shared/widgets.dart';
import 'firebase_providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const AuthGate()),
      GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
      GoRoute(path: '/child', builder: (_, _) => const ChildHomeScreen()),
      GoRoute(path: '/parent', builder: (_, _) => const ParentDashboardScreen()),
      GoRoute(path: '/admin', builder: (_, _) => const AdminPanelScreen()),
    ],
  );
});

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => const FullScreenLoader(label: 'Checking your account'),
      error: (error, _) => ErrorPanel(message: '$error'),
      data: (firebaseUser) {
        if (firebaseUser == null) return const AuthScreen();
        return _ProfileGate(user: firebaseUser);
      },
    );
  }
}

class _ProfileGate extends ConsumerWidget {
  const _ProfileGate({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProvider(user.uid));
    return profile.when(
      loading: () => const FullScreenLoader(label: 'Loading your dashboard'),
      error: (error, _) => ErrorPanel(message: '$error'),
      data: (appUser) {
        if (appUser == null) return const AuthScreen(registrationOnly: true);
        if (appUser.status == AccountStatus.banned ||
            appUser.status == AccountStatus.deleted) {
          return const BlockedAccountScreen(
            title: 'Account unavailable',
            message: 'A parent or admin must review this account.',
          );
        }
        return switch (appUser.role) {
          UserRole.child => const ChildHomeScreen(),
          UserRole.parent => const ParentDashboardScreen(),
          UserRole.admin => const AdminPanelScreen(),
        };
      },
    );
  }
}

final currentUserProvider = StreamProvider.family<AppUser?, String>((ref, uid) {
  return ref.watch(userRepositoryProvider).watchCurrentUser(uid);
});
