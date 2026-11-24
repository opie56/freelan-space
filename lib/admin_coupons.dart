import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCoupons extends StatefulWidget {
  const AdminCoupons({super.key, required this.client, required this.canEdit});
  final SupabaseClient client;
  final bool canEdit;
  @override
  State<AdminCoupons> createState() => _AdminCouponsState();
}

class _AdminCouponsState extends State<AdminCoupons> {
  final code = TextEditingController(),
      amount = TextEditingController(text: '1'),
      limit = TextEditingController(text: '10');
  DateTime? expiry;
  List<dynamic>? rows;
  bool busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    code.dispose();
    amount.dispose();
    limit.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final v = await widget.client.rpc('admin_bonus_coupons') as List;
      if (mounted) {
        setState(() {
          rows = v;
          message = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => message = 'Unable to load coupons.');
    }
  }

  Future<void> create() async {
    final a = int.tryParse(amount.text),
        n = int.tryParse(limit.text),
        c = code.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6,24}$').hasMatch(c) ||
        a == null ||
        a < 1 ||
        a > 10000 ||
        n == null ||
        n < 1 ||
        n > 100000 ||
        expiry == null) {
      setState(
        () => message = 'Enter a valid code, amount, limit and expiry date.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.client.rpc(
        'admin_create_coupon',
        params: {
          'p_code': c,
          'p_amount': a,
          'p_limit': n,
          'p_expires': expiry!.toUtc().toIso8601String(),
        },
      );
      code.clear();
      await load();
      if (mounted) setState(() => message = 'Coupon created.');
    } catch (_) {
      if (mounted) setState(() => message = 'Unable to create coupon.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> disable(String id) async {
    setState(() => busy = true);
    try {
      await widget.client.rpc('admin_disable_coupon', params: {'p_id': id});
      await load();
    } catch (_) {
      if (mounted) setState(() => message = 'Unable to disable coupon.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bonus coupons', style: Theme.of(context).textTheme.titleMedium),
          const Text(
            'Create codes with a coin amount, total redemption limit and expiry.',
          ),
          if (widget.canEdit) ...[
            TextField(
              controller: code,
              maxLength: 24,
              decoration: const InputDecoration(
                labelText: 'Code (6–24 letters or numbers)',
              ),
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Coins per redemption',
              ),
            ),
            TextField(
              controller: limit,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Maximum redemptions',
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: context,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 729)),
                      );
                      if (d != null && mounted) {
                        setState(
                          () => expiry = DateTime(d.year, d.month, d.day + 1),
                        );
                      }
                    },
              child: Text(
                expiry == null
                    ? 'Select expiry date'
                    : 'Expires ${expiry!.subtract(const Duration(days: 1)).toLocal().toString().split(' ').first}',
              ),
            ),
            FilledButton(
              onPressed: busy ? null : create,
              child: const Text('Create coupon'),
            ),
          ],
          if (message != null) Text(message!),
          if (rows == null && message == null)
            const CircularProgressIndicator(),
          if (rows != null)
            for (final r in rows!)
              ListTile(
                title: Text('${r['code']} · ${r['amount']} coins'),
                subtitle: Text(
                  '${r['used']} / ${r['max_uses']} · ${r['expires_at']}',
                ),
                trailing: widget.canEdit && r['enabled'] == true
                    ? TextButton(
                        onPressed: busy
                            ? null
                            : () => disable(r['id'] as String),
                        child: const Text('Disable'),
                      )
                    : null,
              ),
          if (message == 'Unable to load coupons.')
            TextButton(onPressed: load, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
