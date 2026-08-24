import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/message.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/message_service.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class FamilyMessagesScreen extends StatefulWidget {
  const FamilyMessagesScreen({super.key});

  @override
  State<FamilyMessagesScreen> createState() => _FamilyMessagesScreenState();
}

class _FamilyMessagesScreenState extends State<FamilyMessagesScreen> {
  final MessageService _messageService = MessageService();
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _currentUserId = user.id;
    });

    try {
      final conversations = await _messageService.getConversations(user.id);
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            isDark
                ? 'assets/images/ChatGPT_Image_Aug_3_2026_07_26_30_AM.png'
                : 'assets/images/Misty_Mountain_Sunrise_Road.png',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.black.withValues(alpha: 0.3),
          elevation: 0,
          title: const Text('Messages'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _conversations.isEmpty
                ? _buildEmptyState()
                : _buildConversationsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        return _ConversationCard(
          conversation: conversation,
          currentUserId: _currentUserId!,
          onTap: () => _openConversation(conversation),
        );
      },
    );
  }

  void _openConversation(Map<String, dynamic> conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ConversationDetailScreen(
          otherUserId: conversation['userId'],
          otherUserName: conversation['userName'],
          otherUserImage: conversation['userImage'],
          currentUserId: _currentUserId!,
        ),
      ),
    ).then((_) => _loadConversations());
  }
}

class _ConversationCard extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const _ConversationCard({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unreadCount = conversation['unreadCount'] as int;
    final lastMessageTime = conversation['lastMessageTime'] as DateTime;
    final timeAgo = _formatTimeAgo(lastMessageTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 28,
          backgroundImage: conversation['userImage'] != null
              ? NetworkImage(conversation['userImage'])
              : null,
          child: conversation['userImage'] == null
              ? Text(
                  (conversation['userName'] as String).substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Text(
          conversation['userName'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          conversation['lastMessage'],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              timeAgo,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xff2f91ff),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(time);
  }
}

class _ConversationDetailScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImage;
  final String currentUserId;

  const _ConversationDetailScreen({
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserImage,
    required this.currentUserId,
  });

  @override
  State<_ConversationDetailScreen> createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<_ConversationDetailScreen> {
  final MessageService _messageService = MessageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    try {
      final messages = await _messageService.getMessages(
        widget.currentUserId,
        widget.otherUserId,
      );
      
      // Mark messages as read
      await _messageService.markAsRead(widget.currentUserId, widget.otherUserId);

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final message = Message(
      id: const Uuid().v4(),
      senderId: widget.currentUserId,
      receiverId: widget.otherUserId,
      senderName: 'You',
      receiverName: widget.otherUserName,
      senderImageUrl: null,
      receiverImageUrl: widget.otherUserImage,
      content: content,
      isRead: false,
      createdAt: DateTime.now(),
    );

    _messageController.clear();
    
    setState(() => _messages.add(message));
    _scrollToBottom();

    try {
      await _messageService.sendMessage(message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            isDark
                ? 'assets/images/ChatGPT_Image_Aug_3_2026_07_26_30_AM.png'
                : 'assets/images/Misty_Mountain_Sunrise_Road.png',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.black.withValues(alpha: 0.3),
          elevation: 0,
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: widget.otherUserImage != null
                    ? NetworkImage(widget.otherUserImage!)
                    : null,
                child: widget.otherUserImage == null
                    ? Text(
                        widget.otherUserName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 16),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Text(widget.otherUserName),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? _buildEmptyState()
                      : _buildMessagesList(),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Start a conversation',
        style: TextStyle(
          fontSize: 16,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == widget.currentUserId;
        
        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(0xff2f91ff)
                  : Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: !isMe
                  ? Border.all(color: Colors.white.withValues(alpha: 0.1))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(message.createdAt),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xff2f91ff),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
