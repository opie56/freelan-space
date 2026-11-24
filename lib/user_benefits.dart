import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_localization.dart';

Future<bool> benefitEnabled(SupabaseClient client, String key) async {
  final result = await client.rpc('user_feature_settings');
  return (result as Map)[key] == true;
}

class WeeklyCoinSummary extends StatelessWidget {
  const WeeklyCoinSummary({super.key, required this.client});
  final SupabaseClient client;
  Future<Map<String, dynamic>?> load() async {
    if (!await benefitEnabled(client, 'coin_summary')) return null;
    return Map<String, dynamic>.from(
      await client.rpc('user_weekly_coin_summary') as Map,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: load(),
    builder: (context, snapshot) {
      final data = snapshot.data;
      if (data == null) return const SizedBox.shrink();
      return Card(
        child: ListTile(
          leading: const Icon(Icons.calendar_today_outlined),
          title: Text(
            userText(context, 'This week’s coins', 'ഈ ആഴ്ചയിലെ coins'),
          ),
          subtitle: Text(
            '${userText(context, 'Received', 'ലഭിച്ചത്')}: ${data['earned']}  ·  ${userText(context, 'Spent', 'ചെലവായത്')}: ${data['spent']} (UTC)',
          ),
        ),
      );
    },
  );
}

class CampaignInsights extends StatelessWidget {
  const CampaignInsights({
    super.key,
    required this.client,
    required this.campaignId,
  });
  final SupabaseClient client;
  final String campaignId;
  Future<Map<String, dynamic>?> load() async {
    if (!await benefitEnabled(client, 'campaign_insights')) return null;
    return Map<String, dynamic>.from(
      await client.rpc(
        'user_campaign_insights',
        params: {'p_campaign': campaignId},
      ) as Map,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: load(),
    builder: (context, snapshot) {
      final data = snapshot.data;
      if (data == null) return const SizedBox.shrink();
      final approved = (data['approved'] as num).toInt();
      final rejected = (data['rejected'] as num).toInt();
      final total = approved + rejected;
      final seconds = data['average_review_seconds'] as num?;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '${userText(context, 'Approval rate', 'Approval നിരക്ക്')}: ${total == 0 ? '—' : '${(approved * 100 / total).toStringAsFixed(0)}%'} ($total) · ${userText(context, 'Average review', 'ശരാശരി review')}: ${seconds == null ? '—' : '${(seconds / 3600).toStringAsFixed(1)} h'}',
        ),
      );
    },
  );
}

class NotificationPreferences extends StatefulWidget {
  const NotificationPreferences({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<NotificationPreferences> createState() =>
      _NotificationPreferencesState();
}

class _NotificationPreferencesState extends State<NotificationPreferences> {
  Map<String, dynamic>? values;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      if (!await benefitEnabled(widget.client, 'notification_controls')) return;
      final result = await widget.client.rpc('user_notification_preferences');
      if (mounted) {
        setState(() {
          values = Map<String, dynamic>.from(result as Map);
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = userText(
            context,
            'Could not load notification preferences.',
            'Notification settings ലഭിച്ചില്ല.',
          ),
        );
      }
    }
  }

  Future<void> change(String key, bool value) async {
    final next = {...values!, key: value};
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.client.rpc(
        'set_user_notification_preferences',
        params: {
          'p_task': next['task_updates'],
          'p_coin': next['coin_updates'],
          'p_referral': next['referral_updates'],
        },
      );
      if (mounted) setState(() => values = next);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = userText(
            context,
            'Could not save preferences.',
            'Settings save ചെയ്യാനായില്ല.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (values == null && error == null) return const SizedBox.shrink();
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(
              userText(
                context,
                'Notification categories',
                'Notification വിഭാഗങ്ങൾ',
              ),
            ),
            subtitle: Text(
              userText(
                context,
                'Controls future in-app and push notifications.',
                'ഇനി വരുന്ന in-app, push notifications നിയന്ത്രിക്കുക.',
              ),
            ),
          ),
          if (error != null)
            ListTile(
              title: Text(error!),
              trailing: TextButton(
                onPressed: load,
                child: Text(userText(context, 'Retry', 'വീണ്ടും ശ്രമിക്കുക')),
              ),
            ),
          if (values != null)
            for (final e in <(String, String, String)>[
              (
                'task_updates',
                'Task updates and review reminders',
                'Task updates, review reminders',
              ),
              ('coin_updates', 'Coin updates', 'Coin updates'),
              ('referral_updates', 'Referral rewards', 'Referral rewards'),
            ])
              SwitchListTile(
                title: Text(userText(context, e.$2, e.$3)),
                value: values![e.$1] == true,
                onChanged: busy ? null : (v) => change(e.$1, v),
              ),
        ],
      ),
    );
  }
}

class GuidedFirstTask extends StatefulWidget {
  const GuidedFirstTask({
    super.key,
    required this.client,
    required this.userId,
    required this.onBrowse,
  });
  final SupabaseClient client;
  final String userId;
  final VoidCallback onBrowse;
  @override
  State<GuidedFirstTask> createState() => _GuidedFirstTaskState();
}

class _GuidedFirstTaskState extends State<GuidedFirstTask> {
  bool visible = false;
  String get storageKey => 'guided_first_task_${widget.userId}';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = await benefitEnabled(widget.client, 'guided_task');
      if (mounted) {
        setState(
          () => visible = enabled && !(prefs.getBool(storageKey) ?? false),
        );
      }
    } catch (_) {
      /* Other dashboard functions remain available. */
    }
  }

  Future<void> dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(storageKey, true);
    if (mounted) setState(() => visible = false);
  }

  @override
  Widget build(BuildContext context) => !visible
      ? const SizedBox.shrink()
      : Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userText(context, 'Your first task', 'നിങ്ങളുടെ ആദ്യ task'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  userText(
                    context,
                    '1. Choose a task.\n2. Complete it and submit your Instagram username and a relevant screenshot.\n3. The owner or an administrator reviews it; coins are credited after approval.',
                    '1. ഒരു task തിരഞ്ഞെടുക്കുക.\n2. Task പൂർത്തിയാക്കി Instagram username-ഉം screenshot-ഉം സമർപ്പിക്കുക.\n3. ഉടമയോ admin-ഓ പരിശോധിക്കും; അംഗീകരിച്ചാൽ coins ലഭിക്കും.',
                  ),
                ),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: widget.onBrowse,
                      child: Text(
                        userText(context, 'Browse tasks', 'Tasks കാണുക'),
                      ),
                    ),
                    TextButton(
                      onPressed: dismiss,
                      child: Text(userText(context, 'Dismiss', 'അടയ്ക്കുക')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
}
