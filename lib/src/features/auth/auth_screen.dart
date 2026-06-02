import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories.dart';
import '../../domain/models.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.registrationOnly = false});

  final bool registrationOnly;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _invite = TextEditingController();
  final _age = TextEditingController(text: '8');
  UserRole _role = UserRole.child;
  String? _verificationId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    _invite.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = FirebaseAuth.instance.currentUser != null;
    return Scaffold(
      appBar: AppBar(title: const Text('KidsZone')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              signedIn ? 'Complete profile' : 'Mobile OTP login',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'A protected learning and sharing space with parent approval.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            if (!signedIn) ...[
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  hintText: '+911234567890',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _requestOtp,
                icon: const Icon(Icons.sms_outlined),
                label: const Text('Send OTP'),
              ),
              if (_verificationId != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'OTP code',
                    prefixIcon: Icon(Icons.password),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _verifyOtp,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Verify and continue'),
                ),
              ],
            ] else ...[
              SegmentedButton<UserRole>(
                segments: const [
                  ButtonSegment(value: UserRole.child, label: Text('Child'), icon: Icon(Icons.child_care)),
                  ButtonSegment(value: UserRole.parent, label: Text('Parent'), icon: Icon(Icons.family_restroom)),
                  ButtonSegment(value: UserRole.admin, label: Text('Admin'), icon: Icon(Icons.admin_panel_settings)),
                ],
                selected: {_role},
                onSelectionChanged: (value) => setState(() => _role = value.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              if (_role == UserRole.child) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _invite,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Parent invite code',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _completeProfile,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Create profile'),
              ),
            ],
            if (_busy) const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    await ref.read(authRepositoryProvider).requestMobileOtp(
          phone: _phone.text.trim(),
          onCodeSent: (id) => setState(() => _verificationId = id),
          onFailed: (error) => setState(() => _error = error.message),
        );
    setState(() => _busy = false);
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyOtp(
            verificationId: _verificationId!,
            smsCode: _code.text.trim(),
          );
    } catch (error) {
      _error = '$error';
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _completeProfile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).completeRegistration(
            role: _role,
            displayName: _name.text,
            childAge: int.tryParse(_age.text),
            parentInviteCode: _role == UserRole.child ? _invite.text : null,
          );
    } catch (error) {
      _error = '$error';
    } finally {
      setState(() => _busy = false);
    }
  }
}
