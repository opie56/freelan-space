import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_localization.dart';

String t(BuildContext c, String en, String ml) => userText(c, en, ml);

class RewardsAndGoal extends StatefulWidget {
  const RewardsAndGoal({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<RewardsAndGoal> createState() => _RewardsAndGoalState();
}

class _RewardsAndGoalState extends State<RewardsAndGoal> {
  Map<String, dynamic>? flags, rewards, goal;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final f = Map<String, dynamic>.from(
        await widget.client.rpc('user_feature_settings') as Map,
      );
      Map<String, dynamic>? r, g;
      if (f['daily_bonus'] == true || f['achievement_badges'] == true) {
        r = Map<String, dynamic>.from(
          await widget.client.rpc('user_reward_status') as Map,
        );
      }
      if (f['coin_goal'] == true) {
        final value = await widget.client.rpc('user_coin_goal');
        if (value != null) g = Map<String, dynamic>.from(value as Map);
      }
      if (mounted) {
        setState(() {
          flags = f;
          rewards = r;
          goal = g;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t(
            context,
            'Could not load benefits.',
            'Benefits ലഭിച്ചില്ല.',
          ),
        );
      }
    }
  }

  Future<void> claim(String name, [int? milestone]) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.client.rpc(
        name,
        params: milestone == null ? null : {'p_milestone': milestone},
      );
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(context, 'Bonus credited.', 'Bonus ലഭിച്ചു.')),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t(
            context,
            'Bonus unavailable or already claimed.',
            'Bonus ലഭ്യമല്ല അല്ലെങ്കിൽ ഇതിനകം ലഭിച്ചു.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editGoal() async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _GoalDialog(initial: goal?['target'] as int?),
    );
    if (result == null || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.client.rpc(
        'set_user_coin_goal',
        params: {'p_target': result == 0 ? null : result},
      );
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t(
            context,
            'Could not save goal.',
            'Goal save ചെയ്യാനായില്ല.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (flags == null && error == null) return const SizedBox.shrink();
    final f = flags ?? {};
    final approved = (rewards?['approved'] as num?)?.toInt() ?? 0;
    final claimed = (rewards?['claimed_badges'] as List?) ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null)
              Row(
                children: [
                  Expanded(child: Text(error!)),
                  TextButton(
                    onPressed: busy ? null : load,
                    child: Text(t(context, 'Retry', 'വീണ്ടും ശ്രമിക്കുക')),
                  ),
                ],
              ),
            if (f['daily_bonus'] == true && rewards != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t(context, 'Daily check-in', 'Daily check-in')),
                subtitle: Text(
                  '${rewards!['daily_amount']} ${t(context, 'coins · resets at 00:00 UTC', 'coins · 00:00 UTC-ൽ പുതുക്കും')}',
                ),
                trailing: FilledButton(
                  onPressed:
                      busy ||
                          rewards!['daily_claimed'] == true ||
                          rewards!['daily_amount'] == 0
                      ? null
                      : () => claim('claim_daily_bonus'),
                  child: Text(
                    rewards!['daily_claimed'] == true
                        ? t(context, 'Claimed', 'ലഭിച്ചു')
                        : t(context, 'Claim', 'നേടുക'),
                  ),
                ),
              ),
            if (f['achievement_badges'] == true && rewards != null) ...[
              Text(
                '${t(context, 'Approved tasks', 'അംഗീകരിച്ച tasks')}: $approved',
              ),
              for (final milestone in [5, 10, 25])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    approved >= milestone
                        ? Icons.workspace_premium
                        : Icons.lock_outline,
                  ),
                  title: Text(
                    '$milestone ${t(context, 'approved tasks', 'approved tasks')}',
                  ),
                  subtitle: Text(
                    '${t(context, 'Bonus', 'Bonus')}: ${rewards!['badge_$milestone']} coins',
                  ),
                  trailing:
                      approved >= milestone &&
                          (rewards!['badge_$milestone'] as num) > 0 &&
                          !claimed.contains(milestone)
                      ? TextButton(
                          onPressed: busy
                              ? null
                              : () => claim('claim_badge_bonus', milestone),
                          child: Text(t(context, 'Claim', 'നേടുക')),
                        )
                      : null,
                ),
            ],
            if (f['coin_goal'] == true)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t(context, 'Coin goal', 'Coin goal')),
                subtitle: Text(
                  goal == null
                      ? t(
                          context,
                          'Set a target for your available balance.',
                          'ലഭ്യമായ balance-ന് ഒരു ലക്ഷ്യം നൽകുക.',
                        )
                      : '${goal!['balance']} / ${goal!['target']} coins',
                ),
                trailing: TextButton(
                  onPressed: busy ? null : editGoal,
                  child: Text(t(context, 'Edit', 'മാറ്റുക')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({this.initial});
  final int? initial;
  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final controller = TextEditingController(
    text: widget.initial?.toString() ?? '',
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(t(context, 'Coin goal', 'Coin goal')),
    content: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 9,
      decoration: InputDecoration(
        labelText: t(context, 'Target coins', 'ലക്ഷ്യം coins'),
      ),
    ),
    actions: [
      if (widget.initial != null)
        TextButton(
          onPressed: () => Navigator.pop(context, 0),
          child: Text(t(context, 'Remove', 'നീക്കുക')),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t(context, 'Cancel', 'റദ്ദാക്കുക')),
      ),
      FilledButton(
        onPressed: () {
          final value = int.tryParse(controller.text);
          if (value != null && value > 0 && value <= 100000000) {
            Navigator.pop(context, value);
          }
        },
        child: Text(t(context, 'Save', 'സേവ് ചെയ്യുക')),
      ),
    ],
  );
}

