import 'engagement_benefits.dart';
import 'admin_coupons.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUserBenefitsPage extends StatefulWidget {
  const AdminUserBenefitsPage({
    super.key,
    required this.client,
    required this.canEdit,
  });
  final SupabaseClient client;
  final bool canEdit;
  @override
  State<AdminUserBenefitsPage> createState() => _AdminUserBenefitsPageState();
}

class _AdminUserBenefitsPageState extends State<AdminUserBenefitsPage> {
  static const names = {
    'task_search': 'Task search and sorting',
    'review_reminders': 'Pending review reminders',
    'submission_appeals': 'Submission appeals',
    'coin_summary': 'Weekly coin summary',
    'campaign_insights': 'Campaign insights',
    'notification_controls': 'Notification preferences',
    'guided_task': 'Guided first task',
    'daily_bonus': 'Daily check-in bonus',
    'achievement_badges': 'Achievement badges',
    'campaign_drafts': 'Campaign drafts',
    'coin_goal': 'Coin goal',
    'wallet_statement': 'Wallet statement',
    'saved_task_alerts': 'Saved task alerts',
    'support_reference': 'Support references',
    'login_alerts': 'Login alerts',
    'referral_links': 'Referral links',
    'notification_shortcuts': 'Notification shortcuts',
    'campaign_pause': 'Campaign pause and resume',
    'saved_filters': 'Saved task filters',
    'bonus_coupons': 'Bonus coupons',
    'quiet_hours': 'Notification quiet hours',
    'device_sessions': 'Device sessions',
    'offline_view': 'Offline view',
    'weekly_challenges': 'Weekly challenges',
    'resubmit_help': 'Resubmission help',
    'saved_task_reminders': 'Saved task reminders',
    'monthly_coin_insights': 'Monthly coin insights',
    'campaign_copy': 'Campaign copy',
    'campaign_progress_alerts': 'Campaign progress alerts',
    'low_balance_alerts': 'Low balance alerts',
    'editable_help': 'Editable help articles',
    'task_instructions': 'Task instructions',
    'screenshot_editing': 'Screenshot crop and blur',
    'submission_waiting': 'Submission waiting time',
    'report_tracking': 'Report tracking',
    'notification_filters': 'Notification filters',
    'saved_task_notes': 'Private task notes',
    'preferred_task_alerts': 'Preferred task alerts',
    'spending_insights': 'Coin spending insights',
  };
  Map<String, dynamic>? settings;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await widget.client.rpc('admin_user_feature_settings');
      if (mounted) {
        setState(() {
          settings = Map<String, dynamic>.from(value as Map);
          error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to load feature controls.');
    }
  }

  Future<void> change(String key, bool enabled) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.client.rpc(
        'admin_set_user_feature',
        params: {'p_key': key, 'p_enabled': enabled},
      );
      await load();
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to save. Please retry.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('User feature controls')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Enable or disable each feature for users. Reminders require the scheduled database job.',
            ),
            if (error != null)
              ListTile(
                title: Text(error!),
                trailing: TextButton(
                  onPressed: load,
                  child: const Text('Retry'),
                ),
              ),
            if (settings == null && error == null)
              const Center(child: CircularProgressIndicator()),
            if (settings != null)
              for (final entry in names.entries)
                SwitchListTile(
                  title: Text(entry.value),
                  value: settings![entry.key] == true,
                  onChanged: widget.canEdit && !busy
                      ? (value) => change(entry.key, value)
                      : null,
                ),
            AdminEngagementSettings(
              client: widget.client,
              canEdit: widget.canEdit,
            ),
            AdminCoupons(client: widget.client, canEdit: widget.canEdit),
            BenefitRewardSettings(
              client: widget.client,
              canEdit: widget.canEdit,
            ),
          ],
        ),
      ),
    ),
  );
}

class BenefitRewardSettings extends StatefulWidget {
  const BenefitRewardSettings({
    super.key,
    required this.client,
    required this.canEdit,
  });
  final SupabaseClient client;
  final bool canEdit;
  @override
  State<BenefitRewardSettings> createState() => _BenefitRewardSettingsState();
}

class _BenefitRewardSettingsState extends State<BenefitRewardSettings> {
  static const labels = {
    'daily_amount': 'Coins per daily check-in',
    'daily_limit': 'Maximum daily bonus coins (UTC)',
    'badge_5': 'Bonus for 5 approvals',
    'badge_10': 'Bonus for 10 approvals',
    'badge_25': 'Bonus for 25 approvals',
  };
  final values = <String, TextEditingController>{};
  bool loading = true, busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    for (final key in labels.keys) {
      values[key] = TextEditingController();
    }
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.client.rpc('admin_benefit_rewards') as Map;
      if (!mounted) return;
      for (final key in labels.keys) {
        values[key]!.text = '${result[key]}';
      }
      setState(() {
        loading = false;
        message = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          message = 'Unable to load reward settings.';
        });
      }
    }
  }

  Future<void> save() async {
    final parsed = {
      for (final entry in values.entries)
        entry.key: int.tryParse(entry.value.text),
    };
    if (parsed.values.any((v) => v == null || v < 0) ||
        parsed['daily_limit']! > 1000000 ||
        labels.keys
            .where((k) => k != 'daily_limit')
            .any((k) => parsed[k]! > 10000)) {
      setState(() => message = 'Enter valid whole numbers.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.client.rpc(
        'admin_set_benefit_rewards',
        params: {
          for (final entry in parsed.entries) 'p_${entry.key}': entry.value,
        },
      );
      if (mounted) setState(() => message = 'Reward settings saved.');
    } catch (_) {
      if (mounted) setState(() => message = 'Unable to save reward settings.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    for (final value in values.values) {
      value.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reward amounts',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'The daily cap limits total coins credited to all users per UTC day. Badge bonus 0 disables its coin reward.',
          ),
          if (loading)
            const CircularProgressIndicator()
          else ...[
            for (final entry in labels.entries)
              TextField(
                controller: values[entry.key],
                enabled: widget.canEdit && !busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: entry.value),
              ),
            if (widget.canEdit)
              FilledButton(
                onPressed: busy ? null : save,
                child: const Text('Save reward settings'),
              ),
          ],
          if (message != null) Text(message!),
          if (!loading && message == 'Unable to load reward settings.')
            TextButton(onPressed: load, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
