import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories.dart';
import '../../domain/models.dart';
import '../../shared/widgets.dart';

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
      appBar: AppBar(title: const KidsZoneLogo(compact: true)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 24),
              child: Center(child: KidsZoneLogo(centered: true)),
            ),
            Text(
              signedIn ? 'Complete profile' : 'Mobile OTP login',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'A protected learning and sharing space with parent approval.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
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
    final phone = _phone.text.trim();
    if (!_isValidPhone(phone)) {
      setState(() {
        _error = 'Enter the mobile number in international format, for example +911234567890.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestMobileOtp(
            phone: phone,
            onCodeSent: (id) => setState(() => _verificationId = id),
            onFailed: (error) => setState(() {
              _error = _friendlyAuthError(error);
              _busy = false;
            }),
          );
    } on FirebaseAuthException catch (error) {
      _error = _friendlyAuthError(error);
    } catch (error) {
      _error = 'Could not send OTP. Please check Firebase setup and try again.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _error = 'Enter the 6 digit OTP code.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyOtp(
            verificationId: _verificationId!,
            smsCode: code,
          );
    } on FirebaseAuthException catch (error) {
      _error = _friendlyAuthError(error);
    } catch (error) {
      _error = 'Could not verify OTP. Please try again.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeProfile() async {
    final name = _name.text.trim();
    final age = int.tryParse(_age.text.trim());
    final inviteCode = _invite.text.trim();
    if (name.length < 2 || name.length > 40) {
      setState(() {
        _error = 'Display name must be 2 to 40 characters.';
      });
      return;
    }
    if (_role == UserRole.child && (age == null || age < 5 || age > 15)) {
      setState(() {
        _error = 'Child age must be between 5 and 15.';
      });
      return;
    }
    if (_role == UserRole.child && inviteCode.isEmpty) {
      setState(() {
        _error = 'Enter a parent invite code so a parent can approve this account.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).completeRegistration(
            role: _role,
            displayName: name,
            childAge: age,
            parentInviteCode: _role == UserRole.child ? inviteCode : null,
          );
    } catch (error) {
      _error = '$error';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isValidPhone(String value) {
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value);
  }

  String _friendlyAuthError(FirebaseAuthException error) {
    final message = error.message?.toLowerCase() ?? '';
    if (error.code == 'invalid-phone-number') {
      return 'The phone number format is invalid. Use international format, for example +911234567890.';
    }
    if (error.code == 'too-many-requests') {
      return 'OTP requests are temporarily blocked because too many attempts were made. Wait and try again.';
    }
    if (error.code == 'quota-exceeded') {
      return 'Firebase SMS quota is exhausted or billing/SMS limits are blocking this request.';
    }
    if (error.code == 'operation-not-allowed') {
      return 'Phone sign-in is not enabled in Firebase Authentication.';
    }
    if (error.code == 'internal-error' || message.contains('configuration')) {
      return 'Firebase phone auth is not fully configured. Enable Phone sign-in, add this Android app package to Firebase, and add SHA-1/SHA-256 fingerprints.';
    }
    return error.message ?? 'Authentication failed. Please try again.';
  }
}
