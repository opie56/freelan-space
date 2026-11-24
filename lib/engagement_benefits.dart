import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_localization.dart';

String et(BuildContext c, String en, String ml) => userText(c, en, ml);

class EngagementOverview extends StatefulWidget {
  const EngagementOverview({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<EngagementOverview> createState() => _EngagementOverviewState();
}

class _EngagementOverviewState extends State<EngagementOverview> {
  Map? flags, challenge, monthly;
  bool busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final f = await widget.client.rpc('user_feature_settings') as Map;
      final c = f['weekly_challenges'] == true
          ? await widget.client.rpc('weekly_challenge_status') as Map
          : null;
      final m = f['monthly_coin_insights'] == true
          ? await widget.client.rpc('monthly_coin_insights') as Map
          : null;
      if (mounted) {
        setState(() {
          flags = f;
          challenge = c;
          monthly = m;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = et(
            context,
            'Unable to load benefits.',
            'Benefits ലഭ്യമല്ല.',
          ),
        );
      }
    }
  }

  Future<void> claim() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final amount = await widget.client.rpc('claim_weekly_challenge');
      await load();
      if (mounted) setState(() => message = '$amount coins');
    } catch (_) {
      if (mounted) {
        setState(
          () => message = et(
            context,
            'Reward unavailable or already claimed.',
            'Reward ലഭ്യമല്ല അല്ലെങ്കിൽ ഉപയോഗിച്ചു.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (flags == null && message == null) return const SizedBox.shrink();
    return Column(
      children: [
        if (challenge != null)
          Card(
            child: ListTile(
              title: Text(et(context, 'Weekly challenge', 'Weekly challenge')),
              subtitle: Text(
                '${challenge!['completed']} / ${challenge!['target']} · ${challenge!['reward']} coins (UTC)',
              ),
              trailing: challenge!['claimed'] == true
                  ? Text(et(context, 'Claimed', 'ലഭിച്ചു'))
                  : TextButton(
                      onPressed:
                          busy ||
                              (challenge!['completed'] as num) <
                                  (challenge!['target'] as num) ||
                              (challenge!['reward'] as num) == 0
                          ? null
                          : claim,
                      child: Text(et(context, 'Claim', 'നേടുക')),
                    ),
            ),
          ),
        if (monthly != null)
          Card(
            child: ListTile(
              title: Text(et(context, 'This month (UTC)', 'ഈ മാസം (UTC)')),
              subtitle: Text(
                '${et(context, 'Tasks', 'Tasks')}: ${monthly!['task']} · ${et(context, 'Referrals', 'Referrals')}: ${monthly!['referral']} · ${et(context, 'Bonuses', 'Bonuses')}: ${monthly!['bonus']} coins',
              ),
            ),
          ),
        if (message != null) Text(message!),
      ],
    );
  }
}

class SavedReminderButton extends StatefulWidget {
  const SavedReminderButton({
    super.key,
    required this.client,
    required this.campaignId,
  });
  final SupabaseClient client;
  final String campaignId;
  @override
  State<SavedReminderButton> createState() => _SavedReminderButtonState();
}

class _SavedReminderButtonState extends State<SavedReminderButton> {
  bool enabled = false, busy = false;
  DateTime? scheduled;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final f = await widget.client.rpc('user_feature_settings') as Map;
      if (f['saved_task_reminders'] != true) return;
      final rows = await widget.client.rpc('user_saved_task_reminders') as List;
      if (mounted) {
        setState(() {
          enabled = true;
          for (final r in rows) {
            if (r['campaign_id'] == widget.campaignId) {
              scheduled = DateTime.tryParse(r['remind_at'] as String)
                  ?.toLocal();
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> save(DateTime? value) async {
    setState(() => busy = true);
    try {
      await widget.client.rpc(
        'set_saved_task_reminder',
        params: {
          'p_campaign': widget.campaignId,
          'p_at': value?.toUtc().toIso8601String(),
        },
      );
      if (mounted) setState(() => scheduled = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              et(
                context,
                'Unable to save reminder.',
                'Reminder save ചെയ്യാനായില്ല.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pick() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      initialDate:
          scheduled != null &&
              scheduled!.isAfter(now) &&
              scheduled!.isBefore(now.add(const Duration(days: 30)))
          ? scheduled!
          : now,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        scheduled ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (t == null || !mounted) return;
    final value = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (!value.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            et(
              context,
              'Choose a future time.',
              'വരാനിരിക്കുന്ന സമയം തിരഞ്ഞെടുക്കുക.',
            ),
          ),
        ),
      );
      return;
    }
    await save(value);
  }

  @override
  Widget build(BuildContext context) => !enabled
      ? const SizedBox.shrink()
      : Wrap(
          children: [
            TextButton.icon(
              onPressed: busy ? null : pick,
              icon: const Icon(Icons.alarm),
              label: Text(
                scheduled == null
                    ? et(context, 'Remind me', 'ഓർമ്മിപ്പിക്കുക')
                    : scheduled!.toString().substring(0, 16),
              ),
            ),
            if (scheduled != null)
              IconButton(
                onPressed: busy ? null : () => save(null),
                tooltip: et(context, 'Remove reminder', 'Reminder നീക്കുക'),
                icon: const Icon(Icons.close),
              ),
          ],
        );
}

class ExtraAlertSettings extends StatefulWidget {
  const ExtraAlertSettings({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<ExtraAlertSettings> createState() => _ExtraAlertSettingsState();
}

class _ExtraAlertSettingsState extends State<ExtraAlertSettings> {
  Map? flags;
  bool progress = true, busy = false;
  final threshold = TextEditingController();
  String? message;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    threshold.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final f = await widget.client.rpc('user_feature_settings') as Map;
      final v = await widget.client.rpc('user_extra_alerts') as Map;
      if (mounted) {
        setState(() {
          flags = f;
          progress = v['progress'] == true;
          threshold.text = v['low_balance']?.toString() ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> save() async {
    final text = threshold.text.trim();
    final n = text.isEmpty ? null : int.tryParse(text);
    if (text.isNotEmpty && (n == null || n < 0 || n > 100000000)) {
      setState(
        () => message = et(
          context,
          'Enter a valid balance.',
          'ശരിയായ balance നൽകുക.',
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await widget.client.rpc(
        'set_user_extra_alerts',
        params: {'p_progress': progress, 'p_low': n},
      );
      if (mounted) {
        setState(() => message = et(context, 'Saved.', 'സേവ് ചെയ്തു.'));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = et(
            context,
            'Unable to save alerts.',
            'Alerts save ചെയ്യാനായില്ല.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = flags;
    if (f == null ||
        (f['campaign_progress_alerts'] != true &&
            f['low_balance_alerts'] != true)) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              et(
                context,
                'Campaign and balance alerts',
                'Campaign, balance alerts',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (f['campaign_progress_alerts'] == true)
              SwitchListTile(
                title: Text(
                  et(context, 'Campaign progress', 'Campaign പുരോഗതി'),
                ),
                value: progress,
                onChanged: busy ? null : (v) => setState(() => progress = v),
              ),
            if (f['low_balance_alerts'] == true)
              TextField(
                controller: threshold,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: et(
                    context,
                    'Alert below this balance (blank to turn off)',
                    'ഈ balance-ന് താഴെ അറിയിക്കുക (off ചെയ്യാൻ ഒഴിവാക്കുക)',
                  ),
                ),
              ),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(et(context, 'Save', 'സേവ് ചെയ്യുക')),
            ),
            if (message != null) Text(message!),
          ],
        ),
      ),
    );
  }
}

class UserHelpArticles extends StatelessWidget {
  const UserHelpArticles({super.key, required this.client});
  final SupabaseClient client;
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: client.rpc('user_help_articles'),
    builder: (c, s) {
      if (!s.hasData || s.data is! List) return const SizedBox.shrink();
      return Column(
        children: [
          for (final row in s.data as List)
            Card(
              child: ExpansionTile(
                title: Text(row['title'] as String),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(row['body'] as String),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class AdminEngagementSettings extends StatefulWidget {
  const AdminEngagementSettings({
    super.key,
    required this.client,
    required this.canEdit,
  });
  final SupabaseClient client;
  final bool canEdit;
  @override
  State<AdminEngagementSettings> createState() =>
      _AdminEngagementSettingsState();
}

class _AdminEngagementSettingsState extends State<AdminEngagementSettings> {
  final target = TextEditingController(),
      reward = TextEditingController(),
      limit = TextEditingController();
  List rows = [];
  String? message;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    target.dispose();
    reward.dispose();
    limit.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final cfg = await widget.client.rpc('admin_weekly_challenge') as Map;
      final articles = await widget.client.rpc('admin_help_articles') as List;
      if (mounted) {
        setState(() {
          target.text = '${cfg['target']}';
          reward.text = '${cfg['reward']}';
          limit.text = '${cfg['weekly_limit']}';
          rows = articles;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Unable to load challenge or help settings.');
      }
    }
  }

  Future<void> saveChallenge() async {
    setState(() => busy = true);
    try {
      await widget.client.rpc(
        'admin_set_weekly_challenge',
        params: {
          'p_target': int.tryParse(target.text),
          'p_reward': int.tryParse(reward.text),
          'p_limit': int.tryParse(limit.text),
        },
      );
      if (mounted) setState(() => message = 'Challenge settings saved.');
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Invalid settings or unable to save.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit([Map? row]) async {
    final title = TextEditingController(text: row?['title'] as String? ?? ''),
        body = TextEditingController(text: row?['body'] as String? ?? '');
    var active = row?['enabled'] as bool? ?? true;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Help article'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  maxLength: 150,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: body,
                  maxLength: 3000,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Answer'),
                ),
                SwitchListTile(
                  title: const Text('Published'),
                  value: active,
                  onChanged: (v) => set(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, {
                'p_id': row?['id'],
                'p_title': title.text,
                'p_body': body.text,
                'p_enabled': active,
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    body.dispose();
    if (result == null || !mounted) return;
    try {
      await widget.client.rpc('admin_save_help', params: result);
      await load();
    } catch (_) {
      if (mounted) setState(() => message = 'Unable to save article.');
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly challenge',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text('Week is Monday–Sunday UTC. Reward 0 disables payouts.'),
          TextField(
            controller: target,
            enabled: widget.canEdit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Approved tasks required',
            ),
          ),
          TextField(
            controller: reward,
            enabled: widget.canEdit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Reward coins'),
          ),
          TextField(
            controller: limit,
            enabled: widget.canEdit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Weekly coin limit'),
          ),
          if (widget.canEdit)
            FilledButton(
              onPressed: busy ? null : saveChallenge,
              child: const Text('Save challenge'),
            ),
          const SizedBox(height: 16),
          Text('Help articles', style: Theme.of(context).textTheme.titleMedium),
          if (widget.canEdit)
            TextButton(
              onPressed: () => edit(),
              child: const Text('Add article'),
            ),
          for (final r in rows)
            ListTile(
              title: Text(r['title'] as String),
              subtitle: Text(r['enabled'] == true ? 'Published' : 'Hidden'),
              onTap: widget.canEdit ? () => edit(r as Map) : null,
            ),
          if (message != null) Text(message!),
        ],
      ),
    ),
  );
}
