import 'reward_design.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_localization.dart';

String nt(BuildContext c, String en, String ml) => userText(c, en, ml);

class CouponEntry extends StatefulWidget {
  const CouponEntry({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<CouponEntry> createState() => _CouponEntryState();
}

class _CouponEntryState extends State<CouponEntry> {
  final code = TextEditingController();
  bool enabled = false, busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final f = await widget.client.rpc('user_feature_settings') as Map;
      if (mounted) setState(() => enabled = f['bonus_coupons'] == true);
    } catch (_) {}
  }

  Future<void> redeem() async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final r = await widget.client.rpc(
        'redeem_bonus_coupon',
        params: {'p_code': code.text.trim()},
      ) as Map;
      if (mounted) {
        setState(
          () => message = r['status'] == 'ok'
              ? null
              : nt(
                  context,
                  'Code unavailable, used or limit reached.',
                  'Code ലഭ്യമല്ല, ഉപയോഗിച്ചു, അല്ലെങ്കിൽ limit കഴിഞ്ഞു.',
                ),
        );
        if (r['status'] == 'ok') {
          await showCoinCreditSuccess(context, r['amount']);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = nt(
            context,
            'Unable to redeem code.',
            'Code ഉപയോഗിക്കാനായില്ല.',
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
      : RewardPanel(
          title: nt(context, 'Bonus coupon', 'Bonus coupon'),
          subtitle: nt(
            context,
            'Have a code? Turn it into coins.',
            'Coupon code ഉപയോഗിച്ച് coins നേടൂ.',
          ),
          icon: Icons.confirmation_number_outlined,
          accent: const Color(0xffb85a91),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: code,
                maxLength: 24,
                enabled: !busy,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: nt(context, 'Coupon code', 'Coupon code'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              FilledButton(
                onPressed: busy ? null : redeem,
                child: Text(nt(context, 'Redeem', 'ഉപയോഗിക്കുക')),
              ),
              if (message != null) Text(message!),
            ],
          ),
        );
}

class QuietHoursSettings extends StatefulWidget {
  const QuietHoursSettings({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<QuietHoursSettings> createState() => _QuietHoursSettingsState();
}

class _QuietHoursSettingsState extends State<QuietHoursSettings> {
  bool enabled = false, busy = false, configured = false;
  int start = 1320, end = 420, offset = 0;
  String? message;
  @override
  void initState() {
    super.initState();
    offset = DateTime.now().timeZoneOffset.inMinutes;
    load();
  }

  Future<void> load() async {
    try {
      final f = await widget.client.rpc('user_feature_settings') as Map;
      if (f['quiet_hours'] != true) return;
      final v = await widget.client.rpc('user_quiet_hours');
      if (mounted) {
        setState(() {
          enabled = true;
          configured = v != null;
          if (v is Map) {
            start = v['start_minute'] as int;
            end = v['end_minute'] as int;
            offset = v['offset_minute'] as int;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = nt(
            context,
            'Unable to load quiet hours.',
            'Quiet hours ലഭ്യമല്ല.',
          ),
        );
      }
    }
  }

  String format(int v) =>
      '${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';
  Future<void> pick(bool isStart) async {
    final v = isStart ? start : end;
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: v ~/ 60, minute: v % 60),
    );
    if (result != null && mounted) {
      setState(() {
        if (isStart) {
          start = result.hour * 60 + result.minute;
        } else {
          end = result.hour * 60 + result.minute;
        }
      });
    }
  }

  Future<void> save(bool on) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.client.rpc(
        'set_user_quiet_hours',
        params: {
          'p_start': on ? start : null,
          'p_end': on ? end : null,
          'p_offset': on ? offset : null,
        },
      );
      if (mounted) {
        setState(() {
          configured = on;
          message = nt(
            context,
            'Quiet hours saved.',
            'Quiet hours save ചെയ്തു.',
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = nt(
            context,
            'Unable to save quiet hours.',
            'Quiet hours save ചെയ്യാനായില്ല.',
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
                  nt(context, 'Quiet hours', 'Quiet hours'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  nt(
                    context,
                    'Push notifications wait until quiet hours end. In-app notifications remain available.',
                    'Quiet hours കഴിഞ്ഞ് push notifications ലഭിക്കും. App-ൽ notifications കാണാം.',
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: busy ? null : () => pick(true),
                      child: Text(
                        '${nt(context, 'From', 'മുതൽ')}: ${format(start)}',
                      ),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => pick(false),
                      child: Text(
                        '${nt(context, 'To', 'വരെ')}: ${format(end)}',
                      ),
                    ),
                  ],
                ),
                Text('UTC offset: ${offset >= 0 ? '+' : ''}$offset min'),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(
                          () =>
                              offset = DateTime.now().timeZoneOffset.inMinutes,
                        ),
                  child: Text(
                    nt(
                      context,
                      'Use current device offset',
                      'Device time offset ഉപയോഗിക്കുക',
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: busy || start == end ? null : () => save(true),
                      child: Text(nt(context, 'Save', 'സേവ് ചെയ്യുക')),
                    ),
                    if (configured)
                      TextButton(
                        onPressed: busy ? null : () => save(false),
                        child: Text(nt(context, 'Turn off', 'OFF ചെയ്യുക')),
                      ),
                  ],
                ),
                if (message != null) Text(message!),
              ],
            ),
          ),
        );
}

class DeviceSessions extends StatefulWidget {
  const DeviceSessions({super.key, required this.client, required this.askPin});
  final SupabaseClient client;
  final Future<String?> Function(BuildContext) askPin;
  @override
  State<DeviceSessions> createState() => _DeviceSessionsState();
}

class _DeviceSessionsState extends State<DeviceSessions> {
  bool enabled = false, busy = false;
  List<dynamic>? rows;
  String? message;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final f = await widget.client.rpc('user_feature_settings') as Map;
      if (f['device_sessions'] != true) return;
      final v = await widget.client.rpc('user_device_sessions') as List;
      if (mounted) {
        setState(() {
          enabled = true;
          rows = v;
          message = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = nt(
            context,
            'Unable to load devices.',
            'Devices ലഭ്യമല്ല.',
          ),
        );
      }
    }
  }

  Future<void> revoke(String id) async {
    if (busy) return;
    final pin = await widget.askPin(context);
    if (pin == null || !mounted) return;
    setState(() => busy = true);
    try {
      final result = await widget.client.rpc(
        'revoke_device_session',
        params: {'p_id': id, 'p_pin': pin},
      );
      if (result != 'ok') throw StateError('Not confirmed');
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => message = nt(
            context,
            'Unable to sign out that device. Check the PIN.',
            'Device sign out ആയില്ല. PIN പരിശോധിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled && message == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nt(context, 'Devices', 'Devices'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              nt(
                context,
                'Existing access tokens may remain valid until they expire.',
                'മുൻ access token കാലാവധി തീരുന്നതുവരെ പ്രവർത്തിച്ചേക്കാം.',
              ),
            ),
            if (message != null) Text(message!),
            if (rows != null)
              for (final r in rows!)
                ListTile(
                  title: Text(
                    (r['user_agent'] as String?)?.isNotEmpty == true
                        ? r['user_agent'] as String
                        : nt(context, 'Device', 'Device'),
                  ),
                  subtitle: Text('${r['created_at']}'),
                  trailing: r['is_current'] == true
                      ? Text(nt(context, 'Current', 'ഇത്'))
                      : TextButton(
                          onPressed: busy
                              ? null
                              : () => revoke(r['id'] as String),
                          child: Text(nt(context, 'Sign out', 'Sign out')),
                        ),
                ),
            TextButton(
              onPressed: busy ? null : load,
              child: Text(nt(context, 'Refresh', 'പുതുക്കുക')),
            ),
          ],
        ),
      ),
    );
  }
}

