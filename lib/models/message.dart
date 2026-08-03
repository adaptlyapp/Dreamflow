class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String receiverName;
  final String? senderImageUrl;
  final String? receiverImageUrl;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.receiverName,
    this.senderImageUrl,
    this.receiverImageUrl,
    required this.content,
    this.isRead = false,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'],
    senderId: json['senderId'],
    receiverId: json['receiverId'],
    senderName: json['senderName'],
    receiverName: json['receiverName'],
    senderImageUrl: json['senderImageUrl'],
    receiverImageUrl: json['receiverImageUrl'],
    content: json['content'],
    isRead: json['isRead'] ?? false,
    createdAt: DateTime.parse(json['createdAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'receiverId': receiverId,
    'senderName': senderName,
    'receiverName': receiverName,
    'senderImageUrl': senderImageUrl,
    'receiverImageUrl': receiverImageUrl,
    'content': content,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
  };

  Message copyWith({bool? isRead}) => Message(
    id: id,
    senderId: senderId,
    receiverId: receiverId,
    senderName: senderName,
    receiverName: receiverName,
    senderImageUrl: senderImageUrl,
    receiverImageUrl: receiverImageUrl,
    content: content,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );
}
