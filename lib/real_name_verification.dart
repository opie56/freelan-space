import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_preferences_banner.dart';
import 'evidence_image.dart';
import 'user_page_canvas.dart';
import 'user_tokens.dart';

String verificationText(BuildContext context, String en, String ml) =>
    Localizations.localeOf(context).languageCode == 'ml' ? ml : en;

enum VerificationDocument {
  aadhaar(
    'aadhaar',
    'Aadhaar',
    Icons.fingerprint,
    'the photo and name side',
    'the address side',
  ),
  voterId(
    'voter_id',
    'Voter ID',
    Icons.how_to_vote_outlined,
    'the photo and voter details',
    'the reverse with address details',
  ),
  drivingLicence(
    'driving_licence',
    'Driving licence',
    Icons.directions_car_outlined,
    'the photo and licence details',
    'the reverse of the licence',
  ),
  passport(
    'passport',
    'Passport',
    Icons.menu_book_outlined,
    'the photo and name page',
    'the last page with address or file details',
  ),
  pan(
    'pan',
    'PAN card',
    Icons.credit_card,
    'the photo, name and PAN',
    'the reverse of the PAN card',
  );

  const VerificationDocument(
    this.code,
    this.label,
    this.icon,
    this.frontGuide,
    this.backGuide,
  );
  final String code, label, frontGuide, backGuide;
  final IconData icon;

  static String? labelFor(Object? code) {
    for (final document in values) {
      if (document.code == code) return document.label;
    }
    return null;
  }
}

class RealNameVerificationPage extends StatefulWidget {
  const RealNameVerificationPage({
    super.key,
    required this.client,
    this.authorizeNameChange,
    this.capture,
  });
  final SupabaseClient client;
  final Future<bool> Function()? authorizeNameChange;
  final Future<XFile?> Function()? capture;

  @override
  State<RealNameVerificationPage> createState() =>
      _RealNameVerificationPageState();
}

class _Proof {
  const _Proof(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;

  Map<String, String> toJson() => {'mime': mime, 'data': base64Encode(bytes)};
}

class _RealNameVerificationPageState extends State<RealNameVerificationPage> {
  final name = TextEditingController();
  VerificationDocument? document;
  _Proof? front, back;
  Map<String, dynamic>? status;
  String? check, error;
  bool working = false, statusLoading = false, nameInitialized = false;
  int seconds = 0;
  Timer? countdown;
  final elapsed = Stopwatch();
  late final String? owner;
  late final StreamSubscription<AuthState> sessionChanges;

  @override
  void initState() {
    super.initState();
    owner = widget.client.auth.currentUser?.id;
    sessionChanges = widget.client.auth.onAuthStateChange.listen(
      (event) {
        if (!mounted || event.session?.user.id == owner) return;
        countdown?.cancel();
        setState(() {
          name.clear();
          front = null;
          back = null;
          status = null;
          check = null;
          error = t(
            'Your session ended. Sign in again.',
            'സെഷൻ അവസാനിച്ചു. വീണ്ടും സൈൻ ഇൻ ചെയ്യുക.',
          );
        });
      },
      onError: (Object _) {
        // The session is also checked before each proof operation.
      },
    );
    load();
  }

  @override
  void dispose() {
    countdown?.cancel();
    unawaited(sessionChanges.cancel());
    name.dispose();
    super.dispose();
  }

  String t(String en, String ml) => verificationText(context, en, ml);
  void ensureSession() {
    if (owner == null || owner != widget.client.auth.currentUser?.id) {
      throw const AuthException('Session changed');
    }
  }

