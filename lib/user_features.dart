import 'engagement_benefits.dart';
import 'user_page_canvas.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support_page.dart';
import 'design.dart';

String uf(BuildContext c, String en, String ml) => supportText(c, en, ml);

String submissionStatus(BuildContext context, String status) =>
    switch (status) {
      'pending' => uf(context, 'Pending', 'പരിശോധനയിൽ'),
      'approved' => uf(context, 'Approved', 'അംഗീകരിച്ചു'),
      'rejected' => uf(context, 'Rejected', 'നിരസിച്ചു'),
      'withdrawn' => uf(context, 'Withdrawn', 'പിൻവലിച്ചു'),
      'cancelled' => uf(context, 'Cancelled', 'റദ്ദാക്കി'),
      _ => uf(context, 'Earlier submission', 'പഴയ submission'),
    };

class SubmissionHistoryPage extends StatefulWidget {
  const SubmissionHistoryPage({
    super.key,
    required this.client,
    this.onResubmit,
  });
  final SupabaseClient client;
  final void Function(BuildContext, Map)? onResubmit;
  @override
  State<SubmissionHistoryPage> createState() => _SubmissionHistoryPageState();
}

class _SubmissionHistoryPageState extends State<SubmissionHistoryPage> {
  final query = TextEditingController();
  String? status;
  DateTimeRange? range;
  int offset = 0;
  bool appealsEnabled = false, resubmitEnabled = false, waitingEnabled = false;
  late Future<List<dynamic>> data;
  @override
  void initState() {
    super.initState();
    load();
    loadAppeals();
  }

  Future<void> loadAppeals() async {
    try {
      final settings = await widget.client.rpc('user_feature_settings') as Map;
      final enabled = settings['submission_appeals'] == true;
      final retry = settings['resubmit_help'] == true;
      if (mounted) {
        setState(() {
          appealsEnabled = enabled;
          resubmitEnabled = retry;
          waitingEnabled = settings['submission_waiting'] == true;
        });
      }
    } catch (_) {
      /* History remains available. */
    }
  }

