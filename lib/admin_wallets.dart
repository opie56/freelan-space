import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_design.dart';
import 'admin_destination.dart';
import 'support_page.dart';
import 'wallet_transfer.dart' show transferRequestId;

abstract class AdminWalletGateway {
  String get sessionKey;
  Future<List<Map<String, dynamic>>> search(String query, int offset);
  Future<Map<String, dynamic>> operate(Map<String, dynamic> params);
  Future<List<Map<String, dynamic>>> history(String user, int offset);
}

class SupabaseAdminWalletGateway implements AdminWalletGateway {
  SupabaseAdminWalletGateway(
    this.client, {
    this.targetUserId,
    this.targetWalletNumber,
  }) : owner = client.auth.currentUser!.id;
  final SupabaseClient client;
  final String owner;
  final String? targetUserId, targetWalletNumber;
  @override
  String get sessionKey => 'admin_wallet_${client.rest.url}_$owner';
  void checkSession() {
    if (client.auth.currentUser?.id != owner) {
      throw StateError('Account changed.');
    }
  }

  List<Map<String, dynamic>> rows(dynamic value) => (value as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
  @override
  Future<List<Map<String, dynamic>>> search(String query, int offset) async {
    checkSession();
    if (targetUserId != null && query == targetWalletNumber) {
      if (offset > 0) return [];
      return rows(
        await client.rpc(
          'admin_wallet_for_user',
          params: {'p_user': targetUserId},
        ),
      );
    }
    return rows(
      await client.rpc(
        'admin_wallets',
        params: {'p_query': query, 'p_offset': offset, 'p_limit': 50},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> operate(Map<String, dynamic> params) async {
    checkSession();
    return Map<String, dynamic>.from(
      await client.rpc('admin_wallet_operate', params: params) as Map,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> history(String user, int offset) async {
    checkSession();
    return rows(
      await client.rpc(
        'admin_wallet_history',
        params: {'p_user': user, 'p_offset': offset},
      ),
    );
  }
}

String _t(BuildContext c, String en, String ml) => supportText(c, en, ml);
const _actions = {
  'add': 'Add coins',
  'deduct': 'Deduct',
  'debit': 'Debit',
  'hold': 'Hold',
  'release': 'Release hold',
  'transfer': 'Transfer',
  'activate': 'Activate',
  'deactivate': 'Deactivate',
};

class AdminWalletsPage extends StatefulWidget {
  const AdminWalletsPage({
    super.key,
    required this.gateway,
    required this.canEdit,
    this.initialQuery = '',
  });
  final AdminWalletGateway gateway;
  final bool canEdit;
  final String initialQuery;
  @override
  State<AdminWalletsPage> createState() => _AdminWalletsPageState();
}

class _AdminWalletsPageState extends State<AdminWalletsPage> {
  final search = TextEditingController();
  String query = '';
  int offset = 0;
  late Future<List<Map<String, dynamic>>> data;
  Map<String, dynamic>? pending;
  bool restoring = true, storageFailed = false;
  @override
  void initState() {
    super.initState();
    query = widget.initialQuery;
    search.text = query;
    load();
    restore();
  }

  Future<void> restore() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(
        widget.gateway.sessionKey,
      );
      if (!mounted) return;
      setState(() {
        pending = saved == null
            ? null
            : Map<String, dynamic>.from(jsonDecode(saved) as Map);
        restoring = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          restoring = false;
          storageFailed = true;
        });
      }
    }
  }

  void load() {
    data = widget.gateway.search(query, offset);
  }

  void refresh() => setState(load);
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> operate(
    Map<String, dynamic> wallet,
    String action, {
    bool resume = false,
  }) async {
    if (!widget.canEdit ||
        restoring ||
        storageFailed ||
        (!resume && pending != null)) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WalletOperationDialog(
        gateway: widget.gateway,
        wallet: wallet,
        action: action,
        saved: resume ? pending : null,
        onPending: (value) {
          if (mounted) setState(() => pending = value);
        },
      ),
    );
    if (mounted) refresh();
  }

  Future<void> history(Map<String, dynamic> wallet) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _WalletHistory(gateway: widget.gateway, wallet: wallet),
    );
  }

