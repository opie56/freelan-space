import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_captcha.dart';
import 'design.dart';
import 'password_policy.dart';
import 'user_localization.dart';
import 'user_page_canvas.dart';
import 'user_saved_login.dart';

/// A temporary Auth session, separate from the app's persistent login.
class PasswordRecoveryClient {
  PasswordRecoveryClient(this.client, this.redirect);
  final GoTrueClient client;
  final String redirect;

  Future<void> send(String email, String? captcha) =>
      client.resetPasswordForEmail(
        email,
        redirectTo: redirect,
        captchaToken: captcha,
      );

  Future<void> verify(String email, String code) async {
    final result = await client.verifyOTP(
      email: email,
      token: code,
      type: OtpType.recovery,
    );
    if (result.session == null ||
        result.user?.email?.toLowerCase() != email.toLowerCase()) {
      throw const AuthException('Recovery verification failed');
    }
  }

  Future<void> update(String password) async {
    await client.updateUser(UserAttributes(password: password));
  }

  Future<void> close() async {
    try {
      if (client.currentSession != null) {
        await client.signOut(scope: SignOutScope.local);
      }
    } catch (_) {
      // The in-memory session is discarded even if the network is unavailable.
    } finally {
      client.dispose();
    }
  }
}

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({
    super.key,
    required this.createClient,
    required this.savedLogin,
    this.initialEmail = '',
    this.captchaProvider,
    this.now,
  });
  final PasswordRecoveryClient Function() createClient;
  final UserSavedLogin savedLogin;
  final String initialEmail;
  final AuthCaptchaProvider? captchaProvider;
  final DateTime Function()? now;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  late final PasswordRecoveryClient recovery = widget.createClient();
  late final email = TextEditingController(text: widget.initialEmail.trim());
  final code = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  int step = 0;
  bool busy = false, showPassword = false, showConfirm = false;
  String? error, verifiedEmail;
  DateTime? sentAt;
  Timer? timer;
  int get remaining => sentAt == null
      ? 0
      : (60 -
                (widget.now?.call() ?? DateTime.now())
                    .difference(sentAt!)
                    .inSeconds)
            .clamp(0, 60);
  String t(String en, String ml) => userText(context, en, ml);

  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    code.dispose();
    password.dispose();
    confirm.dispose();
    unawaited(recovery.close());
    super.dispose();
  }

  Future<void> send() async {
    if (busy || remaining > 0) return;
    final address = email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address)) {
      setState(
        () => error = t(
          'Enter a valid email address.',
          'ശരിയായ ഇമെയിൽ വിലാസം നൽകുക.',
        ),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final captcha = await (widget.captchaProvider ?? requestAuthCaptcha)(
        context,
      );
      if (!mounted) return;
      await recovery.send(address, captcha);
      if (!mounted) return;
      setState(() {
        verifiedEmail = address;
        step = 1;
        sentAt = widget.now?.call() ?? DateTime.now();
        code.clear();
      });
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return timer.cancel();
        setState(() {});
        if (remaining == 0) timer.cancel();
      });
    } on CaptchaCancelled {
      // No request was sent.
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t(
            'Unable to continue. Please try again.',
            'തുടരാനായില്ല. വീണ്ടും ശ്രമിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verify() async {
    if (busy) return;
    if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      setState(
        () => error = t('Enter the 6-digit code.', '6 അക്ക code നൽകുക.'),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await recovery.verify(verifiedEmail!, code.text.trim());
      if (mounted) {
        setState(() {
          step = 2;
          code.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t(
            'The code is invalid or expired. Try again.',
            'Code തെറ്റാണ് അല്ലെങ്കിൽ കാലഹരണപ്പെട്ടു. വീണ്ടും ശ്രമിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> update() async {
    if (busy) return;
    if (!meetsPasswordPolicy(password.text)) {
      setState(
        () => error = t(
          passwordRequirementsEnglish,
          passwordRequirementsMalayalam,
        ),
      );
      return;
    }
    if (password.text != confirm.text) {
      setState(
        () => error = t('Passwords do not match.', 'Passwords ഒരുപോലെയല്ല.'),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await recovery.update(password.text);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = t(
            'Unable to update password. Please try again.',
            'Password പുതുക്കാനായില്ല. വീണ്ടും ശ്രമിക്കുക.',
          );
          busy = false;
        });
      }
      return;
    }
    // Clear a stale saved password for this account, leaving other accounts alone.
    try {
      final saved = await widget.savedLogin.load();
      if (saved?['email']?.toLowerCase() == verifiedEmail?.toLowerCase()) {
        await widget.savedLogin.forget();
      }
    } catch (_) {
      // The password was already updated; never offer to submit it again.
    }
    password.clear();
    confirm.clear();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xff188758),
          size: 48,
        ),
        title: Text(t('Password updated', 'Password പുതുക്കി')),
        content: Text(
          t(
            'Sign in with your new password.',
            'പുതിയ password ഉപയോഗിച്ച് sign in ചെയ്യുക.',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t('Continue', 'തുടരുക')),
          ),
        ],
      ),
    );
    if (mounted) {
      setState(() => busy = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: UserPageScaffold(
      identity: UserPageIdentity.recovery,
      appBar: AppBar(
        title: Text(t('Account verification', 'Account സ്ഥിരീകരണം')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xff321073), Color(0xff6534ba)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          step == 0
                              ? t(
                                  'Verify your account',
                                  'Account സ്ഥിരീകരിക്കൂ',
                                )
                              : step == 1
                              ? t('Check your email', 'ഇമെയിൽ പരിശോധിക്കുക')
                              : t(
                                  'Create a new password',
                                  'പുതിയ password നൽകുക',
                                ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          step == 0
                              ? t(
                                  'We will send a verification code to your email.',
                                  'ഇമെയിലിലേക്ക് verification code അയയ്ക്കും.',
                                )
                              : step == 1
                              ? userCodeSentTo(context, verifiedEmail!)
                              : t(
                                  'Choose a strong password for your account.',
                                  'Account-ന് ശക്തമായ password നൽകുക.',
                                ),
                          style: const TextStyle(
                            color: Color(0xfff2eaff),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${step + 1} / 3',
                    style: const TextStyle(
                      color: Color(0xff6d6580),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (step == 0)
                    TextField(
                      key: const Key('recovery_email'),
                      controller: email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: t('Email', 'ഇമെയിൽ'),
                        prefixIcon: const Icon(Icons.alternate_email),
                      ),
                    ),
                  if (step == 1) ...[
                    TextField(
                      key: const Key('recovery_code'),
                      controller: code,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        labelText: t('6-digit code', '6 അക്ക code'),
                        prefixIcon: const Icon(Icons.pin_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy || remaining > 0 ? null : send,
                      child: Text(
                        remaining > 0
                            ? '${t('Resend code', 'Code വീണ്ടും അയയ്ക്കുക')} ($remaining)'
                            : t('Resend code', 'Code വീണ്ടും അയയ്ക്കുക'),
                      ),
                    ),
                  ],
                  if (step == 2) ...[
                    TextField(
                      key: const Key('recovery_password'),
                      controller: password,
                      enabled: !busy,
                      obscureText: !showPassword,
                      decoration: InputDecoration(
                        labelText: t('New password', 'പുതിയ password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: showPassword
                              ? t('Hide password', 'Password മറയ്ക്കുക')
                              : t('Show password', 'Password കാണിക്കുക'),
                          onPressed: () =>
                              setState(() => showPassword = !showPassword),
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const Key('recovery_confirm'),
                      controller: confirm,
                      enabled: !busy,
                      obscureText: !showConfirm,
                      decoration: InputDecoration(
                        labelText: t(
                          'Confirm password',
                          'Password വീണ്ടും നൽകുക',
                        ),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: showConfirm
                              ? t('Hide password', 'Password മറയ്ക്കുക')
                              : t('Show password', 'Password കാണിക്കുക'),
                          onPressed: () =>
                              setState(() => showConfirm = !showConfirm),
                          icon: Icon(
                            showConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t(
                        passwordRequirementsEnglish,
                        passwordRequirementsMalayalam,
                      ),
                      style: const TextStyle(
                        height: 1.4,
                        color: Color(0xff625d70),
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      key: const Key('recovery_error'),
                      style: const TextStyle(color: Color(0xffa23636)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  GrowthPrimaryButton(
                    onPressed: busy
                        ? null
                        : step == 0
                        ? send
                        : step == 1
                        ? verify
                        : update,
                    label: busy
                        ? t('Please wait', 'കാത്തിരിക്കുക')
                        : step == 0
                        ? t('Send code', 'Code അയയ്ക്കുക')
                        : step == 1
                        ? t('Verify code', 'Code പരിശോധിക്കുക')
                        : t('Update password', 'Password പുതുക്കുക'),
                    icon: Icons.arrow_forward,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