  Future<void> appeal(String submissionId) async {
    final message = await showDialog<String>(
      context: context,
      builder: (context) => const _AppealDialog(),
    );
    if (message == null || !mounted) return;
    try {
      await widget.client.rpc(
        'appeal_submission',
        params: {'p_submission': submissionId, 'p_message': message},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uf(
              context,
              'Appeal sent. Follow it in Support.',
              'Appeal അയച്ചു. Support-ൽ മറുപടി കാണാം.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uf(
                context,
                'Unable to send appeal. It may already exist.',
                'Appeal അയയ്ക്കാനായില്ല. ഇതിനകം അയച്ചതാകാം.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void load() {
    data = widget.client
        .rpc(
          'user_submission_history',
          params: {
            'p_status': status,
            'p_query': query.text.trim(),
            'p_from': range == null
                ? null
                : DateTime.utc(
                    range!.start.year,
                    range!.start.month,
                    range!.start.day,
                  ).toIso8601String(),
            'p_to': range == null
                ? null
                : DateTime.utc(
                    range!.end.year,
                    range!.end.month,
                    range!.end.day + 1,
                  ).toIso8601String(),
            'p_offset': offset,
            'p_limit': 50,
          },
        )
        .then((v) => v as List<dynamic>);
  }

  void refresh({bool reset = false}) => setState(() {
    if (reset) offset = 0;
    load();
  });
  Future<void> chooseDates() async {
    final value = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: range,
    );
    if (value != null && mounted) {
      setState(() {
        range = value;
        offset = 0;
        load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => UserPageScaffold(
    identity: UserPageIdentity.submissionHistory,
    appBar: AppBar(
      title: Text(uf(context, 'Submission history', 'Submission ചരിത്രം')),
      actions: [
        IconButton(
          onPressed: refresh,
          tooltip: uf(context, 'Refresh', 'പുതുക്കുക'),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .86),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xffe4dcf2)),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: query,
                    maxLength: 100,
                    onSubmitted: (_) => refresh(reset: true),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: uf(
                        context,
                        'Search action or link',
                        'Action അല്ലെങ്കിൽ link തിരയുക',
                      ),
                      counterText: '',
                      suffixIcon: IconButton(
                        onPressed: () => refresh(reset: true),
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: status,
                          hint: Text(
                            uf(context, 'All statuses', 'എല്ലാ നിലകളും'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                uf(context, 'All statuses', 'എല്ലാ നിലകളും'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            for (final v in [
                              'pending',
                              'approved',
                              'rejected',
                              'withdrawn',
                              'cancelled',
                              'legacy',
                            ])
                              DropdownMenuItem(
                                value: v,
                                child: Text(
                                  submissionStatus(context, v),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() {
                            status = v;
                            offset = 0;
                            load();
                          }),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: chooseDates,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          range == null
                              ? uf(
                                  context,
                                  'Date range (UTC)',
                                  'തീയതി പരിധി (UTC)',
                                )
                              : '${range!.start.toIso8601String().substring(0, 10)} – ${range!.end.toIso8601String().substring(0, 10)}',
                        ),
                      ),
                      if (range != null)
                        TextButton(
                          onPressed: () => setState(() {
                            range = null;
                            offset = 0;
                            load();
                          }),
                          child: Text(
                            uf(context, 'Clear dates', 'തീയതി മായ്ക്കുക'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: data,
                builder: (c, s) {
                  if (s.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (s.hasError) {
                    return Center(
                      child: Text(
                        uf(c, 'Unable to load history.', 'ചരിത്രം ലഭ്യമല്ല.'),
                      ),
                    );
                  }
                  final rows = s.data ?? [];
                  return Column(
                    children: [
                      Expanded(
                        child: rows.isEmpty
                            ? Center(
                                child: Text(
                                  uf(
                                    c,
                                    'No submissions found.',
                                    'Submissions കണ്ടെത്തിയില്ല.',
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: rows.length,
                                itemBuilder: (c, i) {
                                  final r = rows[i] as Map;
                                  final submitted = DateTime.tryParse(
                                    r['submitted_at']?.toString() ?? '',
                                  );
                                  final elapsed = submitted == null
                                      ? null
                                      : DateTime.now().difference(submitted);
                                  final waiting =
                                      waitingEnabled &&
                                          r['status'] == 'pending' &&
                                          elapsed != null &&
                                          !elapsed.isNegative
                                      ? '\n${uf(c, 'Waiting', 'കാത്തിരിക്കുന്നത്')}: ${elapsed.inHours}h ${elapsed.inMinutes.remainder(60)}m'
                                      : '';
                                  return Card(
                                    child: Column(
                                      children: [
                                        ListTile(
                                          title: Text(
                                            '${r['action_type']} · ${submissionStatus(c, r['status'] as String)}',
                                          ),
                                          subtitle: Text(
                                            '${r['campaign_link']}\n${r['submitted_at']}$waiting${r['rejection_reason'] == null ? '' : '\n${uf(c, 'Reason', 'കാരണം')}: ${r['rejection_reason']}'}',
                                          ),
                                          trailing:
                                              appealsEnabled &&
                                                  r['status'] == 'rejected'
                                              ? TextButton(
                                                  onPressed: () => appeal(
                                                    r['submission_id']
                                                        as String,
                                                  ),
                                                  child: Text(
                                                    uf(c, 'Appeal', 'Appeal'),
                                                  ),
                                                )
                                              : null,
                                        ),
                                        if (resubmitEnabled &&
                                            r['status'] == 'rejected' &&
                                            widget.onResubmit != null)
                                          TextButton(
                                            onPressed: () =>
                                                widget.onResubmit!(context, r),
                                            child: Text(
                                              uf(
                                                context,
                                                'How to resubmit',
                                                'വീണ്ടും അയയ്ക്കാൻ സഹായം',
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      Wrap(
                        alignment: WrapAlignment.end,
                        children: [
                          TextButton(
                            onPressed: offset > 0
                                ? () => setState(() {
                                    offset -= 50;
                                    load();
                                  })
                                : null,
                            child: Text(uf(c, 'Previous', 'മുമ്പത്തെ')),
                          ),
                          Text(
                            '${offset + (rows.isEmpty ? 0 : 1)}–${offset + rows.length}',
                          ),
                          TextButton(
                            onPressed: rows.length == 50
                                ? () => setState(() {
                                    offset += 50;
                                    load();
                                  })
                                : null,
                            child: Text(uf(c, 'Next', 'അടുത്തത്')),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class UserHelpPage extends StatelessWidget {
  const UserHelpPage({super.key, this.client});
  final SupabaseClient? client;
  @override
  Widget build(BuildContext context) {
    final items = <String, String>{
      uf(context, 'Coins and campaigns', 'Coins, campaigns'): uf(
        context,
        'Coins are reserved when you create a campaign. Unused coins are refunded when it is cancelled.',
        'Campaign തുടങ്ങുമ്പോൾ coins മാറ്റിവയ്ക്കും. റദ്ദാക്കുമ്പോൾ ഉപയോഗിക്കാത്ത coins തിരികെ ലഭിക്കും.',
      ),
      uf(context, 'Submit a task', 'Task സമർപ്പിക്കുക'): uf(
        context,
        'Complete the action, enter your Instagram username and provide the relevant screenshot. The campaign owner or an administrator reviews it.',
        'Action പൂർത്തിയാക്കി Instagram username-ഉം അനുയോജ്യമായ screenshot-ഉം നൽകുക. Campaign ഉടമയോ administrator-ഓ പരിശോധിക്കും.',
      ),
      uf(context, 'PIN and approval', 'PIN, approval'): uf(
        context,
        'Set your Security PIN in Profile using email OTP. The PIN is required to confirm account changes and approve submissions.',
        'Profile-ൽ email OTP ഉപയോഗിച്ച് Security PIN സജ്ജമാക്കുക. Submission approve ചെയ്യാൻ PIN ആവശ്യമാണ്.',
      ),
      uf(context, 'Saved tasks', 'Saved tasks'): uf(
        context,
        'Saving a task helps you find it later. It does not reserve the task.',
        'Task save ചെയ്താൽ പിന്നീട് കണ്ടെത്താം. അത് task reserve ചെയ്യില്ല.',
      ),
      uf(context, 'Need help?', 'സഹായം വേണോ?'): uf(
        context,
        'Open Support in Profile to send a ticket to the administrators.',
        'Administrators-നെ ബന്ധപ്പെടാൻ Profile-ലെ Support തുറക്കുക.',
      ),
    };
    return UserPageScaffold(
      identity: UserPageIdentity.help,
      appBar: AppBar(
        title: Text(uf(context, 'Help & guide', 'സഹായവും മാർഗ്ഗനിർദ്ദേശവും')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              UserSectionIntro(
                title: uf(context, 'Need Help?', 'സഹായം വേണോ?'),
                subtitle: uf(
                  context,
                  'Learn how tasks, campaigns and coins work.',
                  'Tasks, campaigns, coins എന്നിവ എങ്ങനെ ഉപയോഗിക്കാം എന്ന് അറിയുക.',
                ),
                icon: Icons.help_outline_rounded,
              ),
              const SizedBox(height: 16),
              for (final (index, item) in items.entries.indexed)
                Card(
                  child: ExpansionTile(
                    leading: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xffeee6ff),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        [
                          Icons.toll,
                          Icons.fact_check,
                          Icons.verified_user,
                          Icons.bookmark,
                          Icons.help,
                        ][index],
                        color: growthPurple,
                      ),
                    ),
                    title: Text(
                      item.key,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(item.value),
                      ),
                    ],
                  ),
                ),
              if (client != null) ...[
                UserHelpArticles(client: client!),
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xffe9def9),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.support_agent,
                          color: growthPurple,
                          size: 48,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                uf(
                                  context,
                                  'Contact Support',
                                  'Support-നെ ബന്ധപ്പെടുക',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                uf(
                                  context,
                                  'Get in touch with our support team for any assistance.',
                                  'സഹായത്തിനായി support team-നെ ബന്ധപ്പെടുക.',
                                ),
                                style: const TextStyle(fontSize: 11),
                              ),
                              const SizedBox(height: 8),
                              GrowthActionButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        SupportPage(client: client!),
                                  ),
                                ),
                                icon: Icons.mail_outline,
                                label: uf(context, 'Contact Us', 'ബന്ധപ്പെടുക'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AppealDialog extends StatefulWidget {
  const _AppealDialog();
  @override
  State<_AppealDialog> createState() => _AppealDialogState();
}

class _AppealDialogState extends State<_AppealDialog> {
  final message = TextEditingController();
  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(uf(context, 'Appeal rejection', 'Rejection appeal')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          uf(
            context,
            'Explain why the decision should be reviewed. The original screenshot is removed after review.',
            'തീരുമാനം വീണ്ടും പരിശോധിക്കേണ്ട കാരണം എഴുതുക. Review കഴിഞ്ഞാൽ ആദ്യ screenshot നീക്കം ചെയ്യപ്പെടും.',
          ),
        ),
        TextField(
          controller: message,
          maxLength: 1500,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: uf(context, 'Your message', 'നിങ്ങളുടെ സന്ദേശം'),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(uf(context, 'Cancel', 'റദ്ദാക്കുക')),
      ),
      FilledButton(
        onPressed: () {
          final text = message.text.trim();
          if (text.isNotEmpty) Navigator.pop(context, text);
        },
        child: Text(uf(context, 'Send', 'അയയ്ക്കുക')),
      ),
    ],
  );
}
