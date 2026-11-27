import 'admin_destination.dart';

import 'dart:io';

import 'admin_release_audience.dart';
import 'admin_release_activity.dart';
import 'admin_notifications.dart';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_operations.dart';
import 'admin_design.dart';
import 'app_updates.dart';
import 'admin_referral_download.dart';
import 'referral_download.dart';

class AdminAppReleasesPage extends StatefulWidget {
  const AdminAppReleasesPage({
    super.key,
    required this.client,
    required this.canEdit,
  });
  final SupabaseClient client;
  final bool canEdit;
  @override
  State<AdminAppReleasesPage> createState() => _AdminAppReleasesPageState();
}

class _AdminAppReleasesPageState extends State<AdminAppReleasesPage> {
  final code = TextEditingController(),
      name = TextEditingController(),
      notes = TextEditingController();
  XFile? apk;
  Map<String, dynamic>? recipient;
  bool busy = false;
  int referralRevision = 0;
  String? error;
  late Future<List<Map<String, dynamic>>> releases;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    releases = widget.client
        .rpc('admin_app_release_history')
        .then((rows) => List<Map<String, dynamic>>.from(rows as List));
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'Android APK', extensions: ['apk']),
        ],
      );
      if (file == null) return;
      if (await file.length() > maxApkBytes) {
        if (mounted) setState(() => error = 'APK must be at most 200 MiB.');
        return;
      }
      if (mounted) {
        setState(() {
          apk = file;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unable to read the APK. Choose the file again.',
        );
      }
    }
  }

  Future<void> publish() async {
    final version = int.tryParse(code.text.trim());
    final versionName = name.text.trim();
    final releaseNotes = notes.text.trim();
    if (version == null ||
        version < 1 ||
        version > 2100000000 ||
        versionName.isEmpty ||
        versionName.length > 60 ||
        releaseNotes.length > 4000 ||
        apk == null) {
      setState(
        () => error = 'Choose a signed APK and enter its version code, version name and release notes.',
      );
      return;
    }
    if (recipient != null && recipient!['id'] == null) {
      setState(() => error = 'Select a release recipient.');
      return;
    }
    final file = apk!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Publish app update?'),
        content: Text(
          'Version $versionName (build $version) will be offered to ${recipient == null ? 'all active users' : recipient!['email']}. Use the same signing key as the installed app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!await verifyAdminMfa(context, widget.client)) return;
      final bytes = await file.readAsBytes();
      if (bytes.length < 4 ||
          bytes.length > maxApkBytes ||
          bytes[0] != 0x50 ||
          bytes[1] != 0x4b) {
        throw const FormatException('Invalid APK');
      }
      final hash = sha256.convert(bytes).toString();
      final prepare = await widget.client.functions.invoke(
        'app-release-upload',
        body: {'action': 'prepare', 'size': bytes.length},
      );
      final upload = prepare.data as Map<String, dynamic>;
      final uri = Uri.parse(upload['url'] as String);
      if (uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
        throw const FormatException('Invalid upload URL');
      }
      final http = HttpClient();
      try {
        final request = await http.putUrl(uri);
        request.followRedirects = false;
        request.contentLength = bytes.length;
        request.headers.set(
          HttpHeaders.contentTypeHeader,
          'application/vnd.android.package-archive',
        );
        request.headers.set(HttpHeaders.ifNoneMatchHeader, '*');
        request.add(bytes);
        final response = await request.close();
        await response.drain<void>();
        if (response.statusCode != 200) {
          throw const FormatException('Upload failed');
        }
      } finally {
        http.close(force: true);
      }
      await widget.client.functions.invoke(
        'app-release-upload',
        body: {
          'action': 'publish',
          'key': upload['key'],
          'size': bytes.length,
          'sha256': hash,
          'versionCode': version,
          'versionName': versionName,
          'notes': releaseNotes,
          'targetUser': recipient?['id'],
        },
      );
      if (mounted) {
        setState(() {
          apk = null;
          code.clear();
          name.clear();
          notes.clear();
          load();
          referralRevision++;
        });
      }
    } catch (_) {
      // A response can be lost after publication committed; never delete its APK.
      if (mounted) {
        setState(() {
          error = 'Unable to confirm publication. Refresh releases before retrying. Check increasing version code, editor access, R2 setup and connection.';
          load();
          referralRevision++;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> promote(String releaseId) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!await verifyAdminMfa(context, widget.client)) return;
      await widget.client.rpc(
        'admin_promote_app_release',
        params: {'p_release': releaseId},
      );
      if (mounted) {
        setState(() {
          load();
          referralRevision++;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Update published to all active users.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Unable to confirm publication. Refresh releases before retrying. A newer release may already be available to everyone.';
          load();
          referralRevision++;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget releaseForm(bool wide) {
    final codeField = TextField(
      controller: code,
      enabled: !busy,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'APK version code (build number)',
      ),
    );
    final nameField = TextField(
      controller: name,
      enabled: !busy,
      maxLength: 60,
      decoration: const InputDecoration(labelText: 'Version name'),
    );
    final notesField = TextField(
      controller: notes,
      enabled: !busy,
      maxLength: 4000,
      maxLines: 3,
      decoration: const InputDecoration(labelText: 'What is new?'),
    );
    final choose = OutlinedButton.icon(
      onPressed: busy ? null : pick,
      icon: const Icon(Icons.upload_file),
      label: Text(apk?.name ?? 'Choose signed APK'),
    );
    final publishButton = FilledButton.icon(
      onPressed: busy ? null : publish,
      icon: const Icon(Icons.publish),
      label: Text(busy ? 'Uploading & publishing…' : 'Publish update'),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide) ...[
              const SizedBox(
                width: 200,
                child: AdminIllustration('release', height: 210),
              ),
              const SizedBox(width: 20),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Upload new release',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: codeField),
                        const SizedBox(width: 12),
                        Expanded(child: nameField),
                        const SizedBox(width: 12),
                        Expanded(child: notesField),
                      ],
                    )
                  else ...[
                    codeField,
                    const SizedBox(height: 12),
                    nameField,
                    notesField,
                  ],
                  const SizedBox(height: 8),
                  AdminReleaseAudience(
                    gateway: SupabaseAdminNotificationGateway(widget.client),
                    enabled: !busy,
                    onChanged: (value) => setState(() => recipient = value),
                  ),
                  const SizedBox(height: 12),
                  if (wide)
                    Row(
                      children: [
                        Expanded(child: choose),
                        const SizedBox(width: 12),
                        Expanded(child: publishButton),
                      ],
                    )
                  else ...[
                    choose,
                    const SizedBox(height: 12),
                    publishButton,
                  ],
                  if (busy) const LinearProgressIndicator(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AdminDestinationScaffold(
    destination: AdminDestination.releases,
    appBar: AdminPageBar(
      title: 'App releases',
      icon: Icons.rocket_launch,
      desktop: adminWideHeader(context),
      subtitle: 'Manage app updates and release history.',
      actions: [
        IconButton(
          onPressed: busy
              ? null
              : () => setState(() {
                  load();
                  referralRevision++;
                }),
          tooltip: 'Refresh releases',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width >= 1100 ? 1600 : 900,
        ),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Distribute Android updates',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a signed universal APK with a higher version code. Users receive an update notification and confirm installation in Android.',
            ),
            const SizedBox(height: 20),
            AdminReferralDownloadCard(
              key: ValueKey(referralRevision),
              gateway: ReferralDownloadGateway(widget.client),
              canEdit: widget.canEdit,
            ),
            if (widget.canEdit)
              LayoutBuilder(
                builder: (context, constraints) =>
                    releaseForm(constraints.maxWidth >= 1050),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Published releases',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: releases,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Unable to load releases. Check migration and access.',
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No releases published yet.'),
                  );
                }
                return Column(
                  children: [
                    for (final row in snapshot.data!)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.android),
                          title: Text(
                            '${row['version_name']} · build ${row['version_code']}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row['target_user_id'] == null
                                    ? 'All active users'
                                    : 'Specific user · ${row['target_user_id']}',
                              ),
                              Text('${row['notes']}\n${row['created_at']}'),
                              if (widget.canEdit &&
                                  row['target_user_id'] != null)
                                AdminReleasePromoteButton(
                                  versionName: row['version_name'] as String,
                                  versionCode: row['version_code'] as int,
                                  enabled: !busy,
                                  onConfirm: () => promote(row['id'] as String),
                                ),
                              AdminReleaseActivity(
                                client: widget.client,
                                releaseId: row['id'] as String,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class AdminReleasePromoteButton extends StatelessWidget {
  const AdminReleasePromoteButton({
    super.key,
    required this.versionName,
    required this.versionCode,
    required this.enabled,
    required this.onConfirm,
  });
  final String versionName;
  final int versionCode;
  final bool enabled;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: !enabled
        ? null
        : () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Publish to all users?'),
                content: Text(
                  'Version $versionName (build $versionCode) will be offered to all active users using the same APK.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Publish to all'),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) onConfirm();
          },
    icon: const Icon(Icons.public),
    label: const Text('Publish to all users'),
  );
}
