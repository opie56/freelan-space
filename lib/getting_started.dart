import 'package:flutter/material.dart';

import 'design.dart';
import 'user_localization.dart';

/// An optional introduction to the existing task and campaign flows.
class GettingStarted extends StatelessWidget {
  const GettingStarted({super.key, required this.onBrowse, this.onCampaigns});

  final VoidCallback onBrowse;
  final VoidCallback? onCampaigns;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton.icon(
      key: const Key('getting_started_open'),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userText(sheetContext, 'Getting started', 'തുടങ്ങാം'),
                    style: const TextStyle(
                      color: growthInk,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _step(
                    sheetContext,
                    Icons.explore_outlined,
                    'Find a task',
                    'ഒരു task കണ്ടെത്തുക',
                    'Browse the tasks available to you.',
                    'നിങ്ങൾക്ക് ലഭ്യമായ tasks നോക്കുക.',
                  ),
                  _step(
                    sheetContext,
                    Icons.fact_check_outlined,
                    'Submit for review',
                    'പരിശോധനയ്ക്ക് സമർപ്പിക്കുക',
                    'Complete a task and submit the requested details. Coins are awarded after approval.',
                    'Task പൂർത്തിയാക്കി ആവശ്യമായ വിവരങ്ങൾ സമർപ്പിക്കുക. Approval കഴിഞ്ഞാൽ coins ലഭിക്കും.',
                  ),
                  _step(
                    sheetContext,
                    Icons.campaign_outlined,
                    'Create a campaign',
                    'ഒരു campaign തുടങ്ങുക',
                    'Use available coins to create a campaign. The required coins are reserved.',
                    'ലഭ്യമായ coins ഉപയോഗിച്ച് campaign തുടങ്ങാം. ആവശ്യമായ coins മാറ്റിവയ്ക്കും.',
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('getting_started_browse'),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      onBrowse();
                    },
                    icon: const Icon(Icons.explore_outlined),
                    label: Text(
                      userText(sheetContext, 'Browse tasks', 'Task-ുകൾ കാണുക'),
                    ),
                  ),
                  if (onCampaigns != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('getting_started_campaigns'),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        onCampaigns!();
                      },
                      icon: const Icon(Icons.campaign_outlined),
                      label: Text(
                        userText(
                          sheetContext,
                          'View campaigns',
                          'Campaign-കൾ കാണുക',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      icon: const Icon(Icons.lightbulb_outline_rounded),
      label: Text(
        userText(context, 'How the app works', 'App എങ്ങനെ പ്രവർത്തിക്കുന്നു'),
      ),
    ),
  );

  Widget _step(
    BuildContext context,
    IconData icon,
    String title,
    String titleMl,
    String detail,
    String detailMl,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: growthPurple),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userText(context, title, titleMl),
                style: const TextStyle(
                  color: growthInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userText(context, detail, detailMl),
                style: const TextStyle(color: Color(0xff5f5d6c), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