  @override
  Widget build(BuildContext context) => AdminDestinationScaffold(
    minBodyHeight: 330,
    destination: AdminDestination.adjustments,
    appBar: AdminPageBar(
      title: 'Wallets Management',
      icon: Icons.account_balance_wallet_outlined,
      desktop: adminWideHeader(context),
      subtitle: _t(
        context,
        'Find a wallet and manage coins, holds and access.',
        'Wallet കണ്ടെത്തി coins, hold, access എന്നിവ നിയന്ത്രിക്കുക.',
      ),
      actions: [
        IconButton(
          onPressed: refresh,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: _t(
                      context,
                      'Search name, user ID or wallet number',
                      'പേര്, User ID, wallet നമ്പർ തിരയുക',
                    ),
                    counterText: '',
                  ),
                  onSubmitted: (_) => setState(() {
                    query = search.text.trim();
                    offset = 0;
                    load();
                  }),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => setState(() {
                  query = search.text.trim();
                  offset = 0;
                  load();
                }),
                child: const Text('Search'),
              ),
            ],
          ),
        ),
        if (!widget.canEdit)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Read-only access'),
          ),
        if (storageFailed)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Unable to restore pending operations. Reopen this page before making changes.',
            ),
          ),
        if (pending != null)
          Card(
            child: ListTile(
              title: const Text('Wallet operation not confirmed'),
              subtitle: const Text(
                'Check the saved request before starting another operation.',
              ),
              trailing: FilledButton(
                onPressed: widget.canEdit
                    ? () => operate(
                        Map<String, dynamic>.from(pending!['wallet'] as Map),
                        pending!['params']['p_action'] as String,
                        resume: true,
                      )
                    : null,
                child: const Text('Resume request'),
              ),
            ),
          ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: refresh,
                    child: const Text('Unable to load wallets. Retry'),
                  ),
                );
              }
              final rows = snapshot.data!;
              return Column(
                children: [
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(child: Text('No wallets found'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: rows.length,
                            itemBuilder: (context, i) {
                              final row = rows[i];
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${row['display_name']}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      SelectableText(
                                        'User ID: ${row['public_id']}  ·  Wallet number: ${row['wallet_number']}',
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Total: ${row['balance']} coins  ·  Available: ${row['available_balance']}  ·  Held: ${row['held_balance']}  ·  ${row['is_active'] == true ? 'Active' : 'Inactive'}',
                                      ),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          TextButton(
                                            onPressed: () => history(row),
                                            child: const Text(
                                              'Operation history',
                                            ),
                                          ),
                                          if (widget.canEdit)
                                            for (final action
                                                in _actions.entries)
                                              if (action.key !=
                                                  (row['is_active'] == true
                                                      ? 'activate'
                                                      : 'deactivate'))
                                                OutlinedButton(
                                                  onPressed:
                                                      restoring ||
                                                          storageFailed ||
                                                          pending != null
                                                      ? null
                                                      : () => operate(
                                                          row,
                                                          action.key,
                                                        ),
                                                  child: Text(action.value),
                                                ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: offset == 0
                            ? null
                            : () => setState(() {
                                offset -= 50;
                                load();
                              }),
                        child: const Text('Previous'),
                      ),
                      Text('Page ${offset ~/ 50 + 1}'),
                      TextButton(
                        onPressed: rows.length < 50
                            ? null
                            : () => setState(() {
                                offset += 50;
                                load();
                              }),
                        child: const Text('Next'),
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
  );
}

class _WalletOperationDialog extends StatefulWidget {
  const _WalletOperationDialog({
    required this.gateway,
    required this.wallet,
    required this.action,
    required this.saved,
    required this.onPending,
  });
  final AdminWalletGateway gateway;
  final Map<String, dynamic> wallet;
  final String action;
  final Map<String, dynamic>? saved;
  final ValueChanged<Map<String, dynamic>?> onPending;
  @override
  State<_WalletOperationDialog> createState() => _WalletOperationDialogState();
}

class _WalletOperationDialogState extends State<_WalletOperationDialog> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(),
      reason = TextEditingController(),
      recipientWallet = TextEditingController();
  Map<String, dynamic>? pending, recipient;
  bool busy = false;
  String? error;
  bool get stateOnly =>
      widget.action == 'activate' || widget.action == 'deactivate';
  @override
  void initState() {
    super.initState();
    pending = widget.saved;
    if (pending != null) {
      final params = pending!['params'] as Map;
      amount.text = '${params['p_amount']}';
      reason.text = params['p_reason'] as String;
      recipientWallet.text = params['p_recipient_wallet'] as String? ?? '';
      recipient = pending!['recipient'] == null
          ? null
          : Map<String, dynamic>.from(pending!['recipient'] as Map);
    }
  }

  @override
  void dispose() {
    amount.dispose();
    reason.dispose();
    recipientWallet.dispose();
    super.dispose();
  }

  Future<void> lookup() async {
    final number = recipientWallet.text.trim();
    if (!RegExp(r'^[1-9][0-9]{9}$').hasMatch(number)) {
      setState(() => error = 'Enter a 10-digit wallet number.');
      return;
    }
    setState(() {
      busy = true;
      recipient = null;
      error = null;
    });
    try {
      final rows = await widget.gateway.search(number, 0);
      if (!mounted) return;
      final exact = rows.where(
        (r) =>
            r['wallet_number'] == number &&
            r['user_id'] != widget.wallet['user_id'],
      );
      setState(() {
        recipient = exact.isEmpty ? null : exact.first;
        if (recipient == null) error = 'Choose another valid recipient wallet.';
      });
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to check recipient. Retry.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (busy || (pending == null && !form.currentState!.validate())) return;
    if (widget.action == 'transfer' && recipient == null) {
      setState(() => error = 'Check the recipient wallet first.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    var saved = pending != null;
    try {
      final command =
          pending ??
          {
            'wallet': widget.wallet,
            'recipient': recipient,
            'params': {
              'p_request': transferRequestId(),
              'p_user': widget.wallet['user_id'],
              'p_action': widget.action,
              'p_amount': stateOnly ? 0 : int.parse(amount.text.trim()),
              'p_reason': reason.text.trim(),
              'p_recipient_wallet': widget.action == 'transfer'
                  ? recipient!['wallet_number']
                  : null,
              'p_recipient': widget.action == 'transfer'
                  ? recipient!['user_id']
                  : null,
            },
          };
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(
        widget.gateway.sessionKey,
        jsonEncode(command),
      )) {
        throw StateError('Cannot save request');
      }
      saved = true;
      pending = command;
      widget.onPending(command);
      final result = await widget.gateway
          .operate(Map<String, dynamic>.from(command['params'] as Map))
          .timeout(const Duration(seconds: 25));
      if (result['id'] is! String ||
          result['balance'] is! int ||
          result['held_balance'] is! int) {
        throw StateError('Invalid receipt');
      }
      if (!await prefs.remove(widget.gateway.sessionKey)) {
        throw StateError('Cannot clear request');
      }
      pending = null;
      widget.onPending(null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Wallet operation completed${result['reference'] == null ? '' : ' · ${result['reference']}'}',
          ),
        ),
      );
      Navigator.pop(context);
    } on PostgrestException catch (e) {
      // A business exception rolls the entire SQL transaction back. Other errors
      // may have lost the response after commit: retain the exact saved request.
      if (e.code == 'P0001' &&
          const {
            'Invalid wallet operation.',
            'Enter valid operation details.',
            'Choose another valid recipient wallet.',
            'Wallet unavailable.',
            'Recipient wallet unavailable.',
            'Not enough available coins.',
            'Amount exceeds held coins.',
            'Wallet balance limit exceeded.',
            'Wallet is inactive. Activate it before spending.',
          }.contains(e.message)) {
        try {
          if (await (await SharedPreferences.getInstance()).remove(
            widget.gateway.sessionKey,
          )) {
            pending = null;
            widget.onPending(null);
          }
        } catch (_) {
          /* Retry the saved request if cleanup failed. */
        }
      }
      if (mounted) {
        setState(
          () => error = e.code == 'P0001'
              ? e.message
              : 'Unable to complete operation. Check your access and retry.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = saved
              ? 'Operation not confirmed. Retry the same saved request.'
              : 'Unable to save request. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(_actions[widget.action]!),
      content: SizedBox(
        width: 480,
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.wallet['display_name']} · User ID: ${widget.wallet['public_id']}',
                ),
                SelectableText('Wallet: ${widget.wallet['wallet_number']}'),
                const SizedBox(height: 12),
                Text(switch (widget.action) {
                  'hold' => 'Reserve coins without changing the total balance. Held coins cannot be spent.',
                  'release' => 'Make held coins available to spend again.',
                  'deactivate' => 'Stop outgoing spending. Incoming credits and bonuses will still be recorded.',
                  'deduct' || 'debit' => 'Remove the entered coins from the available balance immediately.',
                  _ => 'This operation takes effect immediately.',
                }),
                if (!stateOnly)
                  TextFormField(
                    controller: amount,
                    enabled: pending == null && !busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Coins'),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      return n == null || n <= 0 || n > 2147483647
                          ? 'Enter a positive whole coin amount.'
                          : null;
                    },
                  ),
                if (widget.action == 'transfer') ...[
                  TextFormField(
                    controller: recipientWallet,
                    enabled: pending == null && !busy,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Recipient wallet number',
                    ),
                    onChanged: (_) => setState(() => recipient = null),
                  ),
                  OutlinedButton(
                    onPressed: busy || pending != null ? null : lookup,
                    child: const Text('Check recipient'),
                  ),
                  if (recipient != null)
                    Text(
                      'To: ${recipient!['display_name']} · User ID: ${recipient!['public_id']} · Wallet: ${recipient!['wallet_number']}',
                    ),
                ],
                TextFormField(
                  controller: reason,
                  enabled: pending == null && !busy,
                  maxLength: 1000,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Enter a reason.' : null,
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (busy) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: Text(pending == null ? 'Cancel' : 'Close; keep saved request'),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(pending == null ? 'Apply now' : 'Retry saved request'),
        ),
      ],
    ),
  );
}

class _WalletHistory extends StatefulWidget {
  const _WalletHistory({required this.gateway, required this.wallet});
  final AdminWalletGateway gateway;
  final Map<String, dynamic> wallet;
  @override
  State<_WalletHistory> createState() => _WalletHistoryState();
}

class _WalletHistoryState extends State<_WalletHistory> {
  int offset = 0;
  late Future<List<Map<String, dynamic>>> data = widget.gateway.history(
    widget.wallet['user_id'] as String,
    offset,
  );
  void page(int value) => setState(() {
    offset = value;
    data = widget.gateway.history(widget.wallet['user_id'] as String, offset);
  });
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Operation history · ${widget.wallet['wallet_number']}'),
    content: SizedBox(
      width: 650,
      height: 420,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return TextButton(
              onPressed: () => page(offset),
              child: const Text('Unable to load history. Retry'),
            );
          }
          final rows = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('No wallet operations'))
                    : ListView(
                        children: [
                          for (final row in rows)
                            ListTile(
                              title: Text(
                                '${row['action']} · ${row['amount']} coins',
                              ),
                              subtitle: Text(
                                '${row['reason']}\n${row['actor']} · ${row['created_at']}\nReference: ${(row['result'] as Map?)?['reference'] ?? row['id']}',
                              ),
                            ),
                        ],
                      ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: offset == 0 ? null : () => page(offset - 50),
                    child: const Text('Previous'),
                  ),
                  TextButton(
                    onPressed: rows.length < 50
                        ? null
                        : () => page(offset + 50),
                    child: const Text('Next'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
