import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../domain/models.dart';
import '../../shared/widgets.dart';

final adminUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.map(AppUser.fromDoc).toList());
});

final reviewQueueProvider = StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('moderationQueue')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs);
});

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
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
        children: const [
          AdminUsersTab(),
          AdminReviewTab(),
          AdminSafetyTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: 'Review'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Safety'),
        ],
      ),
    );
  }
}

class AdminUsersTab extends ConsumerWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);
    return users.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorPanel(message: '$error'),
      data: (items) => ListView(
        children: [
          const SectionHeader(title: 'User management'),
          for (final user in items)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: Icon(_roleIcon(user.role)),
                title: Text(user.displayName),
                subtitle: Text('${user.role.name} • ${user.status.name}'),
                trailing: PopupMenuButton<AccountStatus>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (status) => ref.read(firestoreProvider).collection('users').doc(user.id).update({
                    'status': status.name,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: AccountStatus.active, child: Text('Activate')),
                    PopupMenuItem(value: AccountStatus.suspended, child: Text('Suspend')),
                    PopupMenuItem(value: AccountStatus.banned, child: Text('Ban')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _roleIcon(UserRole role) {
    return switch (role) {
      UserRole.child => Icons.child_care,
      UserRole.parent => Icons.family_restroom,
      UserRole.admin => Icons.admin_panel_settings,
    };
  }
}

class AdminReviewTab extends ConsumerWidget {
  const AdminReviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(reviewQueueProvider);
    return queue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorPanel(message: '$error'),
      data: (items) => ListView(
        children: [
          const SectionHeader(title: 'Flagged content review'),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No flagged content waiting for review.'),
            ),
          for (final item in items)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.data()['targetType'] as String? ?? 'content', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text('Status: ${item.data()['status'] ?? 'queued'}'),
                    if (item.data()['text'] != null) Text(item.data()['text'] as String),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _decide(ref, item, ContentStatus.approved),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _decide(ref, item, ContentStatus.rejected),
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _decide(
    WidgetRef ref,
    QueryDocumentSnapshot<Map<String, dynamic>> item,
    ContentStatus status,
  ) async {
    final db = ref.read(firestoreProvider);
    final data = item.data();
    final targetType = data['targetType'] as String?;
    final targetId = data['targetId'] as String?;
    if (targetType == 'post' && targetId != null) {
      await db.collection('posts').doc(targetId).update({
        'status': status.name,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    }
    await item.reference.update({
      'status': status == ContentStatus.approved ? 'approved' : 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }
}

class AdminSafetyTab extends ConsumerWidget {
  const AdminSafetyTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: const [
        SectionHeader(title: 'Safety controls'),
        Padding(
          padding: EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Production safety settings live in Firestore featureToggles, moderationRules, and rewardRules collections. Security rules should restrict writes to admins only.',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
