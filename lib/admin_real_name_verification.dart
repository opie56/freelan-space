import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'evidence_image.dart';
import 'real_name_verification.dart';

class AdminRealNameVerificationPage extends StatefulWidget {
  const AdminRealNameVerificationPage({
    super.key,
    required this.client,
    required this.canEdit,
  });
  final SupabaseClient client;
  final bool canEdit;
  @override
  State<AdminRealNameVerificationPage> createState() =>
      _AdminRealNameVerificationPageState();
}

class _AdminRealNameVerificationPageState
    extends State<AdminRealNameVerificationPage> {
  late Future<dynamic> requests;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() => requests = widget.client.rpc('admin_real_name_requests');
  Future<void> inspect(Map row) async {
    final changed = row['current_name'] != row['submitted_name'];
    await showDialog<void>(
      context: context,
      builder: (context) => _ProofDialog(
        client: widget.client,
        row: row,
        canEdit: widget.canEdit,
        changed: changed,
      ),
    );
    if (mounted) setState(load);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        verificationText(
          context,
          'Real name requests',
          'പേര് പരിശോധന അപേക്ഷകൾ',
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => setState(load),
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    ),
    body: FutureBuilder<dynamic>(
      future: requests,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(load),
              child: const Text('Unable to load requests. Retry'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data as List;
        if (rows.isEmpty) {
          return Center(
            child: Text(
              verificationText(
                context,
                'No pending requests.',
                'അപേക്ഷകളൊന്നുമില്ല.',
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index] as Map;
            return ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(row['submitted_name'] as String),
              subtitle: Text('${row['email'] ?? ''}\n${row['submitted_at']}'),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => inspect(row),
            );
          },
        );
      },
    ),
  );
}

class _ProofDialog extends StatefulWidget {
  const _ProofDialog({
    required this.client,
    required this.row,
    required this.canEdit,
    required this.changed,
  });
  final SupabaseClient client;
  final Map row;
  final bool canEdit, changed;
  @override
  State<_ProofDialog> createState() => _ProofDialogState();
}

class _ProofDialogState extends State<_ProofDialog> {
  late Future<dynamic> proof;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    proof = load();
  }

  Future<dynamic> load() async {
    final data = await widget.client.rpc(
      'admin_real_name_proof',
      params: {'p_request_id': widget.row['request_id']},
    );
    if (data == null) throw StateError('Request unavailable');
    return decodeEvidenceImage(data as String);
  }

  Future<void> decide(bool approve) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.client.rpc(
        'admin_decide_real_name',
        params: {
          'p_request_id': widget.row['request_id'],
          'p_approve': approve,
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Decision failed. Refresh the requests and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Review: ${widget.row['submitted_name']}'),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account: ${widget.row['email'] ?? ''}'),
            if (widget.changed)
              Text(
                'Profile name changed to ${widget.row['current_name'] ?? '(empty)'}. Reject and ask the user to submit again.',
              ),
            const SizedBox(height: 12),
            FutureBuilder<dynamic>(
              future: proof,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Unable to load ID image.');
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return InteractiveViewer(
                  child: Image.memory(snapshot.data, fit: BoxFit.contain),
                );
              },
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      if (widget.canEdit)
        TextButton(
          onPressed: busy ? null : () => decide(false),
          child: const Text('Reject'),
        ),
      if (widget.canEdit)
        FutureBuilder<dynamic>(
          future: proof,
          builder: (context, snapshot) => FilledButton(
            onPressed: busy || widget.changed || !snapshot.hasData
                ? null
                : () => decide(true),
            child: const Text('Approve'),
          ),
        ),
    ],
  );
}
