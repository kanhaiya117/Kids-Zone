import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

import '../core/firebase_providers.dart';
import '../domain/models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(firebaseMessagingProvider),
  );
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(firestoreProvider));
});

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
    ref.watch(moderationRepositoryProvider),
  );
});

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepository(ref.watch(firestoreProvider));
});

final screenTimeRepositoryProvider = Provider<ScreenTimeRepository>((ref) {
  return ScreenTimeRepository(ref.watch(firestoreProvider));
});

final educationRepositoryProvider = Provider<EducationRepository>((ref) {
  return EducationRepository(ref.watch(firestoreProvider));
});

class AuthRepository {
  AuthRepository(this._auth, this._firestore, this._messaging);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  Future<void> requestMobileOtp({
    required String phone,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException error) onFailed,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: onFailed,
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<void> completeRegistration({
    required UserRole role,
    required String displayName,
    required int? childAge,
    required String? parentInviteCode,
  }) async {
    final cleanName = displayName.trim();
    final cleanInvite = parentInviteCode?.trim().toUpperCase();
    if (cleanName.length < 2 || cleanName.length > 40) {
      throw ArgumentError('Display name must be 2 to 40 characters.');
    }
    if (role == UserRole.child && (childAge == null || childAge < 5 || childAge > 15)) {
      throw ArgumentError('Child age must be between 5 and 15.');
    }
    if (role == UserRole.child && (cleanInvite == null || cleanInvite.isEmpty)) {
      throw ArgumentError('Parent invite code is required for child accounts.');
    }
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in Firebase user.');
    final token = await _messaging.getToken();
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(user.uid);
    final status = role == UserRole.child ? AccountStatus.pending : AccountStatus.active;

    batch.set(userRef, {
      'role': role.name,
      'status': status.name,
      'displayName': cleanName,
      'phone': user.phoneNumber,
      'fcmTokens': token == null ? [] : FieldValue.arrayUnion([token]),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (role == UserRole.parent) {
      batch.set(_firestore.collection('parents').doc(user.uid), {
        'userId': user.uid,
        'displayName': cleanName,
        'inviteCode': user.uid.substring(0, 6).toUpperCase(),
        'verified': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (role == UserRole.child) {
      final childRef = _firestore.collection('children').doc(user.uid);
      batch.set(childRef, {
        'userId': user.uid,
        'displayName': cleanName,
        'age': childAge ?? 5,
        'status': AccountStatus.pending.name,
        'chatEnabled': false,
        'goodScore': 0,
        'badScore': 0,
        'parentIds': <String>[],
        'safetyPolicy': const SafetyPolicy().toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (cleanInvite != null && cleanInvite.isNotEmpty) {
        final parentQuery = await _firestore
            .collection('parents')
            .where('inviteCode', isEqualTo: cleanInvite)
            .limit(1)
            .get();
        if (parentQuery.docs.isEmpty) {
          throw ArgumentError('Parent invite code was not found.');
        }
        final parentId = parentQuery.docs.first.id;
        batch.set(_firestore.collection('approvalRequests').doc(), {
          'childId': user.uid,
          'parentId': parentId,
          'childName': cleanName,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  Future<void> signOut() => _auth.signOut();
}

class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<AppUser?> watchCurrentUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromDoc(doc);
    });
  }

  Stream<List<ChildProfile>> watchChildrenForParent(String parentId) {
    return _firestore
        .collection('children')
        .where('parentIds', arrayContains: parentId)
        .snapshots()
        .map((snap) => snap.docs.map(ChildProfile.fromDoc).toList());
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchApprovals(String parentId) {
    return _firestore
        .collection('approvalRequests')
        .where('parentId', isEqualTo: parentId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs);
  }

  Future<void> approveChild(String requestId, String parentId, String childId) async {
    await _firestore.runTransaction((tx) async {
      final childRef = _firestore.collection('children').doc(childId);
      final userRef = _firestore.collection('users').doc(childId);
      final requestRef = _firestore.collection('approvalRequests').doc(requestId);
      tx.update(childRef, {
        'status': AccountStatus.active.name,
        'parentIds': FieldValue.arrayUnion([parentId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(userRef, {
        'status': AccountStatus.active.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(requestRef, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });
      tx.set(_firestore.collection('auditLogs').doc(), {
        'actorUserId': parentId,
        'action': 'child.approved',
        'targetType': 'child',
        'targetId': childId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateChildPermissions({
    required String childId,
    required bool chatEnabled,
    required SafetyPolicy policy,
  }) {
    return _firestore.collection('children').doc(childId).update({
      'chatEnabled': chatEnabled,
      'safetyPolicy': policy.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> grantReward({
    required String parentId,
    required String childId,
    required int points,
    required String note,
  }) async {
    final childRef = _firestore.collection('children').doc(childId);
    await _firestore.runTransaction((tx) async {
      tx.update(childRef, {'goodScore': FieldValue.increment(points)});
      tx.set(_firestore.collection('rewards').doc(), {
        'childId': childId,
        'parentId': parentId,
        'points': points,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

class ModerationRepository {
  ModerationRepository(this._firestore);

  final FirebaseFirestore _firestore;
  static const _blockedWords = <String>{
    'hate',
    'kill',
    'stupid',
    'idiot',
    'drugs',
    'weapon',
    'nude',
    'sex',
  };

  Future<ModerationResult> moderateText({
    required String targetType,
    required String targetId,
    required String actorUserId,
    required String text,
  }) async {
    final normalized = text.toLowerCase();
    final hits = _blockedWords.where(normalized.contains).toList();
    final score = (hits.length * 25).clamp(0, 100);
    final decision = _decisionFor(score);
    await _firestore.collection('moderationLogs').add({
      'targetType': targetType,
      'targetId': targetId,
      'actorUserId': actorUserId,
      'provider': 'client_local_and_cloud_queue',
      'riskScore': score,
      'decision': decision.name,
      'reasonCodes': hits,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (decision != ModerationDecision.approved) {
      await _firestore.collection('moderationQueue').doc(targetId).set({
        'targetType': targetType,
        'targetId': targetId,
        'actorUserId': actorUserId,
        'text': text,
        'localRiskScore': score,
        'status': decision == ModerationDecision.rejected ? 'auto_rejected' : 'needs_review',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return ModerationResult(decision: decision, score: score, reasonCodes: hits);
  }

  Future<void> queueMediaModeration({
    required String targetId,
    required String targetType,
    required String actorUserId,
    required String mediaUrl,
    required String mimeType,
  }) {
    return _firestore.collection('moderationQueue').doc(targetId).set({
      'targetType': targetType,
      'targetId': targetId,
      'actorUserId': actorUserId,
      'mediaUrl': mediaUrl,
      'mimeType': mimeType,
      'status': 'needs_ai_scan',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  ModerationDecision _decisionFor(int score) {
    if (score >= 60) return ModerationDecision.rejected;
    if (score >= 25) return ModerationDecision.flagged;
    return ModerationDecision.approved;
  }
}

class ModerationResult {
  const ModerationResult({
    required this.decision,
    required this.score,
    required this.reasonCodes,
  });

  final ModerationDecision decision;
  final int score;
  final List<String> reasonCodes;
}

class ContentRepository {
  ContentRepository(this._firestore, this._storage, this._moderation);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ModerationRepository _moderation;
  final _uuid = const Uuid();

  Stream<List<KidPost>> watchApprovedFeed() {
    return _firestore
        .collection('posts')
        .where('status', isEqualTo: ContentStatus.approved.name)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(KidPost.fromDoc).toList());
  }

  Future<void> createPost({
    required String childId,
    required String authorName,
    required String title,
    required String body,
    required ContentType type,
    File? mediaFile,
  }) async {
    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    if (cleanTitle.length < 3 || cleanTitle.length > 80) {
      throw ArgumentError('Title must be 3 to 80 characters.');
    }
    if (cleanBody.length > 1000) {
      throw ArgumentError('Description must be 1000 characters or less.');
    }
    if (type == ContentType.poetry && cleanBody.length < 3) {
      throw ArgumentError('Poetry needs at least 3 characters.');
    }
    if (type != ContentType.poetry && mediaFile == null) {
      throw ArgumentError('A ${type.name} file is required.');
    }
    final postId = _uuid.v4();
    String? mediaUrl;
    String? mimeType;
    if (mediaFile != null) {
      mimeType = lookupMimeType(mediaFile.path) ?? 'application/octet-stream';
      if (!_isAllowedMime(type, mimeType)) {
        throw ArgumentError('Selected file type is not allowed for ${type.name}.');
      }
      final ref = _storage.ref('quarantine/posts/$childId/$postId');
      await ref.putFile(mediaFile, SettableMetadata(contentType: mimeType));
      mediaUrl = await ref.getDownloadURL();
    }

    final textResult = await _moderation.moderateText(
      targetType: 'post',
      targetId: postId,
      actorUserId: childId,
      text: '$cleanTitle\n$cleanBody',
    );
    final initialStatus = textResult.decision == ModerationDecision.rejected
        ? ContentStatus.rejected
        : ContentStatus.pending;

    await _firestore.collection('posts').doc(postId).set({
      'childId': childId,
      'authorName': authorName,
      'title': cleanTitle,
      'body': cleanBody,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'status': initialStatus.name,
      'moderationScore': textResult.score,
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mediaUrl != null && mimeType != null) {
      await _moderation.queueMediaModeration(
        targetId: postId,
        targetType: 'post',
        actorUserId: childId,
        mediaUrl: mediaUrl,
        mimeType: mimeType,
      );
    }
  }

  Future<void> likePost(String postId, String childId) async {
    final likeRef = _firestore.collection('posts').doc(postId).collection('likes').doc(childId);
    await _firestore.runTransaction((tx) async {
      final like = await tx.get(likeRef);
      if (like.exists) return;
      tx.set(likeRef, {'childId': childId, 'createdAt': FieldValue.serverTimestamp()});
      tx.update(_firestore.collection('posts').doc(postId), {
        'likeCount': FieldValue.increment(1),
      });
    });
  }

  Future<void> addComment({
    required String postId,
    required String childId,
    required String body,
  }) async {
    final cleanBody = body.trim();
    if (cleanBody.length < 2 || cleanBody.length > 500) {
      throw ArgumentError('Comment must be 2 to 500 characters.');
    }
    final commentRef = _firestore.collection('posts').doc(postId).collection('comments').doc();
    final result = await _moderation.moderateText(
      targetType: 'comment',
      targetId: commentRef.id,
      actorUserId: childId,
      text: cleanBody,
    );
    if (result.decision == ModerationDecision.rejected) {
      await _firestore.collection('children').doc(childId).update({
        'badScore': FieldValue.increment(10),
      });
    }
    await commentRef.set({
      'childId': childId,
      'body': cleanBody,
      'status': result.decision == ModerationDecision.approved
          ? ContentStatus.approved.name
          : ContentStatus.flagged.name,
      'moderationScore': result.score,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (result.decision == ModerationDecision.approved) {
      await _firestore.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(1),
      });
    }
  }

  bool _isAllowedMime(ContentType type, String mimeType) {
    return switch (type) {
      ContentType.photo || ContentType.drawing => mimeType.startsWith('image/'),
      ContentType.video => mimeType.startsWith('video/'),
      ContentType.poetry => true,
    };
  }
}

class ScreenTimeRepository {
  ScreenTimeRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<ScreenTimeState> watchState(String childId) {
    return _firestore.collection('screenTime').doc(childId).snapshots().map((doc) {
      return ScreenTimeState.fromDoc(childId, doc.data());
    });
  }

  Future<ScreenTimeState> heartbeat({
    required String childId,
    required SafetyPolicy policy,
  }) async {
    final ref = _firestore.collection('screenTime').doc(childId);
    late ScreenTimeState next;
    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(ref);
      final current = ScreenTimeState.fromDoc(childId, doc.data());
      final now = DateTime.now();
      final elapsed = now.difference(current.lastHeartbeatAt);
      final dailyUsed = current.dailyUsed + (elapsed.isNegative ? Duration.zero : elapsed);
      final sessionUsed = now.difference(current.sessionStartedAt);
      var phase = current.phase;
      DateTime? lockedUntil = current.lockedUntil;

      final overrideActive =
          policy.parentOverrideUntil != null && policy.parentOverrideUntil!.isAfter(now);
      if (overrideActive) {
        phase = ScreenTimePhase.parentOverride;
      } else if (current.lockedUntil != null && current.lockedUntil!.isAfter(now)) {
        phase = ScreenTimePhase.locked;
      } else if (dailyUsed >= policy.dailyLimit || sessionUsed >= policy.continuousLimit) {
        phase = ScreenTimePhase.locked;
        lockedUntil = now.add(policy.breakDuration);
      } else {
        phase = ScreenTimePhase.active;
        lockedUntil = null;
      }

      next = ScreenTimeState(
        childId: childId,
        phase: phase,
        sessionStartedAt: current.sessionStartedAt,
        lastHeartbeatAt: now,
        dailyUsed: dailyUsed,
        extensionUsed: current.extensionUsed,
        lockedUntil: lockedUntil,
      );
      tx.set(ref, next.toMap(), SetOptions(merge: true));
      tx.set(_firestore.collection('activityLogs').doc(), {
        'userId': childId,
        'childId': childId,
        'activityType': 'screen_time.heartbeat',
        'metadata': {'phase': phase.name, 'dailySeconds': dailyUsed.inSeconds},
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return next;
  }

  Future<void> useExtension(String childId, SafetyPolicy policy) async {
    final ref = _firestore.collection('screenTime').doc(childId);
    await _firestore.runTransaction((tx) async {
      final current = ScreenTimeState.fromDoc(childId, (await tx.get(ref)).data());
      if (current.extensionUsed) {
        throw StateError('Daily extension already used.');
      }
      final now = DateTime.now();
      tx.set(ref, {
        ...current.toMap(),
        'phase': ScreenTimePhase.extensionUsed.name,
        'lockedUntil': null,
        'lastHeartbeatAt': Timestamp.fromDate(now),
        'extensionUsed': true,
        'sessionStartedAt': Timestamp.fromDate(now.subtract(policy.continuousLimit).add(policy.extensionDuration)),
      }, SetOptions(merge: true));
    });
  }
}

class EducationRepository {
  EducationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<List<EducationItem>> watchDailyItems() {
    return _firestore
        .collection('education')
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(EducationItem.fromDoc).toList());
  }

  Future<void> completeQuiz({
    required String childId,
    required String quizId,
    required int score,
  }) async {
    await _firestore.runTransaction((tx) async {
      tx.set(_firestore.collection('quizAttempts').doc(), {
        'childId': childId,
        'quizId': quizId,
        'score': score,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(_firestore.collection('children').doc(childId), {
        'goodScore': FieldValue.increment(10),
      });
    });
  }
}
