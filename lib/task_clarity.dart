import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_localization.dart';

String ct(BuildContext c, String en, String ml) => userText(c, en, ml);

class MonthlySpending extends StatelessWidget {
  const MonthlySpending({super.key, required this.client});
  final SupabaseClient client;
  Future<Map?> load() async {
    final f = await client.rpc('user_feature_settings') as Map;
    return f['spending_insights'] == true
        ? await client.rpc('monthly_spending_insights') as Map
        : null;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map?>(
    future: load(),
    builder: (c, s) {
      final v = s.data;
      if (v == null) return const SizedBox.shrink();
      return Card(
        child: ListTile(
          title: Text(
            ct(c, 'Monthly coin spending (UTC)', 'ഈ മാസത്തെ coin ചെലവ് (UTC)'),
          ),
          subtitle: Text(
            '${ct(c, 'Campaign reservations', 'Campaign മാറ്റിവച്ചത്')}: ${v['campaign']} · ${ct(c, 'Transfers', 'Transfers')}: ${v['transfer']} · ${ct(c, 'Other', 'മറ്റുള്ളവ')}: ${v['other']} · ${ct(c, 'Refunds', 'തിരികെ ലഭിച്ചത്')}: ${v['refund']}',
          ),
        ),
      );
    },
  );
}

class SavedTaskNote extends StatefulWidget {
  const SavedTaskNote({
    super.key,
    required this.client,
    required this.campaignId,
    this.enabledOverride,
  });
  final SupabaseClient client;
  final String campaignId;
  final bool? enabledOverride;
  @override
  State<SavedTaskNote> createState() => _SavedTaskNoteState();
}

class _SavedTaskNoteState extends State<SavedTaskNote> {
  bool enabled = false, loadingNote = false;
  String? note;
  @override
  void initState() {
    super.initState();
    if (widget.enabledOverride != null) {
      enabled = widget.enabledOverride!;
    } else {
      load();
    }
  }

  @override
  void didUpdateWidget(covariant SavedTaskNote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabledOverride != oldWidget.enabledOverride &&
        widget.enabledOverride != null) {
      enabled = widget.enabledOverride!;
    }
  }

  Future<void> load() async {
    try {
      final f = await widget.client.rpc('user_feature_settings') as Map;
      if (f['saved_task_notes'] != true) return;
      if (mounted) setState(() => enabled = true);
    } catch (_) {}
  }