  Future<void> load() async {
    if (statusLoading || working) return;
    countdown?.cancel();
    setState(() {
      statusLoading = true;
      error = null;
    });
    try {
      ensureSession();
      final value = await widget.client.rpc('real_name_verification_status');
      ensureSession();
      if (!mounted) return;
      setState(() {
        applyStatus(Map<String, dynamic>.from(value as Map));
        if (!nameInitialized) {
          name.text = (status?['profile_name'] as String?) ?? '';
          nameInitialized = true;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t(
            'Could not load verification. Try again.',
            'പേര് പരിശോധന ലഭ്യമായില്ല. വീണ്ടും ശ്രമിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => statusLoading = false);
    }
  }

  void applyStatus(Map<String, dynamic> value) {
    status = value;
    countdown?.cancel();
    final initial = (value['seconds_remaining'] as num?)?.toInt() ?? 0;
    seconds = initial;
    if (initial <= 0) return;
    elapsed
      ..reset()
      ..start();
    countdown = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final remaining = initial - elapsed.elapsed.inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        setState(() => seconds = 0);
        unawaited(load());
      } else if (remaining != seconds) {
        setState(() => seconds = remaining);
      }
    });
  }

  Future<void> takePhoto(bool isFront) async {
    setState(() {
      working = true;
      error = null;
    });
    XFile? file;
    try {
      ensureSession();
      file =
          await (widget.capture?.call() ??
              ImagePicker().pickImage(
                source: ImageSource.camera,
                preferredCameraDevice: CameraDevice.rear,
                maxWidth: 1800,
                maxHeight: 1800,
                imageQuality: 82,
                requestFullMetadata: false,
              ));
      if (file == null || !mounted) return;
      ensureSession();
      if (await file.length() > 524288) throw const FormatException();
      final bytes = await file.readAsBytes();
      await validateEvidenceImage(bytes);
      ensureSession();
      if (!mounted) return;
      setState(() {
        final photo = _Proof(
          bytes,
          bytes[0] == 0xff ? 'image/jpeg' : 'image/png',
        );
        if (isFront) {
          front = photo;
        } else {
          back = photo;
        }
        check = null;
      });
    } on FormatException {
      if (mounted) {
        setState(
          () => error = t(
            'Retake the photo as a JPEG or PNG under 512 KB.',
            '512 KB-ൽ താഴെയുള്ള JPEG അല്ലെങ്കിൽ PNG ആയി വീണ്ടും എടുക്കുക.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t(
            'Could not open the camera. Check camera access and try again.',
            'ക്യാമറ തുറക്കാനായില്ല. അനുമതി പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.',
          ),
        );
      }
    } finally {
      // Camera images from image_picker are temporary cache files on Android.
      if (file != null &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          widget.capture == null) {
        try {
          await File(file.path).delete();
        } on FileSystemException {
          // The system may already have removed the temporary file.
        }
      }
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> send(String action) async {
    final selected = document;
    final frontPhoto = front, backPhoto = back;
    final draft = name.text.trim();
    if (working ||
        statusLoading ||
        selected == null ||
        frontPhoto == null ||
        backPhoto == null ||
        draft.isEmpty ||
        draft.runes.length > 80) {
      return;
    }
    setState(() {
      working = true;
      error = null;
    });
    try {
      ensureSession();
      if (action != 'check' &&
          draft != widget.client.auth.currentUser?.userMetadata?['full_name']) {
        if (widget.authorizeNameChange != null &&
            !await widget.authorizeNameChange!()) {
          return;
        }
        if (!mounted) return;
        ensureSession();
        await widget.client.auth.updateUser(
          UserAttributes(data: {'full_name': draft}),
        );
        ensureSession();
      }
      final response = await widget.client.functions.invoke(
        'real-name-verification',
        body: {
          'action': action,
          'name': draft,
          'document_type': selected.code,
          'front': frontPhoto.toJson(),
          'back': backPhoto.toJson(),
        },
      );
      if (!mounted) return;
      ensureSession();
      final result = Map<String, dynamic>.from(response.data as Map);
      setState(() {
        if (result['status'] == 'processing' || result['status'] == 'pending') {
          applyStatus(result);
          front = null;
          back = null;
          check = null;
          FocusManager.instance.primaryFocus?.unfocus();
        } else {
          check = result['status'] as String?;
        }
      });
    } on FunctionException catch (failure) {
      if (!mounted) return;
      final details = failure.details;
      final code = details is Map ? details['status'] : null;
      setState(() {
        if (code == 'invalid_photos' || code == 'unavailable') {
          check = code as String;
        } else {
          error = code == 'try_later'
              ? t(
                  'Try again in a minute, or refresh the current status.',
                  'ഒരു മിനിറ്റിന് ശേഷം വീണ്ടും ശ്രമിക്കുക, അല്ലെങ്കിൽ നിലവിലെ സ്ഥിതി പുതുക്കുക.',
                )
              : t(
                  'Could not submit. Refresh your status and try again.',
                  'അയയ്ക്കാനായില്ല. സ്ഥിതി പുതുക്കി വീണ്ടും ശ്രമിക്കുക.',
                );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t(
            'Could not complete the request. Refresh and try again.',
            'അപേക്ഷ പൂർത്തിയാക്കാനായില്ല. പുതുക്കി വീണ്ടും ശ്രമിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Widget panel(
    int step,
    String title,
    String description,
    List<Widget> children,
  ) => Card(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: userLine),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: const Color(0xffeee6fa),
                foregroundColor: const Color(0xff512b80),
                child: Text('$step'),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: userInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(description, style: const TextStyle(color: userMuted)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  Widget photoTile(bool isFront, _Proof? photo) {
    final label = isFront ? t('Front', 'മുൻവശം') : t('Back', 'പിൻവശം');
    return OutlinedButton(
      onPressed: working ? null : () => takePhoto(isFront),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.65,
            child: photo == null
                ? const Icon(Icons.photo_camera_outlined, size: 29)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(photo.bytes, fit: BoxFit.contain),
                  ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
            photo == null
                ? t('Open camera', 'ക്യാമറ തുറക്കുക')
                : t('Retake', 'വീണ്ടും എടുക്കുക'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget notice(
    IconData icon,
    String title,
    String body, {
    bool warning = false,
  }) {
    final color = warning ? const Color(0xff813d28) : userTeal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warning ? const Color(0xffffeee7) : const Color(0xffe4f5ef),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                if (body.isNotEmpty) ...[const SizedBox(height: 4), Text(body)],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = status?['status'];
    final automatic =
        state == 'processing' || status?['seconds_remaining'] != null;
    final selected = document;
    final ready =
        !statusLoading &&
        selected != null &&
        front != null &&
        back != null &&
        name.text.trim().isNotEmpty;
    final manual = const {'unreadable', 'unavailable'}.contains(check);
    return UserPageScaffold(
      identity: UserPageIdentity.realName,
      appBar: AppBar(
        title: Text(t('Real name verification', 'യഥാർത്ഥ പേര് പരിശോധിക്കൽ')),
        actions: [
          IconButton(
            onPressed: working || statusLoading ? null : load,
            icon: const Icon(Icons.refresh),
            tooltip: t('Refresh status', 'സ്ഥിതി പുതുക്കുക'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              AccountPreferencesBanner(
                kicker: t('PROFILE • IDENTITY', 'പ്രൊഫൈൽ • തിരിച്ചറിയൽ'),
                title: t(
                  'Verify your real name',
                  'നിങ്ങളുടെ യഥാർത്ഥ പേര് സ്ഥിരീകരിക്കുക',
                ),
                subtitle: t(
                  'Match the name on your profile to a government ID and unlock a verified badge.',
                  'സർക്കാർ ID-യിലെ പേരുമായി പ്രൊഫൈൽ പേര് പൊരുത്തപ്പെടുത്തി verified badge നേടുക.',
                ),
                icon: Icons.verified_user_outlined,
              ),
              const SizedBox(height: 14),
              if (statusLoading || working) const LinearProgressIndicator(),
              if (automatic)
                notice(
                  Icons.timer_outlined,
                  t(
                    'Your name will be verified automatically shortly.',
                    'നിങ്ങളുടെ പേര് ഉടൻ സ്വയമേവ സ്ഥിരീകരിക്കും.',
                  ),
                  seconds > 0
                      ? t(
                          'Finishing in ${seconds}s',
                          '${seconds}s ൽ പൂർത്തിയാകും',
                        )
                      : t('Checking your result…', 'ഫലം പരിശോധിക്കുന്നു…'),
                )
              else if (state == 'pending')
                notice(
                  Icons.fact_check_outlined,
                  t('Submitted for ID review', 'ID പരിശോധനയ്ക്ക് നൽകി'),
                  t(
                    'An administrator will check your proof. You can see the result here.',
                    'അഡ്മിൻ നിങ്ങളുടെ രേഖ പരിശോധിക്കും. ഫലം ഇവിടെ കാണാം.',
                  ),
                )
              else if (state == 'approved')
                notice(
                  Icons.verified,
                  t(
                    'Your real name is verified',
                    'നിങ്ങളുടെ പേര് സ്ഥിരീകരിച്ചു',
                  ),
                  t(
                    '${status?['verified_name'] ?? ''} is now locked on your profile.',
                    '${status?['verified_name'] ?? ''} എന്ന പേര് ഇനി മാറ്റാനാകില്ല.',
                  ),
                )
              else if (status != null) ...[
                if (state == 'rejected') ...[
                  notice(
                    Icons.info_outline,
                    t('Verification rejected', 'അപേക്ഷ നിരസിച്ചു'),
                    (status?['rejection_reason'] as String?) ??
                        t(
                          'No reason was recorded for this earlier request. You can submit new photos.',
                          'ഈ പഴയ അപേക്ഷയ്ക്ക് കാരണം രേഖപ്പെടുത്തിയിട്ടില്ല. പുതിയ ചിത്രങ്ങൾ നൽകാം.',
                        ),
                    warning: true,
                  ),
                  const SizedBox(height: 10),
                ],
                panel(
                  1,
                  t('Choose your ID', 'ID തിരഞ്ഞെടുക്കുക'),
                  t(
                    'Select the document you have with you.',
                    'നിങ്ങളുടെ കൈവശമുള്ള രേഖ തിരഞ്ഞെടുക്കുക.',
                  ),
                  [
                    DropdownButtonFormField<VerificationDocument>(
                      initialValue: selected,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: t('Document type', 'രേഖയുടെ തരം'),
                      ),
                      items: [
                        for (final option in VerificationDocument.values)
                          DropdownMenuItem(
                            value: option,
                            child: Row(
                              children: [
                                Icon(option.icon, size: 20),
                                const SizedBox(width: 10),
                                Text(option.label),
                              ],
                            ),
                          ),
                      ],
                      onChanged: working
                          ? null
                          : (value) => setState(() {
                              if (document == value) return;
                              document = value;
                              front = null;
                              back = null;
                              check = null;
                              error = null;
                            }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                panel(
                  2,
                  t('Capture both sides', 'രണ്ട് വശവും ചിത്രീകരിക്കുക'),
                  selected == null
                      ? t(
                          'Choose an ID to see its photo guide.',
                          'ചിത്ര നിർദ്ദേശം കാണാൻ ID തിരഞ്ഞെടുക്കുക.',
                        )
                      : t(
                          'Front: ${selected.frontGuide}. Back: ${selected.backGuide}. Keep all text sharp and in frame.',
                          'മുൻവശം: ${selected.frontGuide}. പിൻവശം: ${selected.backGuide}. എഴുത്ത് മുഴുവൻ വ്യക്തമായി കാണണം.',
                        ),
                  [
                    if (selected != null)
                      Row(
                        children: [
                          Expanded(child: photoTile(true, front)),
                          const SizedBox(width: 10),
                          Expanded(child: photoTile(false, back)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                panel(
                  3,
                  t('Confirm your name', 'പേര് ഉറപ്പാക്കുക'),
                  t(
                    'Enter the full name printed on the ID. You can edit it here before submitting.',
                    'ID-യിൽ അച്ചടിച്ച മുഴുവൻ പേരും നൽകുക. അപേക്ഷ അയയ്ക്കും മുമ്പ് ഇവിടെ മാറ്റാം.',
                  ),
                  [
                    TextField(
                      controller: name,
                      enabled: !working,
                      maxLength: 80,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: t('Profile name', 'പ്രൊഫൈൽ പേര്'),
                      ),
                      onChanged: (_) => setState(() {
                        check = null;
                        error = null;
                      }),
                    ),
                    if (check != null) ...[
                      notice(
                        check == 'match'
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        switch (check) {
                          'match' => t('Name matches', 'പേര് പൊരുത്തപ്പെട്ടു'),
                          'mismatch' => t(
                            'The name does not match',
                            'പേര് പൊരുത്തപ്പെടുന്നില്ല',
                          ),
                          'invalid_photos' => t(
                            'Check both photos',
                            'രണ്ട് ചിത്രവും പരിശോധിക്കുക',
                          ),
                          'unavailable' => t(
                            'Automatic check unavailable',
                            'സ്വയമേവ പരിശോധിക്കാൻ കഴിയുന്നില്ല',
                          ),
                          _ => t(
                            'Could not read the name or ID format clearly',
                            'പേരോ രേഖയുടെ രൂപമോ വ്യക്തമായി വായിക്കാനായില്ല',
                          ),
                        },
                        switch (check) {
                          'match' => t(
                            'Submit to start automatic verification.',
                            'സ്വയമേവ പരിശോധിക്കാൻ അപേക്ഷ അയയ്ക്കുക.',
                          ),
                          'mismatch' => t(
                            'Edit the name above to match the ID, then check it again.',
                            'ID-യിലുള്ളതുപോലെ മുകളിൽ പേര് തിരുത്തി വീണ്ടും പരിശോധിക്കുക.',
                          ),
                          'unavailable' => t(
                            'Try the scan again or send both photos for admin review.',
                            'വീണ്ടും പരിശോധിക്കുക, അല്ലെങ്കിൽ രണ്ട് ചിത്രവും അഡ്മിന് അയയ്ക്കുക.',
                          ),
                          _ => t(
                            'Retake clear photos of the front and back.',
                            'മുൻവശവും പിൻവശവും വ്യക്തമായി വീണ്ടും എടുക്കുക.',
                          ),
                        },
                        warning: check != 'match',
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (check == 'match')
                      FilledButton.icon(
                        onPressed: ready && !working
                            ? () => send('submit')
                            : null,
                        icon: const Icon(Icons.verified_outlined),
                        label: Text(
                          t(
                            'Submit for verification',
                            'സ്ഥിരീകരിക്കാൻ അയയ്ക്കുക',
                          ),
                        ),
                      )
                    else
                      FilledButton.icon(
                        onPressed: ready && !working
                            ? () => send('check')
                            : null,
                        icon: const Icon(Icons.document_scanner_outlined),
                        label: Text(
                          t(
                            'Scan and check name',
                            'സ്കാൻ ചെയ്ത് പേര് പരിശോധിക്കുക',
                          ),
                        ),
                      ),
                    if (manual)
                      TextButton(
                        onPressed: ready && !working
                            ? () => send('manual')
                            : null,
                        child: Text(
                          t(
                            'Send for admin review',
                            'അഡ്മിൻ പരിശോധനയ്ക്ക് അയയ്ക്കുക',
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                notice(
                  Icons.lock_outline,
                  t('Private ID photos', 'സ്വകാര്യ ID ചിത്രങ്ങൾ'),
                  t(
                    'Your photos are used to check your name and removed after a decision.',
                    'പേര് പരിശോധിക്കാൻ മാത്രം ചിത്രങ്ങൾ ഉപയോഗിക്കും. തീരുമാനത്തിന് ശേഷം നീക്കും.',
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 10),
                notice(
                  Icons.error_outline,
                  t('Try again', 'വീണ്ടും ശ്രമിക്കുക'),
                  error!,
                  warning: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