class CampaignDraftControls extends StatefulWidget {
  const CampaignDraftControls({
    super.key,
    required this.client,
    required this.current,
    required this.restore,
  });
  final SupabaseClient client;
  final Map<String, dynamic> Function() current;
  final void Function(Map<String, dynamic>) restore;
  @override
  State<CampaignDraftControls> createState() => _CampaignDraftControlsState();
}

class _CampaignDraftControlsState extends State<CampaignDraftControls> {
  bool enabled = false, busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final f = await widget.client.rpc('user_feature_settings') as Map;
      if (mounted) setState(() => enabled = f['campaign_drafts'] == true);
    } catch (_) {}
  }

  Future<void> save() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final data = widget.current();
      await widget.client.rpc(
        'save_campaign_draft',
        params: {
          'p_id': null,
          'p_kind': data['kind'],
          'p_link': data['link'],
          'p_username': data['username'],
          'p_count': data['count'],
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(context, 'Draft saved.', 'Draft save ചെയ്തു.')),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                context,
                'Unable to save draft. Check the task count and draft limit.',
                'Draft save ചെയ്യാനായില്ല. Task count, draft limit പരിശോധിക്കുക.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open() async {
    try {
      final rows = await widget.client.rpc('user_campaign_drafts') as List;
      if (!mounted) return;
      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text(t(context, 'Saved drafts', 'Saved drafts'))),
              if (rows.isEmpty)
                ListTile(
                  title: Text(t(context, 'No drafts yet.', 'Drafts ഇല്ല.')),
                ),
              for (final row in rows)
                ListTile(
                  title: Text('${row['kind']} · ${row['username']}'),
                  subtitle: Text('${row['link']}'),
                  onTap: () => Navigator.pop(
                    context,
                    Map<String, dynamic>.from(row as Map),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await widget.client.rpc(
                        'delete_campaign_draft',
                        params: {'p_id': row['id']},
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ),
            ],
          ),
        ),
      );
      if (picked != null && mounted) widget.restore(picked);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(context, 'Unable to load drafts.', 'Drafts ലഭ്യമല്ല.'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => !enabled
      ? const SizedBox.shrink()
      : Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : save,
              icon: const Icon(Icons.save_outlined),
              label: Text(t(context, 'Save draft', 'Draft save ചെയ്യുക')),
            ),
            TextButton(
              onPressed: busy ? null : open,
              child: Text(t(context, 'Open drafts', 'Drafts തുറക്കുക')),
            ),
          ],
        );
}

class SupportReferenceButton extends StatefulWidget {
  const SupportReferenceButton({
    super.key,
    required this.client,
    required this.kind,
    required this.id,
    this.enabledOverride,
  });
  final SupabaseClient client;
  final String kind, id;
  final bool? enabledOverride;
  @override
  State<SupportReferenceButton> createState() => _SupportReferenceButtonState();
}

class _SupportReferenceButtonState extends State<SupportReferenceButton> {
  bool enabled = false;
  @override
  void initState() {
    super.initState();
    if (widget.enabledOverride != null) {
      enabled = widget.enabledOverride!;
    } else {
      load();
    }
  }

  Future<void> load() async {
    try {
      final f = await widget.client.rpc('user_feature_settings') as Map;
      if (mounted) setState(() => enabled = f['support_reference'] == true);
    } catch (_) {}
  }

