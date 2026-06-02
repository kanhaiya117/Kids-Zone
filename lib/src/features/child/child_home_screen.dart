import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/repositories.dart';
import '../../domain/models.dart';
import '../../shared/widgets.dart';
import '../education/education_screen.dart';
import '../feed/feed_screen.dart';
import '../screen_time/screen_time_controller.dart';

final currentChildProvider = StreamProvider<ChildProfile?>((ref) {
  final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(firestoreProvider).collection('children').doc(uid).snapshots().map((doc) {
    if (!doc.exists) return null;
    return ChildProfile.fromDoc(doc);
  });
});

class ChildHomeScreen extends ConsumerStatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  ConsumerState<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends ConsumerState<ChildHomeScreen> {
  int _tab = 0;
  Timer? _heartbeatTimer;
  String? _heartbeatChildId;

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(currentChildProvider);
    return child.when(
      loading: () => const FullScreenLoader(label: 'Loading child profile'),
      error: (error, _) => ErrorPanel(message: '$error'),
      data: (profile) {
        if (profile == null) {
          return const BlockedAccountScreen(
            title: 'Profile missing',
            message: 'Please complete registration again.',
          );
        }
        if (profile.requiresParentApproval) {
          return PendingApprovalScreen(profile: profile);
        }
        if (profile.status == AccountStatus.suspended) {
          return const BlockedAccountScreen(
            title: 'Account paused',
            message: 'A parent or admin can reactivate this account after review.',
          );
        }
        final policy = SafetyPolicy.fromMap(null);
        _startHeartbeat(profile.id, policy);
        final screenTime = ref.watch(childScreenTimeProvider(profile.id));
        return screenTime.when(
          loading: () => const FullScreenLoader(label: 'Checking screen time'),
          error: (error, _) => ErrorPanel(message: '$error'),
          data: (state) {
            if (state.isLocked) {
              return ScreenTimeLockScreen(childId: profile.id, state: state, policy: policy);
            }
            return Scaffold(
              appBar: AppBar(
                title: const Text('KidsZone'),
                actions: [
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
              body: IndexedStack(
                index: _tab,
                children: [
                  FeedScreen(child: profile),
                  EducationScreen(childId: profile.id),
                  ChildScoresScreen(profile: profile),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (index) => setState(() => _tab = index),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.dynamic_feed_outlined), label: 'Feed'),
                  NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Learn'),
                  NavigationDestination(icon: Icon(Icons.stars_outlined), label: 'Score'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _startHeartbeat(String childId, SafetyPolicy policy) {
    if (_heartbeatChildId == childId) return;
    _heartbeatChildId = childId;
    _heartbeatTimer?.cancel();
    ref.read(screenTimeRepositoryProvider).heartbeat(childId: childId, policy: policy);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      ref.read(screenTimeRepositoryProvider).heartbeat(childId: childId, policy: policy);
    });
  }
}

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key, required this.profile});

  final ChildProfile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KidsZone')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.family_restroom, size: 48),
                  const SizedBox(height: 12),
                  Text('Parent approval needed', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'Your account is safe and waiting for your parent to approve it.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
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

class ScreenTimeLockScreen extends ConsumerWidget {
  const ScreenTimeLockScreen({
    super.key,
    required this.childId,
    required this.state,
    required this.policy,
  });

  final String childId;
  final ScreenTimeState state;
  final SafetyPolicy policy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = state.lockedUntil?.difference(DateTime.now()) ?? policy.breakDuration;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_off_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text('Break time', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Come back in ${remaining.inMinutes.clamp(0, 99)} minute(s).',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: state.extensionUsed
                        ? null
                        : () => ref.read(screenTimeRepositoryProvider).useExtension(childId, policy),
                    icon: const Icon(Icons.add_alarm_outlined),
                    label: const Text('Use 5 minute extension'),
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

class ChildScoresScreen extends StatelessWidget {
  const ChildScoresScreen({super.key, required this.profile});

  final ChildProfile profile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: StatTile(label: 'Good score', value: '${profile.goodScore}', icon: Icons.thumb_up_alt_outlined)),
            const SizedBox(width: 8),
            Expanded(child: StatTile(label: 'Bad score', value: '${profile.badScore}', icon: Icons.warning_amber_outlined)),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Safety health', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: ((profile.health + 100) / 200).clamp(0, 1)),
                const SizedBox(height: 8),
                Text('Keep learning, creating, and being kind to grow your score.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
