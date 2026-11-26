import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'evidence_image.dart';

String verificationText(BuildContext context, String en, String ml) =>
    Localizations.localeOf(context).languageCode == 'ml' ? ml : en;

class RealNameVerificationPage extends StatefulWidget {
  const RealNameVerificationPage({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<RealNameVerificationPage> createState() =>
      _RealNameVerificationPageState();
}

class _RealNameVerificationPageState extends State<RealNameVerificationPage> {
  late Future<dynamic> status;
  Uint8List? proof;
  String? mime;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() => status = widget.client.rpc('real_name_verification_status');
  Future<void> choose() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      if (await file.length() > 524288) throw const FormatException();
      final bytes = await file.readAsBytes();
      await validateEvidenceImage(bytes);
      final type = bytes[0] == 0xff && bytes[1] == 0xd8
          ? 'image/jpeg'
          : 'image/png';
      if (mounted) {
        setState(() {
          proof = bytes;
          mime = type;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = verificationText(
            context,
            'Choose a valid JPEG or PNG under 512 KB.',
            '512 KB-ൽ താഴെയുള്ള JPEG അല്ലെങ്കിൽ PNG തിരഞ്ഞെടുക്കുക.',
          ),
        );
      }
    }
  }

  Future<void> submit() async {
    if (proof == null || mime == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.client.rpc(
        'submit_real_name_verification',
        params: {'p_mime': mime, 'p_data': base64Encode(proof!)},
      );
      if (mounted) {
        setState(() {
          proof = null;
          mime = null;
          load();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = verificationText(
            context,
            'Unable to submit. Check your profile name and try again.',
            'അയയ്ക്കാനായില്ല. Profile പേര് പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        verificationText(
          context,
          'Real name verification',
          'യഥാർത്ഥ പേര് പരിശോധിക്കൽ',
        ),
      ),
      actions: [
        IconButton(
          onPressed: busy ? null : () => setState(load),
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: FutureBuilder<dynamic>(
          future: status,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: () => setState(load),
                  child: Text(
                    verificationText(
                      context,
                      'Could not load. Retry',
                      'ലഭ്യമായില്ല. വീണ്ടും ശ്രമിക്കുക',
                    ),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final state = (snapshot.data as Map)['status'] as String;
            final canSubmit = state != 'pending' && state != 'approved';
            final message = switch (state) {
              'pending' => verificationText(
                context,
                'Your request is waiting for admin review.',
                'നിങ്ങളുടെ അപേക്ഷ admin പരിശോധിക്കുന്നതിനായി കാത്തിരിക്കുന്നു.',
              ),
              'approved' => verificationText(
                context,
                'Your real name is verified.',
                'നിങ്ങളുടെ യഥാർത്ഥ പേര് പരിശോധിച്ചു.',
              ),
              'rejected' => verificationText(
                context,
                'Your request was rejected. You can submit a new ID proof.',
                'അപേക്ഷ നിരസിച്ചു. പുതിയ ID proof നൽകാം.',
              ),
              'name_changed' => verificationText(
                context,
                'Your profile name changed. Submit a new request for this name.',
                'Profile പേര് മാറി. പുതിയ പേരിനായി അപേക്ഷ നൽകുക.',
              ),
              _ => verificationText(
                context,
                'Submit an ID proof to have your profile name reviewed by an admin.',
                'Profile പേര് പരിശോധിക്കാൻ ഒരു ID proof നൽകുക.',
              ),
            };
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 56,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 18),
                Text(message, style: Theme.of(context).textTheme.titleMedium),
                if (canSubmit) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${verificationText(context, 'Profile name', 'Profile പേര്')}: ${widget.client.auth.currentUser?.userMetadata?['full_name'] ?? verificationText(context, 'Not set', 'നൽകിയിട്ടില്ല')}',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    verificationText(
                      context,
                      'Set your full name in Personal information first. Upload a clear photo of an ID showing the same name (JPEG or PNG, up to 512 KB). The admin reviews it and the image is removed after the decision.',
                      'ആദ്യം Personal information-ൽ പൂർണ്ണ പേര് നൽകുക. അതേ പേര് കാണിക്കുന്ന ID-യുടെ വ്യക്തമായ ചിത്രം നൽകുക (JPEG/PNG, പരമാവധി 512 KB). Admin തീരുമാനം എടുത്ത ശേഷം ചിത്രം നീക്കം ചെയ്യും.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: busy ? null : choose,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      proof == null
                          ? verificationText(
                              context,
                              'Choose ID proof',
                              'ID proof തിരഞ്ഞെടുക്കുക',
                            )
                          : verificationText(
                              context,
                              'Change ID proof',
                              'ID proof മാറ്റുക',
                            ),
                    ),
                  ),
                  if (proof != null)
                    Text(
                      verificationText(
                        context,
                        'ID image selected',
                        'ID ചിത്രം തിരഞ്ഞെടുത്തു',
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: busy || proof == null ? null : submit,
                    child: Text(
                      verificationText(
                        context,
                        'Submit for review',
                        'പരിശോധനയ്ക്ക് അയയ്ക്കുക',
                      ),
                    ),
                  ),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (busy) const LinearProgressIndicator(),
              ],
            );
          },
        ),
      ),
    ),
  );
}
