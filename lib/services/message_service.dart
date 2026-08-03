import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wellspring/models/message.dart';
import 'package:wellspring/services/notification_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';

class MessageService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  Future<List<Map<String, dynamic>>> getConversations(String currentUserId) async {
    try {
      final data = await _supabase
          .from('messages')
          .select()
          .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
          .order('created_at', ascending: false);
      
      final messages = data.map((json) => Message.fromJson({
        'id': json['id'],
        'senderId': json['sender_id'],
        'receiverId': json['receiver_id'],
        'senderName': json['sender_name'],
        'receiverName': json['receiver_name'],
        'senderImageUrl': json['sender_image_url'],
        'receiverImageUrl': json['receiver_image_url'],
        'content': json['content'],
        'isRead': json['is_read'],
        'createdAt': json['created_at'],
      })).toList();
      
      final conversationsMap = <String, Message>{};
      for (var msg in messages) {
        final otherUserId = msg.senderId == currentUserId ? msg.receiverId : msg.senderId;
        if (!conversationsMap.containsKey(otherUserId) || msg.createdAt.isAfter(conversationsMap[otherUserId]!.createdAt)) {
          conversationsMap[otherUserId] = msg;
        }
      }
      
      final conversations = conversationsMap.values.map((msg) {
        final otherUserId = msg.senderId == currentUserId ? msg.receiverId : msg.senderId;
        final otherUserName = msg.senderId == currentUserId ? msg.receiverName : msg.senderName;
        final otherUserImage = msg.senderId == currentUserId ? msg.receiverImageUrl : msg.senderImageUrl;
        final unreadCount = messages.where((m) => 
          m.senderId == otherUserId && m.receiverId == currentUserId && !m.isRead
        ).length;
        
        return {
          'userId': otherUserId,
          'userName': otherUserName,
          'userImage': otherUserImage,
          'lastMessage': msg.content,
          'lastMessageTime': msg.createdAt,
          'unreadCount': unreadCount,
        };
      }).toList()..sort((a, b) => (b['lastMessageTime'] as DateTime).compareTo(a['lastMessageTime'] as DateTime));
      
      return conversations;
    } catch (e) {
      debugPrint('MessageService.getConversations error: $e');
      return [];
    }
  }

  Future<List<Message>> getMessages(String currentUserId, String otherUserId) async {
    try {
      final data = await _supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$currentUserId)')
          .order('created_at', ascending: true);
      
      return data.map((json) => Message.fromJson({
        'id': json['id'],
        'senderId': json['sender_id'],
        'receiverId': json['receiver_id'],
        'senderName': json['sender_name'],
        'receiverName': json['receiver_name'],
        'senderImageUrl': json['sender_image_url'],
        'receiverImageUrl': json['receiver_image_url'],
        'content': json['content'],
        'isRead': json['is_read'],
        'createdAt': json['created_at'],
      })).toList();
    } catch (e) {
      debugPrint('MessageService.getMessages error: $e');
      return [];
    }
  }

  Future<void> sendMessage(Message message) async {
    try {
      await _supabase.from('messages').insert({
        'id': message.id,
        'sender_id': message.senderId,
        'receiver_id': message.receiverId,
        'sender_name': message.senderName,
        'receiver_name': message.receiverName,
        'sender_image_url': message.senderImageUrl,
        'receiver_image_url': message.receiverImageUrl,
        'content': message.content,
        'is_read': message.isRead,
        'created_at': message.createdAt.toIso8601String(),
      });
      
      // Send notification to receiver
      try {
        await NotificationService.instance.notifyNewMessage(
          senderName: message.senderName,
          messagePreview: message.content.length > 100 
            ? '${message.content.substring(0, 100)}...' 
            : message.content,
          senderId: message.senderId,
        );
      } catch (e) {
        debugPrint('MessageService.sendMessage: notification error: $e');
      }
    } catch (e) {
      debugPrint('MessageService.sendMessage error: $e');
      rethrow;
    }
  }

  Future<void> markAsRead(String currentUserId, String otherUserId) async {
    try {
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('sender_id', otherUserId)
          .eq('receiver_id', currentUserId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('MessageService.markAsRead error: $e');
      rethrow;
    }
  }
}