class OfflineWalletView extends StatefulWidget {
  const OfflineWalletView({
    super.key,
    required this.client,
    required this.uid,
    required this.project,
  });
  final SupabaseClient client;
  final String uid, project;
  @override
  State<OfflineWalletView> createState() => _OfflineWalletViewState();
}

class _OfflineWalletViewState extends State<OfflineWalletView>
    with WidgetsBindingObserver {
  final storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );
  Map<String, dynamic>? cached;
  int generation = 0;
  Timer? refresh;
  String get key => 'offline_wallet_${widget.project}_${widget.uid}';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh = Timer.periodic(const Duration(minutes: 1), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(load());
      }
    });
    load();
  }

  @override
  void dispose() {
    refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    final request = ++generation;
    try {
      final flags = await widget.client.rpc('user_feature_settings') as Map;
      if (!mounted || request != generation) return;
      if (flags['offline_view'] != true) {
        if (mounted && request == generation) setState(() => cached = null);
        await storage.delete(key: key);
        return;
      }
      final wallet = await widget.client
          .from('wallets')
          .select('balance,held_balance')
          .eq('id', widget.uid)
          .maybeSingle();
      if (!mounted || request != generation) return;
      if (wallet == null) {
        if (mounted && request == generation) setState(() => cached = null);
        await storage.delete(key: key);
        return;
      }
      final data = {
        'balance':
            (wallet['balance'] as int) - (wallet['held_balance'] as int? ?? 0),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await storage.write(key: key, value: jsonEncode(data));
      if (mounted && request == generation) setState(() => cached = null);
    } on PostgrestException catch (_) {
      if (mounted && request == generation) setState(() => cached = null);
    } on AuthException catch (_) {
      if (mounted && request == generation) setState(() => cached = null);
    } catch (_) {
      try {
        final raw = await storage.read(key: key);
        if (raw != null && mounted && request == generation) {
          setState(
            () => cached = Map<String, dynamic>.from(jsonDecode(raw) as Map),
          );
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) => cached == null
      ? const SizedBox.shrink()
      : Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_off_outlined),
            title: Text(
              nt(context, 'Offline wallet snapshot', 'Offline wallet snapshot'),
            ),
            subtitle: Text(
              '${cached!['balance']} coins · ${nt(context, 'last updated', 'അവസാനം പുതുക്കിയത്')}: ${cached!['updated_at']}',
            ),
          ),
        );
}
