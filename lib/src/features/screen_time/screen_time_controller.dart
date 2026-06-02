import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories.dart';
import '../../domain/models.dart';

final childScreenTimeProvider =
    StreamProvider.family<ScreenTimeState, String>((ref, childId) {
  return ref.watch(screenTimeRepositoryProvider).watchState(childId);
});
