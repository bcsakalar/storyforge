import '../models/message.dart';
import 'api_service.dart';

class MessageService {
  final ApiService _api;

  MessageService(this._api);

  Future<List<Conversation>> getConversations() async {
    final response = await _api.get('/messages/conversations');
    return (response.data['conversations'] as List).map((c) => Conversation.fromJson(c)).toList();
  }

  Future<List<Message>> getMessages(int userId, {int? cursor}) async {
    final params = <String, dynamic>{};
    if (cursor != null) params['cursor'] = cursor.toString();
    final response = await _api.get('/messages/$userId', queryParameters: params);
    return (response.data['messages'] as List).map((m) => Message.fromJson(m)).toList();
  }

  Future<Message> sendMessage(int userId, String content, {String? messageType, String? imageUrl}) async {
    final data = <String, dynamic>{'content': content};
    if (messageType != null) data['messageType'] = messageType;
    if (imageUrl != null) data['imageUrl'] = imageUrl;
    final response = await _api.post('/messages/$userId', data: data);
    return Message.fromJson(response.data['message']);
  }

  Future<void> markAsRead(int userId) async {
    await _api.put('/messages/$userId/read');
  }
}
