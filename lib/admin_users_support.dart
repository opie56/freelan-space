import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_design.dart';
import 'admin_destination.dart';
import 'support_page.dart';

/// Administrator inbox for conversations started by members.
class AdminUsersSupportPage extends StatefulWidget {
  const AdminUsersSupportPage({
    super.key,
    required this.client,
    required this.canEdit,
    this.userId,
  });

  final SupabaseClient client;
  final bool canEdit;
  final String? userId;

  @override
  State<AdminUsersSupportPage> createState() => _AdminUsersSupportPageState();
}

class _AdminUsersSupportPageState extends State<AdminUsersSupportPage> {
  late Future<List<dynamic>> tickets;
  Timer? timer;
  bool closing = false;
  int pendingLoads = 0;

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          !closing &&
          pendingLoads == 0) {
        refresh();
      }
    });
  }

  void load() {
    pendingLoads++;
    tickets =
        (widget.userId == null
                ? widget.client.rpc('admin_support_tickets')
                : widget.client.rpc(
                    'admin_support_tickets_for_user',
                    params: {'p_user': widget.userId},
                  ))
            .then((v) => v as List)
            .whenComplete(() => pendingLoads--);
  }

  void refresh() => setState(load);

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> closeTicket(Map ticket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          supportText(context, 'Close this chat?', 'ഈ chat അടയ്ക്കണോ?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(supportText(context, 'Cancel', 'റദ്ദാക്കുക')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(supportText(context, 'Close chat', 'Chat അടയ്ക്കുക')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || closing) return;
    setState(() => closing = true);
    try {
      await widget.client.rpc(
        'admin_close_ticket',
        params: {'p_ticket': ticket['id']},
      );
      if (mounted) refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              supportText(
                context,
                'Unable to close chat.',
                'Chat അടയ്ക്കാനായില്ല.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => closing = false);
    }
  }

  Future<void> openTicket(Map ticket) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SupportConversation(
          client: widget.client,
          id: ticket['id'] as String,
          subject: ticket['subject'] as String,
          open: ticket['status'] == 'open',
          canReply: widget.canEdit,
          admin: true,
        ),
      ),
    );
    if (mounted) refresh();
  }

  @override
  Widget build(BuildContext context) => AdminDestinationScaffold(
    destination: AdminDestination.tickets,
    appBar: AdminPageBar(
      title: 'Users Supports',
      icon: Icons.support_agent,
      desktop: adminWideHeader(context),
      subtitle: supportText(
        context,
        'Read and reply to user support chats.',
        'User support chat-ുകൾ വായിച്ച് മറുപടി നൽകുക.',
      ),
      actions: [
        IconButton(
          onPressed: refresh,
          tooltip: supportText(context, 'Refresh', 'പുതുക്കുക'),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: FutureBuilder<List<dynamic>>(
          future: tickets,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      supportText(
                        context,
                        'Unable to load support chats.',
                        'Support chats ലഭ്യമല്ല.',
                      ),
                    ),
                    TextButton(
                      onPressed: refresh,
                      child: Text(
                        supportText(context, 'Retry', 'വീണ്ടും ശ്രമിക്കുക'),
                      ),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snapshot.data!;
            if (rows.isEmpty) {
              return AdminEmptyState(
                title: supportText(
                  context,
                  'No support chats yet.',
                  'Support chats ഇതുവരെ ഇല്ല.',
                ),
                art: 'operations_empty',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final ticket = rows[index] as Map;
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.chat_bubble_outline),
                    ),
                    title: Text('${ticket['subject']}'),
                    subtitle: Text(
                      '${ticket['email'] ?? 'Sign-in visitor'} · ${ticket['status']}',
                    ),
                    onTap: () => openTicket(ticket),
                    trailing: widget.canEdit && ticket['status'] == 'open'
                        ? IconButton(
                            tooltip: supportText(
                              context,
                              'Close chat',
                              'Chat അടയ്ക്കുക',
                            ),
                            onPressed: closing
                                ? null
                                : () => closeTicket(ticket),
                            icon: const Icon(Icons.check_circle_outline),
                          )
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}
