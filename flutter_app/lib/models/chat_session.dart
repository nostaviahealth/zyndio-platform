import '../providers/chat_provider.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime date;
  final String lastMessage;
  final List<ChatMessage> messages;

  final String? summary;

  const ChatSession({
    required this.id,
    required this.title,
    required this.date,
    required this.lastMessage,
    this.messages = const [],
    this.summary,
  });
  
  // JSON Serialization for SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'lastMessage': lastMessage,
      'messages': messages.map((m) => m.toJson()).toList(),
      'summary': summary,
    };
  }
  
  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'],
      date: DateTime.parse(json['date']),
      lastMessage: json['lastMessage'],
      messages: (json['messages'] as List<dynamic>?)
          ?.map((m) => ChatMessage.fromJson(m))
          .toList() ?? [],
      summary: json['summary'],
    );
  }
}
