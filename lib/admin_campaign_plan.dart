import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_design.dart';
import 'admin_destination.dart';

abstract interface class AdminCampaignPlanGateway {
  Future<Map<String, dynamic>> loadCampaignPlan();
  Future<void> saveCampaignPlan(Map<String, int> settings);
}

class AdminCampaignPlanPage extends StatefulWidget {
  const AdminCampaignPlanPage({
    super.key,
    required this.gateway,
    required this.canEdit,
  });
  final AdminCampaignPlanGateway gateway;
  final bool canEdit;

  @override
  State<AdminCampaignPlanPage> createState() => _AdminCampaignPlanPageState();
}

class _AdminCampaignPlanPageState extends State<AdminCampaignPlanPage> {
  static const fields = {
    'campaign_count': 'Campaigns per window',
    'window_hours': 'Window in hours',
    'base_tasks': 'Tasks per campaign',
    'referral_bonus': 'Extra tasks after first referral',
  };
  final controls = <String, TextEditingController>{};
  bool loading = true, saving = false;
  String? error, saved;

  @override
  void initState() {
    super.initState();
    for (final key in fields.keys) {
      controls[key] = TextEditingController();
    }
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.gateway.loadCampaignPlan();
      if (!mounted) return;
      for (final key in fields.keys) {
        controls[key]!.text = '${data[key]}';
      }
    } catch (_) {
      error = 'Unable to load campaign settings.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    final values = {
      for (final key in fields.keys) key: int.tryParse(controls[key]!.text),
    };
    final count = values['campaign_count'], hours = values['window_hours'];
    final base = values['base_tasks'], bonus = values['referral_bonus'];
    if (count == null ||
        count < 1 ||
        count > 100 ||
        hours == null ||
        hours < 1 ||
        hours > 720 ||
        base == null ||
        base < 1 ||
        base > 100 ||
        bonus == null ||
        bonus < 0 ||
        bonus > 99 ||
        base + bonus > 100) {
      setState(() {
        error = 'Use 1–100 campaigns, 1–720 hours and 1–100 total tasks.';
        saved = null;
      });
      return;
    }
    setState(() {
      saving = true;
      error = null;
      saved = null;
    });
    try {
      await widget.gateway.saveCampaignPlan({
        'campaign_count': count,
        'window_hours': hours,
        'base_tasks': base,
        'referral_bonus': bonus,
      });
      if (mounted) setState(() => saved = 'Campaign plan saved.');
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to save campaign settings.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in controls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdminDestinationScaffold(
    destination: AdminDestination.coins,
    appBar: AdminPageBar(
      title: 'Campaign Limits',
      icon: Icons.speed_outlined,
      desktop: adminWideHeader(context),
      subtitle: 'Configure the Free Plan for future campaigns.',
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (saved != null) Text(saved!),
                  if (error != null || saved != null)
                    const SizedBox(height: 12),
                  if (error != null && controls.values.first.text.isEmpty)
                    TextButton(onPressed: load, child: const Text('Retry'))
                  else ...[
                    for (final entry in fields.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: controls[entry.key],
                          key: Key('campaign-plan-${entry.key}'),
                          enabled: widget.canEdit && !saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: entry.value,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    const Text(
                      'A referral unlocks the extra tasks for each campaign. Cancelled campaigns count toward the window.',
                    ),
                    const SizedBox(height: 16),
                    if (widget.canEdit)
                      FilledButton(
                        onPressed: saving ? null : save,
                        child: const Text('Save campaign limits'),
                      ),
                  ],
                ],
              ),
      ),
    ),
  );
}
