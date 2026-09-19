import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/features/conversation/data/models/conversation_api_models.dart';

/// Writes to the `conversations` Cloud Function (CONVERSATIONS.md §4). Reads happen through
/// [ConversationsStream]; the responses here only carry ids and the express result.
abstract class ConversationsApi {
  Future<ConversationWriteResponse> create(CreateConversationRequest request);
  Future<ConversationWriteResponse> send(String conversationId, SendMessageRequest request);
  Future<ConversationWriteResponse> requestOptions(String conversationId, ConversationActionRequest request);
  Future<ConversationWriteResponse> redo(String conversationId, ConversationActionRequest request);
  Future<void> patch(String conversationId, ConversationPatchRequest request);

  /// Soft delete: the conversation leaves the user's list (`active: false`) and nothing is
  /// destroyed — the server keeps it, there is no retention policy.
  Future<void> archive(String conversationId);
}

class CloudConversationsApi implements ConversationsApi {
  const CloudConversationsApi(this._api);

  static const String path = '/conversations';

  final CloudFunctionsApi _api;

  @override
  Future<ConversationWriteResponse> create(CreateConversationRequest request) =>
      _api.post(path, body: request.toJson(), fromJson: ConversationWriteResponse.fromJson);

  @override
  Future<ConversationWriteResponse> send(String conversationId, SendMessageRequest request) =>
      _api.post('$path/$conversationId/messages', body: request.toJson(), fromJson: ConversationWriteResponse.fromJson);

  @override
  Future<ConversationWriteResponse> requestOptions(String conversationId, ConversationActionRequest request) =>
      _api.post('$path/$conversationId/options', body: request.toJson(), fromJson: ConversationWriteResponse.fromJson);

  @override
  Future<ConversationWriteResponse> redo(String conversationId, ConversationActionRequest request) =>
      _api.post('$path/$conversationId/redo', body: request.toJson(), fromJson: ConversationWriteResponse.fromJson);

  @override
  Future<void> patch(String conversationId, ConversationPatchRequest request) =>
      _api.patch('$path/$conversationId', body: request.toJson(), fromJson: (json) => json);

  @override
  Future<void> archive(String conversationId) => _api.delete('$path/$conversationId', fromJson: (json) => json);
}
