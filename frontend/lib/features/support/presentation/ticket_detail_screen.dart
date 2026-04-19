import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../models/support_ticket.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  final SupportTicket ticket;

  const TicketDetailScreen({super.key, required this.ticket});

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _messageController = TextEditingController();
  List<TicketMessage> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final user = ref.read(authStateProvider).user!;
      final service = ref.read(supportServiceProvider);
      final data = await service.getTicketMessages(widget.ticket.ticketId, user.id);
      if (mounted) {
        setState(() {
          _messages = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      final user = ref.read(authStateProvider).user!;
      final service = ref.read(supportServiceProvider);
      final msg = await service.sendMessage(widget.ticket.ticketId, text, user.id);
      if (mounted) {
        setState(() {
          _messages.add(msg);
          _messageController.clear();
        });
      }
    } catch (e) {
      if (mounted) showFToast(context: context, title: const Text('Failed to send message'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.ticket.ticketId),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildTicketHeader(),
                      const Divider(height: 48),
                      ..._messages.map((m) => _buildMessageBubble(m)),
                    ],
                  ),
          ),
          if (widget.ticket.status != 'CLOSED' && widget.ticket.status != 'RESOLVED')
            _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildTicketHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.ticket.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Text(widget.ticket.description, style: const TextStyle(height: 1.5)),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(TicketMessage m) {
    final isMe = m.isMine;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.accent : Colors.grey[200],
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? Radius.zero : null,
            bottomLeft: !isMe ? Radius.zero : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(m.senderName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSub)),
            Text(m.message, style: TextStyle(color: isMe ? Colors.white : AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a reply...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FButton(onPress: _sendMessage, child: const Icon(Icons.send_rounded)),
          ],
        ),
      ),
    );
  }
}
