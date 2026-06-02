import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { child, parent, admin }
enum AccountStatus { pending, active, suspended, banned, deleted }
enum ContentStatus { pending, approved, flagged, rejected }
enum ContentType { photo, video, drawing, poetry }
enum ModerationDecision { approved, flagged, rejected }
enum ScreenTimePhase { active, breakRequired, locked, extensionUsed, parentOverride }

T enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  return values.cast<T?>().firstWhere(
        (value) => value?.name == name,
        orElse: () => fallback,
      ) ??
      fallback;
}

DateTime readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.status,
    required this.displayName,
    this.phone,
    this.avatarUrl,
    required this.createdAt,
  });

  final String id;
  final UserRole role;
  final AccountStatus status;
  final String displayName;
  final String? phone;
  final String? avatarUrl;
  final DateTime createdAt;

  bool get isActive => status == AccountStatus.active;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      id: doc.id,
      role: enumFromName(UserRole.values, data['role'] as String?, UserRole.child),
      status: enumFromName(
        AccountStatus.values,
        data['status'] as String?,
        AccountStatus.pending,
      ),
      displayName: data['displayName'] as String? ?? 'Kid',
      phone: data['phone'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      createdAt: readDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'role': role.name,
        'status': status.name,
        'displayName': displayName,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.userId,
    required this.parentIds,
    required this.age,
    required this.status,
    required this.chatEnabled,
    required this.goodScore,
    required this.badScore,
    this.suspendedUntil,
  });

  final String id;
  final String userId;
  final List<String> parentIds;
  final int age;
  final AccountStatus status;
  final bool chatEnabled;
  final int goodScore;
  final int badScore;
  final DateTime? suspendedUntil;

  int get health => goodScore - badScore;
  bool get requiresParentApproval => status == AccountStatus.pending;

  factory ChildProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ChildProfile(
      id: doc.id,
      userId: data['userId'] as String? ?? doc.id,
      parentIds: List<String>.from(data['parentIds'] as List? ?? const []),
      age: (data['age'] as num?)?.toInt() ?? 5,
      status: enumFromName(
        AccountStatus.values,
        data['status'] as String?,
        AccountStatus.pending,
      ),
      chatEnabled: data['chatEnabled'] as bool? ?? false,
      goodScore: (data['goodScore'] as num?)?.toInt() ?? 0,
      badScore: (data['badScore'] as num?)?.toInt() ?? 0,
      suspendedUntil:
          data['suspendedUntil'] == null ? null : readDate(data['suspendedUntil']),
    );
  }
}

class SafetyPolicy {
  const SafetyPolicy({
    this.continuousLimit = const Duration(minutes: 15),
    this.breakDuration = const Duration(minutes: 2),
    this.extensionDuration = const Duration(minutes: 5),
    this.dailyLimit = const Duration(minutes: 60),
    this.parentOverrideUntil,
    this.extensionUsedDate,
  });

  final Duration continuousLimit;
  final Duration breakDuration;
  final Duration extensionDuration;
  final Duration dailyLimit;
  final DateTime? parentOverrideUntil;
  final DateTime? extensionUsedDate;

  factory SafetyPolicy.fromMap(Map<String, dynamic>? data) {
    data ??= const {};
    return SafetyPolicy(
      continuousLimit: Duration(minutes: (data['continuousLimitMinutes'] as num?)?.toInt() ?? 15),
      breakDuration: Duration(minutes: (data['breakDurationMinutes'] as num?)?.toInt() ?? 2),
      extensionDuration: Duration(minutes: (data['extensionDurationMinutes'] as num?)?.toInt() ?? 5),
      dailyLimit: Duration(minutes: (data['dailyLimitMinutes'] as num?)?.toInt() ?? 60),
      parentOverrideUntil:
          data['parentOverrideUntil'] == null ? null : readDate(data['parentOverrideUntil']),
      extensionUsedDate:
          data['extensionUsedDate'] == null ? null : readDate(data['extensionUsedDate']),
    );
  }