  Future<void> edit() async {
    setState(() => loadingNote = true);
    try {
      note = await widget.client.rpc(
        'user_saved_task_note',
        params: {'p_campaign': widget.campaignId},
      ) as String?;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ct(context, 'Unable to load note.', 'കുറിപ്പ് ലഭ്യമല്ല.'),
            ),
          ),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => loadingNote = false);
    }
    if (!mounted) return;
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _EntryDialog(
        initial: note,
        title: ct(context, 'Private task note', 'സ്വകാര്യ task കുറിപ്പ്'),
        hint: ct(
          context,
          'Other users cannot see this note. Unsaving removes it.',
          'മറ്റു users ഈ കുറിപ്പ് കാണില്ല. Unsave ചെയ്താൽ കുറിപ്പ് നീങ്ങും.',
        ),
      ),
    );
    if (value == null || !mounted) return;
    try {
      await widget.client.rpc(
        'set_saved_task_note',
        params: {'p_campaign': widget.campaignId, 'p_note': value},
      );
      if (mounted) {
        setState(() => note = value.trim().isEmpty ? null : value.trim());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ct(
                context,
                'Unable to save note.',
                'കുറിപ്പ് save ചെയ്യാനായില്ല.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => enabled
      ? TextButton.icon(
          onPressed: loadingNote ? null : edit,
          icon: const Icon(Icons.note_outlined),
          label: Text(ct(context, 'Task note', 'Task കുറിപ്പ്')),
        )
      : const SizedBox.shrink();
}

class TaskInstructionsEditor extends StatefulWidget {
  const TaskInstructionsEditor({
    super.key,
    required this.client,
    required this.campaignId,
    required this.initial,
  });
  final SupabaseClient client;
  final String campaignId;
  final String? initial;
  @override
  State<TaskInstructionsEditor> createState() => _TaskInstructionsEditorState();
}

class _TaskInstructionsEditorState extends State<TaskInstructionsEditor> {
  bool enabled = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final f = await widget.client.rpc('user_feature_settings') as Map;
      if (mounted) setState(() => enabled = f['task_instructions'] == true);
    } catch (_) {}
  }

  Future<void> edit() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _EntryDialog(
        initial: widget.initial,
        title: ct(context, 'Task instructions', 'Task നിർദ്ദേശങ്ങൾ'),
        hint: ct(
          context,
          'Describe the screenshot needed',
          'ആവശ്യമായ screenshot വിവരിക്കുക',
        ),
      ),
    );
    if (text == null || !mounted) return;
    try {
      await widget.client.rpc(
        'set_campaign_instructions',
        params: {'p_campaign': widget.campaignId, 'p_text': text},
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ct(
                context,
                'Unable to save instructions.',
                'നിർദ്ദേശങ്ങൾ save ചെയ്യാനായില്ല.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => enabled
      ? TextButton(
          onPressed: edit,
          child: Text(
            ct(context, 'Edit task instructions', 'Task നിർദ്ദേശങ്ങൾ മാറ്റുക'),
          ),
        )
      : const SizedBox.shrink();
}

class PreferredTasksSettings extends StatefulWidget {
  const PreferredTasksSettings({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<PreferredTasksSettings> createState() => _PreferredTasksSettingsState();
}

class _PreferredTasksSettingsState extends State<PreferredTasksSettings> {
  bool enabled = false, busy = false;
  final selected = <String>{};
  String? message;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final f = await widget.client.rpc('user_feature_settings') as Map;
      if (f['preferred_task_alerts'] != true) return;
      final rows = await widget.client.rpc('user_preferred_tasks') as List;
      if (mounted) {
        setState(() {
          enabled = true;
          selected.addAll(rows.cast<String>());
        });
      }
    } catch (_) {}
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await widget.client.rpc(
        'set_preferred_tasks',
        params: {'p_categories': selected.toList()},
      );
      if (mounted) {
        setState(() => message = ct(context, 'Saved.', 'സേവ് ചെയ്തു.'));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = ct(
            context,
            'Unable to save categories.',
            'Categories save ചെയ്യാനായില്ല.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => !enabled
      ? const SizedBox.shrink()
      : Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ct(context, 'New task alerts', 'പുതിയ task അറിയിപ്പുകൾ'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  ct(
                    context,
                    'Choose categories; alerts follow your task notification settings.',
                    'Categories തിരഞ്ഞെടുക്കുക; task notification settings ബാധകമാണ്.',
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final cat in ['follow', 'like', 'comment', 'share'])
                      FilterChip(
                        label: Text(cat),
                        selected: selected.contains(cat),
                        onSelected: busy
                            ? null
                            : (value) => setState(() {
                                if (value) {
                                  selected.add(cat);
                                } else {
                                  selected.remove(cat);
                                }
                              }),
                      ),
                  ],
                ),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(ct(context, 'Save', 'സേവ് ചെയ്യുക')),
                ),
                if (message != null) Text(message!),
              ],
            ),
          ),
        );
}

class UserReportTracking extends StatelessWidget {
  const UserReportTracking({super.key, required this.client});
  final SupabaseClient client;
  Future<List?> load() async {
    final f = await client.rpc('user_feature_settings') as Map;
    return f['report_tracking'] == true
        ? await client.rpc('user_campaign_reports') as List
        : null;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List?>(
    future: load(),
    builder: (c, s) {
      final rows = s.data;
      if (rows == null) return const SizedBox.shrink();
      return Card(
        child: ExpansionTile(
          title: Text(ct(c, 'My campaign reports', 'എന്റെ campaign reports')),
          children: [
            if (rows.isEmpty)
              ListTile(title: Text(ct(c, 'No reports yet.', 'Reports ഇല്ല.'))),
            for (final r in rows)
              ListTile(
                title: Text(
                  '${ct(c, 'Campaign', 'Campaign')}: ${r['campaign_link']}',
                ),
                subtitle: Text(
                  '${r['status'] == 'open' ? ct(c, 'Under review', 'പരിശോധനയിൽ') : ct(c, 'Resolved', 'പരിശോധിച്ചു')} · ${r['created_at']}',
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _EntryDialog extends StatefulWidget {
  const _EntryDialog({
    required this.initial,
    required this.title,
    required this.hint,
  });
  final String? initial;
  final String title, hint;
  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initial,
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: controller,
      maxLength: 1000,
      maxLines: 4,
      decoration: InputDecoration(hintText: widget.hint),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(ct(context, 'Cancel', 'റദ്ദാക്കുക')),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: Text(ct(context, 'Save', 'സേവ് ചെയ്യുക')),
      ),
    ],
  );
}
