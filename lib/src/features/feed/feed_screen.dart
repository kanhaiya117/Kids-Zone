import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories.dart';
import '../../domain/models.dart';
import '../../shared/widgets.dart';

final approvedFeedProvider = StreamProvider<List<KidPost>>((ref) {
  return ref.watch(contentRepositoryProvider).watchApprovedFeed();
});

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key, required this.child});

  final ChildProfile child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(approvedFeedProvider);
    return Scaffold(
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorPanel(message: '$error'),
        data: (posts) => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            const SectionHeader(title: 'Child-safe feed'),
            if (posts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No approved posts yet. Create something kind and clever.'),
              ),
            for (final post in posts) PostCard(post: post, childId: child.id),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => CreatePostSheet(child: child),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
    );
  }
}

class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, required this.childId});

  final KidPost post;
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person_outline)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.authorName, style: Theme.of(context).textTheme.titleSmall),
                      Text(post.type.name, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.title, style: Theme.of(context).textTheme.titleMedium),
            if (post.body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(post.body),
            ],
            if (post.mediaUrl != null && post.type != ContentType.video) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(post.mediaUrl!, height: 220, width: double.infinity, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  tooltip: 'Like',
                  onPressed: () => ref.read(contentRepositoryProvider).likePost(post.id, childId),
                  icon: const Icon(Icons.favorite_border),
                ),
                Text('${post.likeCount}'),
                const SizedBox(width: 16),
                const Icon(Icons.mode_comment_outlined, size: 20),
                const SizedBox(width: 4),
                Text('${post.commentCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CreatePostSheet extends ConsumerStatefulWidget {
  const CreatePostSheet({super.key, required this.child});

  final ChildProfile child;

  @override
  ConsumerState<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<CreatePostSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _picker = ImagePicker();
  ContentType _type = ContentType.poetry;
  File? _file;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Create moderated post', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<ContentType>(
              segments: const [
                ButtonSegment(value: ContentType.poetry, icon: Icon(Icons.edit_note), label: Text('Poem')),
                ButtonSegment(value: ContentType.photo, icon: Icon(Icons.photo), label: Text('Photo')),
                ButtonSegment(value: ContentType.drawing, icon: Icon(Icons.brush), label: Text('Art')),
                ButtonSegment(value: ContentType.video, icon: Icon(Icons.videocam), label: Text('Video')),
              ],
              selected: {_type},
              onSelectionChanged: (value) => setState(() {
                _type = value.first;
                _file = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description or poem',
                prefixIcon: Icon(Icons.edit_note),
              ),
            ),
            if (_type != ContentType.poetry) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickMedia,
                icon: Icon(_type == ContentType.video ? Icons.video_library : Icons.image),
                label: Text(_file == null ? 'Pick ${_type.name}' : 'Change file'),
              ),
            ],
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Submit for moderation'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMedia() async {
    final picked = _type == ContentType.video
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _file = File(picked.path));
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.length < 3 || title.length > 80) {
      setState(() {
        _error = 'Title must be 3 to 80 characters.';
      });
      return;
    }
    if (body.length > 1000) {
      setState(() {
        _error = 'Description must be 1000 characters or less.';
      });
      return;
    }
    if (_type == ContentType.poetry && body.length < 3) {
      setState(() {
        _error = 'Poetry needs at least 3 characters.';
      });
      return;
    }
    if (_type != ContentType.poetry && _file == null) {
      setState(() {
        _error = 'Pick a ${_type.name} file before submitting.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(contentRepositoryProvider).createPost(
            childId: widget.child.id,
            authorName: 'Kid',
            title: title,
            body: body,
            type: _type,
            mediaFile: _file,
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
