# KidsZone

KidsZone is a Flutter Android app for a child-safe educational social platform with parent approval, moderated content, screen-time controls, rewards, and admin review tools.

## Stack

- Flutter 3.44.1 / Dart 3.12.1
- Riverpod
- Firebase Authentication with mobile OTP
- Cloud Firestore
- Firebase Storage
- Firebase Cloud Messaging
- Material 3

## Project Structure

```text
lib/
  main.dart
  src/
    app.dart
    core/
      firebase_providers.dart
      router.dart
      theme.dart
    data/
      repositories.dart
    domain/
      models.dart
    features/
      admin/
      auth/
      child/
      education/
      feed/
      parent/
      screen_time/
    shared/
      widgets.dart
firestore.rules
firestore.indexes.json
storage.rules
firebase.json
```

## Firebase Setup

1. Create a Firebase project.
2. Enable Phone Authentication, Firestore, Storage, and FCM.
3. Download `google-services.json`.
4. Place it at `android/app/google-services.json`.
5. Deploy rules:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage:rules
```

## Firestore Collections

- `users`
- `parents`
- `children`
- `approvalRequests`
- `posts`
- `posts/{postId}/likes`
- `posts/{postId}/comments`
- `education`
- `screenTime`
- `moderationQueue`
- `moderationLogs`
- `rewards`
- `activityLogs`
- `auditLogs`

## Safety Notes

The Flutter client performs local fail-closed checks and writes all risky media/text into `moderationQueue`. Real AI moderation for images, videos, and high-stakes text decisions must run in a trusted Firebase Cloud Function or backend worker, because mobile-only AI moderation can be bypassed by a modified client.

## Verification

```bash
flutter analyze
flutter test
flutter build apk --debug
```

The local workspace passed `flutter analyze` and `flutter test`. Android build requires an installed Android SDK and `ANDROID_HOME`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