  Future<void> open() async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => const _SupportMessageDialog(),
    );
    if (message == null || !mounted) return;
    try {
      await widget.client.rpc(
        'support_reference_ticket',
        params: {
          'p_kind': widget.kind,
          'p_id': widget.id,
          'p_message': message,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                context,
                'Sent. Follow the reply in Support.',
                'അയച്ചു. മറുപടി Support-ൽ കാണാം.',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                context,
                'Unable to send support request.',
                'Support request അയയ്ക്കാനായില്ല.',
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
          onPressed: open,
          icon: const Icon(Icons.support_agent),
          label: Text(t(context, 'Get help', 'സഹായം')),
        )
      : const SizedBox.shrink();
}

class _SupportMessageDialog extends StatefulWidget {
  const _SupportMessageDialog();
  @override
  State<_SupportMessageDialog> createState() => _SupportMessageDialogState();
}

class _SupportMessageDialogState extends State<_SupportMessageDialog> {
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: Text(t(c, 'Contact support', 'Support-നെ ബന്ധപ്പെടുക')),
    content: TextField(
      controller: text,
      maxLines: 4,
      maxLength: 1500,
      decoration: InputDecoration(
        labelText: t(c, 'Describe the issue', 'പ്രശ്നം വിവരിക്കുക'),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: Text(t(c, 'Cancel', 'റദ്ദാക്കുക')),
      ),
      FilledButton(
        onPressed: () {
          if (text.text.trim().isNotEmpty) Navigator.pop(c, text.text.trim());
        },
        child: Text(t(c, 'Send', 'അയയ്ക്കുക')),
      ),
    ],
  );
}

class WalletStatementButton extends StatefulWidget {
  const WalletStatementButton({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<WalletStatementButton> createState() => _WalletStatementButtonState();
}

class _WalletStatementButtonState extends State<WalletStatementButton> {
  bool enabled = false, busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final f = await widget.client.rpc('user_feature_settings') as Map;
      if (mounted) setState(() => enabled = f['wallet_statement'] == true);
    } catch (_) {}
  }

  Future<void> export() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      ),
    );
    if (range == null || !mounted) return;
    final start = DateTime.utc(
          range.start.year,
          range.start.month,
          range.start.day,
        ),
        end = DateTime.utc(range.end.year, range.end.month, range.end.day + 1);
    if (end.difference(start).inDays > 366) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              context,
              'Select at most 366 days.',
              '366 ദിവസം വരെ തിരഞ്ഞെടുക്കുക.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final rows = await loadWalletStatement(widget.client, start, end);
      final csv = walletStatementCsv(rows);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(csv),
              name: 'wallet_statement.csv',
              mimeType: 'text/csv',
            ),
          ],
          fileNameOverrides: ['wallet_statement.csv'],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                context,
                'Unable to export statement.',
                'Statement export ചെയ്യാനായില്ല.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => enabled
      ? OutlinedButton.icon(
          onPressed: busy ? null : export,
          icon: const Icon(Icons.file_download_outlined),
          label: Text(
            t(context, 'Export statement', 'Statement export ചെയ്യുക'),
          ),
        )
      : const SizedBox.shrink();
}

Future<List<Map<String, dynamic>>> loadWalletStatement(
  SupabaseClient client,
  DateTime start,
  DateTime end,
) async {
  final rows = <Map<String, dynamic>>[];
  for (var offset = 0; offset <= 100000; offset += 200) {
    final page = await client.rpc(
      'wallet_statement',
      params: {
        'p_from': start.toIso8601String(),
        'p_to': end.toIso8601String(),
        'p_offset': offset,
      },
    ) as List;
    rows.addAll(page.map((r) => Map<String, dynamic>.from(r as Map)));
    if (page.length < 200) break;
    if (offset == 100000) throw StateError('Statement too large');
  }
  return rows;
}

String walletStatementCsv(List<Map<String, dynamic>> rows) {
  String cell(Object? value) {
    var v = '${value ?? ''}';
    if (value is! num && RegExp(r'^[=+@\-]').hasMatch(v)) v = "'$v";
    return '"${v.replaceAll('"', '""')}"';
  }

  final csv = StringBuffer('Date UTC,Amount,Reason,Reference ID\r\n');
  for (final row in rows) {
    csv.write(
      [
        cell(row['created_at']),
        cell(row['amount']),
        cell(row['reason']),
        cell(row['reference_id']),
      ].join(','),
    );
    csv.write('\r\n');
  }
  return csv.toString();
}
