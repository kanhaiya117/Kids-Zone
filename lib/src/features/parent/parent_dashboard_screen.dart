import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories.dart';
import '../../domain/models.dart';
import '../../shared/widgets.dart';

final parentChildrenProvider = StreamProvider.family<List<ChildProfile>, String>((ref, parentId) {
  return ref.watch(userRepositoryProvider).watchChildrenForParent(parentId);
});

final approvalRequestsProvider =
    StreamProvider.family<List<dynamic>, String>((ref, parentId) {
  return ref.watch(userRepositoryProvider).watchApprovals(parentId);
});

class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final parentId = FirebaseAuth.instance.currentUser?.uid;
    if (parentId == null) return const ErrorPanel(message: 'Not signed in.');
    return Scaffold(
      appBar: AppBar(
        title: const KidsZoneLogo(compact: true),
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
          ParentApprovalsTab(parentId: parentId),
          ParentChildrenTab(parentId: parentId),
          ParentReportsTab(parentId: parentId),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.verified_user_outlined), label: 'Approvals'),
          NavigationDestination(icon: Icon(Icons.family_restroom), label: 'Children'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), label: 'Reports'),
        ],
      ),
    );
  }
}

class ParentApprovalsTab extends ConsumerWidget {
  const ParentApprovalsTab({super.key, required this.parentId});

  final String parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvals = ref.watch(approvalRequestsProvider(parentId));
    return approvals.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorPanel(message: '$error'),
      data: (requests) => ListView(
        children: [
          const SectionHeader(title: 'Pending child approvals'),
          if (requests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No pending approval requests.'),
            ),
          for (final request in requests)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.child_care),
                title: Text(request.data()['childName'] as String? ?? 'Child'),
                subtitle: Text('Child ID: ${request.data()['childId']}'),
                trailing: FilledButton.tonalIcon(
                  onPressed: () => ref.read(userRepositoryProvider).approveChild(
                        request.id as String,
                        parentId,
                        request.data()['childId'] as String,
                      ),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ParentChildrenTab extends ConsumerWidget {
  const ParentChildrenTab({super.key, required this.parentId});

  final String parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(parentChildrenProvider(parentId));
    return children.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorPanel(message: '$error'),
      data: (items) => ListView(
        children: [
          const SectionHeader(title: 'Managed children'),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Share your parent invite code with your child account.'),
            ),
          for (final child in items)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.child_care),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Child age ${child.age}', style: Theme.of(context).textTheme.titleMedium)),
                        Switch(
                          value: child.chatEnabled,
                          onChanged: (enabled) => ref.read(userRepositoryProvider).updateChildPermissions(
                                childId: child.id,
                                chatEnabled: enabled,
                                policy: const SafetyPolicy(),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: StatTile(label: 'Good', value: '${child.goodScore}', icon: Icons.thumb_up_outlined)),
                        const SizedBox(width: 8),
                        Expanded(child: StatTile(label: 'Bad', value: '${child.badScore}', icon: Icons.warning_outlined)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => ref.read(userRepositoryProvider).grantReward(
                                  parentId: parentId,
                                  childId: child.id,
                                  points: 10,
                                  note: 'Parent reward',
                                ),
                            icon: const Icon(Icons.card_giftcard),
                            label: const Text('Reward +10'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _overrideLock(ref, child.id, child.chatEnabled),
                            icon: const Icon(Icons.lock_open),
                            label: const Text('Override'),
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

  Future<void> _overrideLock(WidgetRef ref, String childId, bool chatEnabled) {
    return ref.read(userRepositoryProvider).updateChildPermissions(
          childId: childId,
          chatEnabled: chatEnabled,
          policy: SafetyPolicy(parentOverrideUntil: DateTime.now().add(const Duration(minutes: 15))),
        );
  }
}

class ParentReportsTab extends ConsumerWidget {
  const ParentReportsTab({super.key, required this.parentId});

  final String parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(parentChildrenProvider(parentId));
    return children.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorPanel(message: '$error'),
      data: (items) => ListView(
        children: [
          const SectionHeader(title: 'Daily activity reports'),
          for (final child in items)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.summarize_outlined),
                title: Text('Child ${child.id.substring(0, 6)}'),
                subtitle: Text('Health ${child.health}. Chat ${child.chatEnabled ? 'enabled' : 'disabled'}.'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
        ],
      ),
    );
  }
}
