import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_localization.dart';
import 'user_saved_login.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({
    super.key,
    required this.client,
    required this.savedLogin,
  });
  final SupabaseClient client;
  final UserSavedLogin savedLogin;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

enum _Step { consent, email, confirmation }

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  static const _phrase = 'ACCOUNT DELETE';
  final _code = TextEditingController();
  final _confirmation = TextEditingController();
  late final User? _user;
  _Step _step = _Step.consent;
  bool _agreed = false, _busy = false, _deleted = false;
  String? _message, _verifiedCode;
  DateTime? _sentAt;

  String _text(String en, String ml) => userText(context, en, ml);

  @override
  void initState() {
    super.initState();
    _user = widget.client.auth.currentUser;
  }

  @override
  void dispose() {
    _code.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    final current = widget.client.auth.currentUser;
    if (_busy) return;
    if (_user == null ||
        current?.id != _user.id ||
        current?.email != _user.email) {
      setState(
        () => _message = _text(
          'Your sign-in changed. Reopen this page to continue.',
          'ലോഗിൻ മാറി. തുടരാൻ ഈ പേജ് വീണ്ടും തുറക്കുക.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = _text(
            'Unable to continue. Check your connection and try again.',
            'തുടരാനായില്ല. ഇന്റർനെറ്റ് പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(() async {
    if (_sentAt != null &&
        DateTime.now().difference(_sentAt!) < const Duration(seconds: 60)) {
      setState(
        () => _message = _text(
          'Wait 60 seconds before requesting another code.',
          'പുതിയ കോഡ് ആവശ്യപ്പെടുന്നതിന് മുമ്പ് 60 സെക്കൻഡ് കാത്തിരിക്കുക.',
        ),
      );
      return;
    }
    await widget.client.auth.reauthenticate();
    if (!mounted) return;
    setState(() {
      _code.clear();
      _sentAt = DateTime.now();
      _message = _text(
        'Check your email for the confirmation code.',
        'സ്ഥിരീകരണ കോഡിനായി ഇമെയിൽ പരിശോധിക്കുക.',
      );
    });
  });

  void _showCodeError(Object? result) {
    setState(() {
      _step = _Step.email;
      _verifiedCode = null;
      _confirmation.clear();
      _message = switch (result) {
        'admin_account' => _text(
          'Administrator accounts must be managed by the project owner.',
          'അഡ്മിൻ അക്കൗണ്ടുകൾ പ്രോജക്റ്റ് ഉടമയാണ് കൈകാര്യം ചെയ്യേണ്ടത്.',
        ),
        'email_otp_required' => _text(
          'Sign in with your verified email to continue.',
          'തുടരാൻ സ്ഥിരീകരിച്ച ഇമെയിൽ ഉപയോഗിച്ച് ലോഗിൻ ചെയ്യുക.',
        ),
        _ => _text(
          'Code invalid or expired. Check the code or request a new one.',
          'കോഡ് തെറ്റാണ് അല്ലെങ്കിൽ കാലഹരണപ്പെട്ടു. കോഡ് പരിശോധിക്കുക അല്ലെങ്കിൽ പുതിയത് ആവശ്യപ്പെടുക.',
        ),
      };
    });
  }

  Future<void> _verify() => _run(() async {
    final nonce = _code.text.trim();
    if (_step != _Step.email ||
        _sentAt == null ||
        !RegExp(r'^[0-9]{6}$').hasMatch(nonce)) {
      return;
    }
    final result = await widget.client.rpc(
      'verify_account_deletion_code',
      params: {'p_nonce': nonce},
    );
    if (!mounted) return;
    if (result != 'ok') {
      _showCodeError(result);
      return;
    }
    setState(() {
      _verifiedCode = nonce;
      _code.clear();
      _step = _Step.confirmation;
    });
  });

  Future<void> _delete() => _run(() async {
    if (_step != _Step.confirmation ||
        _verifiedCode == null ||
        _confirmation.text != _phrase) {
      return;
    }
    final result = await widget.client.rpc(
      'delete_my_account',
      params: {'p_nonce': _verifiedCode},
    );
    if (result != 'ok') {
      if (mounted) _showCodeError(result);
      return;
    }
    _verifiedCode = null;
    _confirmation.clear();
    if (mounted) setState(() => _deleted = true);
    final cleanup = _cleanUpDeletedAccount();
    if (!mounted) {
      await cleanup;
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_text('Account deleted', 'അക്കൗണ്ട് നീക്കം ചെയ്തു')),
        content: Text(
          _text(
            'Your account was permanently deleted.',
            'നിങ്ങളുടെ അക്കൗണ്ട് സ്ഥിരമായി നീക്കം ചെയ്തു.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_text('OK', 'ശരി')),
          ),
        ],
      ),
    );
    await cleanup;
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  });

  Future<void> _cleanUpDeletedAccount() async {
    // A device cleanup failure does not undo a confirmed server deletion.
    try {
      await widget.savedLogin.forget();
    } catch (_) {
      /* The sign-in screen also offers a forget control. */
    }
    if (_user != null && widget.client.auth.currentUser?.id == _user.id) {
      try {
        await widget.client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        /* The deleted account no longer has server access. */
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          _text('Permanently delete account', 'Account സ്ഥിരമായി നീക്കുക'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_step == _Step.consent) ...[
                Text(
                  _text(
                    'What you will lose',
                    'നിങ്ങൾക്ക് നഷ്ടമാകുന്ന വിവരങ്ങൾ',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  _text(
                    '• Your sign-in, profile, profile photo and linked Instagram accounts.\n'
                        '• Your coin balance, wallet access, rewards and referral access.\n'
                        '• Access to your campaigns, submissions, saved tasks, notifications and support conversations.\n'
                        '• Your real name verification and any pending ID proof.',
                    '• ലോഗിൻ, പ്രൊഫൈൽ, പ്രൊഫൈൽ ഫോട്ടോ, ബന്ധിപ്പിച്ച Instagram അക്കൗണ്ടുകൾ.\n'
                        '• കോയിൻ ബാലൻസ്, വാലറ്റ്, റിവാർഡുകൾ, റഫറൽ സൗകര്യം.\n'
                        '• ക്യാമ്പെയ്‌നുകൾ, സമർപ്പണങ്ങൾ, സേവ് ചെയ്ത ടാസ്‌ക്കുകൾ, അറിയിപ്പുകൾ, സപ്പോർട്ട് സംഭാഷണങ്ങൾ എന്നിവയിലേക്കുള്ള പ്രവേശനം.\n'
                        '• പേര് സ്ഥിരീകരണവും പരിശോധനയ്ക്ക് കാത്തിരിക്കുന്ന തിരിച്ചറിയൽ രേഖയും.',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _text('What is kept', 'സൂക്ഷിക്കുന്ന വിവരങ്ങൾ'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  _text(
                    'Authorized administrators keep a private audit copy of profile details, campaigns, submission evidence, wallet and referral history, and support messages. Payment receipts are also retained. Passwords, PINs, login codes, sessions and pending ID proof are excluded from the audit copy.',
                    'അധികാരമുള്ള അഡ്മിൻമാർ പ്രൊഫൈൽ വിവരങ്ങൾ, ക്യാമ്പെയ്‌നുകൾ, സമർപ്പിച്ച തെളിവുകൾ, വാലറ്റ്, റഫറൽ ചരിത്രം, സപ്പോർട്ട് സന്ദേശങ്ങൾ എന്നിവയുടെ സ്വകാര്യ ഓഡിറ്റ് പകർപ്പ് സൂക്ഷിക്കും. പേയ്‌മെന്റ് രസീതുകളും സൂക്ഷിക്കും. പാസ്‌വേഡ്, PIN, ലോഗിൻ കോഡ്, സെഷൻ, പരിശോധനയ്ക്ക് കാത്തിരിക്കുന്ന തിരിച്ചറിയൽ രേഖ എന്നിവ ഓഡിറ്റ് പകർപ്പിൽ ഉണ്ടാകില്ല.',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _text(
                    'This is permanent. Your account, coins and lost data cannot be recovered. The audit copy cannot be used to restore your account.',
                    'ഇത് ശാശ്വതമാണ്. അക്കൗണ്ട്, കോയിൻ, നഷ്ടപ്പെട്ട വിവരങ്ങൾ എന്നിവ വീണ്ടെടുക്കാനാവില്ല. ഓഡിറ്റ് പകർപ്പ് ഉപയോഗിച്ച് അക്കൗണ്ട് പുനഃസ്ഥാപിക്കാനാവില്ല.',
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _agreed,
                  onChanged: (value) =>
                      setState(() => _agreed = value ?? false),
                  title: Text(
                    _text(
                      'I have read the details and agree to permanent deletion.',
                      'വിവരങ്ങൾ വായിച്ചു. അക്കൗണ്ട് സ്ഥിരമായി നീക്കം ചെയ്യാൻ ഞാൻ സമ്മതിക്കുന്നു.',
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _agreed
                      ? () => setState(() => _step = _Step.email)
                      : null,
                  child: Text(_text('Continue', 'തുടരുക')),
                ),
              ],
              if (_step == _Step.email) ...[
                Text(
                  _text(
                    'Verify your email address',
                    'ഇമെയിൽ വിലാസം സ്ഥിരീകരിക്കുക',
                  ),
                ),
                if (_user?.email case final email? when email.isNotEmpty) ...[
                  SelectableText(email, textDirection: TextDirection.ltr),
                  OutlinedButton(
                    onPressed: _busy ? null : _send,
                    child: Text(
                      _sentAt == null
                          ? _text(
                              'Send confirmation code',
                              'സ്ഥിരീകരണ കോഡ് അയയ്ക്കുക',
                            )
                          : _text(
                              'Resend email code',
                              'ഇമെയിൽ കോഡ് വീണ്ടും അയയ്ക്കുക',
                            ),
                    ),
                  ),
                ] else
                  Text(
                    _text(
                      'Sign in with your verified email to continue.',
                      'തുടരാൻ സ്ഥിരീകരിച്ച ഇമെയിൽ ഉപയോഗിച്ച് ലോഗിൻ ചെയ്യുക.',
                    ),
                  ),
                if (_sentAt != null) ...[
                  TextField(
                    controller: _code,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _text(
                        'Email confirmation code',
                        'ഇമെയിൽ സ്ഥിരീകരണ കോഡ്',
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed:
                        !_busy &&
                            RegExp(r'^[0-9]{6}$').hasMatch(_code.text.trim())
                        ? _verify
                        : null,
                    child: Text(_text('Verify code', 'കോഡ് സ്ഥിരീകരിക്കുക')),
                  ),
                ],
              ],
              if (_step == _Step.confirmation) ...[
                Text(
                  _text(
                    'Email verified. Type ACCOUNT DELETE to permanently delete your account.',
                    'ഇമെയിൽ സ്ഥിരീകരിച്ചു. അക്കൗണ്ട് സ്ഥിരമായി നീക്കം ചെയ്യാൻ ACCOUNT DELETE എന്ന് ടൈപ്പ് ചെയ്യുക.',
                  ),
                ),
                TextField(
                  controller: _confirmation,
                  enabled: !_busy,
                  autocorrect: false,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: _phrase),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: !_busy && _confirmation.text == _phrase
                      ? _delete
                      : null,
                  child: Text(
                    _text(
                      'Delete my account permanently',
                      'എന്റെ അക്കൗണ്ട് സ്ഥിരമായി നീക്കുക',
                    ),
                  ),
                ),
              ],
              if (_message != null)
                Semantics(liveRegion: true, child: Text(_message!)),
              if (_busy && !_deleted) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    ),
  );
}
