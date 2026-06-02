import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories.dart';
import '../../domain/models.dart';
import '../../shared/widgets.dart';

final educationItemsProvider = StreamProvider<List<EducationItem>>((ref) {
  return ref.watch(educationRepositoryProvider).watchDailyItems();
});

class EducationScreen extends ConsumerWidget {
  const EducationScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(educationItemsProvider);
    return items.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorPanel(message: '$error'),
      data: (data) => ListView(
        children: [
          const SectionHeader(title: 'Daily learning'),
          if (data.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Admins can publish GK, tech news, quizzes, tips, and jokes here.'),
            ),
          for (final item in data)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: Icon(_iconFor(item.category)),
                title: Text(item.title),
                subtitle: Text(item.body),
                trailing: item.category == 'quiz'
                    ? IconButton(
                        tooltip: 'Complete quiz',
                        onPressed: () => ref.read(educationRepositoryProvider).completeQuiz(
                              childId: childId,
                              quizId: item.id,
                              score: 100,
                            ),
                        icon: const Icon(Icons.check_circle_outline),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(String category) {
    return switch (category) {
      'quiz' => Icons.quiz_outlined,
      'tech' => Icons.memory_outlined,
      'joke' => Icons.sentiment_very_satisfied,
      'tip' => Icons.lightbulb_outline,
      _ => Icons.public,
    };
  }
}
