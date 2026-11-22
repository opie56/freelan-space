import 'package:flutter/material.dart';

import 'user_localization.dart';
import 'referral_design.dart';
import 'design.dart';
import 'user_tokens.dart';
import 'user_page_canvas.dart';

class ReferralHistoryEntry {
  ReferralHistoryEntry.fromRow(Map row)
    : referred = row['direction'] == 'referred',
      name = row['masked_name'] as String?,
      email = row['masked_email'] as String?,
      date = DateTime.parse(row['created_at'] as String).toLocal();

  final bool referred;
  final String? name, email;
  final DateTime date;
}

abstract interface class ReferralHistoryGateway {
  Future<List<ReferralHistoryEntry>> loadReferralHistory(int offset);
}

class ReferralHistoryPage extends StatefulWidget {
  const ReferralHistoryPage({super.key, required this.load});

  final Future<List<ReferralHistoryEntry>> Function(int offset) load;

  @override
  State<ReferralHistoryPage> createState() => _ReferralHistoryPageState();
}

class _ReferralHistoryPageState extends State<ReferralHistoryPage> {
  static const pageSize = 50;
  int offset = 0;
  late var data = widget.load(offset);

  void page(int next) => setState(() {
    offset = next;
    data = widget.load(offset);
  });

  @override
  Widget build(BuildContext context) => UserPageScaffold(
    identity: UserPageIdentity.referrals,
    appBar: AppBar(
      title: Text(userText(context, 'Referral History', 'Referral ചരിത്രം')),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: FutureBuilder<List<ReferralHistoryEntry>>(
          future: data,
          builder: (context, snapshot) {
            final dates = MaterialLocalizations.of(context);
            final entries = snapshot.data ?? [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
              children: [
                ReferralHeader(
                  eyebrow: userText(
                    context,
                    'Your connections',
                    'നിങ്ങളുടെ ബന്ധങ്ങൾ',
                  ),
                  title: userText(
                    context,
                    'Referral History',
                    'Referral ചരിത്രം',
                  ),
                  description: userText(
                    context,
                    'See the people connected through your referral codes.',
                    'Referral code വഴി ബന്ധമുള്ളവരെ കാണാം.',
                  ),
                  icon: Icons.history_rounded,
                ),
                const SizedBox(height: 24),
                if (snapshot.connectionState != ConnectionState.done)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (snapshot.hasError)
                  ReferralSurface(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 32,
                          color: userMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          userText(
                            context,
                            'Unable to load referral history.',
                            'Referral ചരിത്രം ലഭ്യമല്ല.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () => page(offset),
                          child: Text(
                            userText(context, 'Retry', 'വീണ്ടും ശ്രമിക്കുക'),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (entries.isEmpty)
                  ReferralSurface(
                    child: Column(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xffeff8f5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.people_outline_rounded,
                            color: userTeal,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          userText(
                            context,
                            'No referrals on this page.',
                            'ഈ പേജിൽ referrals ഇല്ല.',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: growthInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Text(
                    userText(
                      context,
                      'Referral connections',
                      'Referral ബന്ധങ്ങൾ',
                    ),
                    style: const TextStyle(
                      color: growthInk,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userText(
                      context,
                      'Names and emails are masked for privacy.',
                      'സ്വകാര്യതയ്ക്കായി പേരും email-ഉം മറച്ചിരിക്കുന്നു.',
                    ),
                    style: const TextStyle(color: userMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 14),
                  for (final entry in entries) ...[
                    ReferralSurface(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: entry.referred
                                  ? const Color(0xffeaf7f3)
                                  : const Color(0xfff2edff),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              entry.referred
                                  ? Icons.person_add_alt_1_rounded
                                  : Icons.person_outline_rounded,
                              color: entry.referred ? userTeal : growthPurple,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.name ??
                                      userText(
                                        context,
                                        'Name unavailable',
                                        'പേര് ലഭ്യമല്ല',
                                      ),
                                  style: const TextStyle(
                                    color: growthInk,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (entry.email != null)
                                  Text(
                                    entry.email!,
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                      color: userMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  entry.referred
                                      ? userText(
                                          context,
                                          'Used your code',
                                          'നിങ്ങളുടെ code ഉപയോഗിച്ചു',
                                        )
                                      : userText(
                                          context,
                                          'Referred you',
                                          'നിങ്ങളെ refer ചെയ്തു',
                                        ),
                                  style: TextStyle(
                                    color: entry.referred
                                        ? userTeal
                                        : growthPurple,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  dates.formatMediumDate(entry.date),
                                  style: const TextStyle(
                                    color: userMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                if (offset > 0 || entries.length == pageSize)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      if (offset > 0)
                        TextButton(
                          onPressed: () => page(offset - pageSize),
                          child: Text(
                            userText(context, 'Previous', 'മുമ്പത്തെ പേജ്'),
                          ),
                        ),
                      if (entries.length == pageSize)
                        TextButton(
                          onPressed: () => page(offset + pageSize),
                          child: Text(userText(context, 'Next', 'അടുത്ത പേജ്')),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class CampaignPlan {
  const CampaignPlan({
    required this.maxTasks,
    this.nextCampaignAt,
    this.campaignCount = 1,
    this.windowHours = 24,
    this.baseTasks = 3,
    this.referralBonus = 5,
  });

  factory CampaignPlan.fromJson(Map data) => CampaignPlan(
    maxTasks: data['max_tasks'] as int,
    nextCampaignAt: data['next_campaign_at'] == null
        ? null
        : DateTime.parse(data['next_campaign_at'] as String),
    campaignCount: data['campaign_count'] as int,
    windowHours: data['window_hours'] as int,
    baseTasks: data['base_tasks'] as int,
    referralBonus: data['referral_bonus'] as int,
  );

  final int maxTasks, campaignCount, windowHours, baseTasks, referralBonus;
  final DateTime? nextCampaignAt;
}

abstract interface class CampaignPlanGateway {
  Future<CampaignPlan> loadCampaignPlan();
}

class CampaignLimitsPage extends StatefulWidget {
  const CampaignLimitsPage({super.key, required this.loadPlan});
  final Future<CampaignPlan> Function() loadPlan;

  @override
  State<CampaignLimitsPage> createState() => _CampaignLimitsPageState();
}

class _CampaignLimitsPageState extends State<CampaignLimitsPage> {
  late Future<CampaignPlan> plan = widget.loadPlan();
  @override
  Widget build(BuildContext context) => UserPageScaffold(
    identity: UserPageIdentity.profile,
    appBar: AppBar(
      title: Text(userText(context, 'Campaign Limits', 'Campaign പരിധികൾ')),
    ),
    body: FutureBuilder<CampaignPlan>(
      future: plan,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userText(
                    context,
                    'Unable to load campaign limits.',
                    'Campaign പരിധികൾ ലഭ്യമല്ല.',
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    plan = widget.loadPlan();
                  }),
                  child: Text(userText(context, 'Retry', 'വീണ്ടും ശ്രമിക്കുക')),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final value = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.speed_outlined),
                title: Text(userText(context, 'Free Plan', 'Free Plan')),
                subtitle: Text(
                  userText(
                    context,
                    '${value.campaignCount} campaign(s) every ${value.windowHours} hours',
                    '${value.windowHours} മണിക്കൂറിൽ ${value.campaignCount} campaign(s)',
                  ),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.checklist),
                title: Text(
                  userText(
                    context,
                    '${value.baseTasks} tasks per campaign',
                    'ഒരു campaign-ന് ${value.baseTasks} tasks',
                  ),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.people_outline),
                title: Text(
                  userText(
                    context,
                    '${value.referralBonus} extra tasks with a referral',
                    'Referral വഴി ${value.referralBonus} extra tasks',
                  ),
                ),
                subtitle: Text(
                  userText(
                    context,
                    'After your first successful referral, you can add up to ${value.baseTasks + value.referralBonus} tasks per campaign.',
                    'ആദ്യ successful referral കഴിഞ്ഞാൽ ഒരു campaign-ന് ${value.baseTasks + value.referralBonus} tasks വരെ ചേർക്കാം.',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