  Map<String, dynamic> toMap() => {
        'continuousLimitMinutes': continuousLimit.inMinutes,
        'breakDurationMinutes': breakDuration.inMinutes,
        'extensionDurationMinutes': extensionDuration.inMinutes,
        'dailyLimitMinutes': dailyLimit.inMinutes,
        'parentOverrideUntil':
            parentOverrideUntil == null ? null : Timestamp.fromDate(parentOverrideUntil!),
        'extensionUsedDate':
            extensionUsedDate == null ? null : Timestamp.fromDate(extensionUsedDate!),
      };
}

class ScreenTimeState {
  const ScreenTimeState({
    required this.childId,
    required this.phase,
    required this.sessionStartedAt,
    required this.lastHeartbeatAt,
    required this.dailyUsed,
    required this.extensionUsed,
    this.lockedUntil,
  });

  final String childId;
  final ScreenTimePhase phase;
  final DateTime sessionStartedAt;
  final DateTime lastHeartbeatAt;
  final Duration dailyUsed;
  final bool extensionUsed;
  final DateTime? lockedUntil;

  bool get isLocked =>
      phase == ScreenTimePhase.locked || phase == ScreenTimePhase.breakRequired;

  factory ScreenTimeState.initial(String childId) {
    final now = DateTime.now();
    return ScreenTimeState(
      childId: childId,
      phase: ScreenTimePhase.active,
      sessionStartedAt: now,
      lastHeartbeatAt: now,
      dailyUsed: Duration.zero,
      extensionUsed: false,
    );
  }

  factory ScreenTimeState.fromDoc(String childId, Map<String, dynamic>? data) {
    if (data == null) return ScreenTimeState.initial(childId);
    return ScreenTimeState(
      childId: childId,
      phase: enumFromName(
        ScreenTimePhase.values,
        data['phase'] as String?,
        ScreenTimePhase.active,
      ),
      sessionStartedAt: readDate(data['sessionStartedAt']),
      lastHeartbeatAt: readDate(data['lastHeartbeatAt']),
      dailyUsed: Duration(seconds: (data['dailyUsedSeconds'] as num?)?.toInt() ?? 0),
      extensionUsed: data['extensionUsed'] as bool? ?? false,
      lockedUntil: data['lockedUntil'] == null ? null : readDate(data['lockedUntil']),
    );
  }

  Map<String, dynamic> toMap() => {
        'phase': phase.name,
        'sessionStartedAt': Timestamp.fromDate(sessionStartedAt),
        'lastHeartbeatAt': Timestamp.fromDate(lastHeartbeatAt),
        'dailyUsedSeconds': dailyUsed.inSeconds,
        'extensionUsed': extensionUsed,
        'lockedUntil': lockedUntil == null ? null : Timestamp.fromDate(lockedUntil!),
      };
}

class KidPost {
  const KidPost({
    required this.id,
    required this.childId,
    required this.authorName,
    required this.title,
    required this.body,
    required this.type,
    required this.status,
    required this.createdAt,
    this.mediaUrl,
    this.moderationScore = 0,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  final String id;
  final String childId;
  final String authorName;
  final String title;
  final String body;
  final ContentType type;
  final ContentStatus status;
  final DateTime createdAt;
  final String? mediaUrl;
  final int moderationScore;
  final int likeCount;
  final int commentCount;

  factory KidPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return KidPost(
      id: doc.id,
      childId: data['childId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Friend',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: enumFromName(ContentType.values, data['type'] as String?, ContentType.poetry),
      status: enumFromName(
        ContentStatus.values,
        data['status'] as String?,
        ContentStatus.pending,
      ),
      createdAt: readDate(data['createdAt']),
      mediaUrl: data['mediaUrl'] as String?,
      moderationScore: (data['moderationScore'] as num?)?.toInt() ?? 0,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class EducationItem {
  const EducationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final DateTime createdAt;

  factory EducationItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return EducationItem(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      category: data['category'] as String? ?? 'general',
      createdAt: readDate(data['createdAt']),
    );
  }
}

class DailyReport {
  const DailyReport({
    required this.childId,
    required this.date,
    required this.minutesUsed,
    required this.postsCreated,
    required this.quizzesCompleted,
    required this.flags,
    required this.goodScore,
    required this.badScore,
  });

  final String childId;
  final DateTime date;
  final int minutesUsed;
  final int postsCreated;
  final int quizzesCompleted;
  final int flags;
  final int goodScore;
  final int badScore;
}
