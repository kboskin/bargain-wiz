import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:appwizard/features/conversation/data/models/conversation_documents.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';

/// Live reads of the user's conversations (Firestore listeners; owner-only rules, no writes).
abstract class ConversationsStream {
  /// Active (not archived) conversations, newest activity first.
  Stream<List<Conversation>> watchConversations(String uid);

  /// Messages of one conversation in server order.
  Stream<List<ProDealCloserMessage>> watchMessages(String uid, String conversationId);

  /// One conversation document; null once it no longer exists. Express reads its result here,
  /// because the backend queues the model call and writes the answer when it lands.
  Stream<Conversation?> watchConversation(String uid, String conversationId);
}

class FirestoreConversationsStream implements ConversationsStream {
  FirestoreConversationsStream({FirebaseFirestore? firestore, this.limit = 100}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  final int limit;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _conversations(String uid) =>
      _db.collection('users').doc(uid).collection('conversations');

  @override
  Stream<List<Conversation>> watchConversations(String uid) => _conversations(uid)
      .where('active', isEqualTo: true)
      .orderBy('updated_at', descending: true)
      .limit(limit)
      .snapshots()
      .map((snapshot) => [for (final doc in snapshot.docs) ConversationDocuments.conversation(doc.id, doc.data())]);

  @override
  Stream<Conversation?> watchConversation(String uid, String conversationId) => _conversations(uid)
      .doc(conversationId)
      .snapshots()
      .map((doc) => doc.exists ? ConversationDocuments.conversation(doc.id, doc.data()!) : null);

  @override
  Stream<List<ProDealCloserMessage>> watchMessages(String uid, String conversationId) => _conversations(uid)
      .doc(conversationId)
      .collection('messages')
      .orderBy('seq')
      .snapshots()
      // The backend records the system prompt the deal started with as the seq-0 message
      // (CONVERSATIONS.md). It is configuration, not something the buyer said or was told,
      // so it never reaches the chat.
      .map((snapshot) => [
            for (final doc in snapshot.docs)
              if (!ConversationDocuments.isSystem(doc.data())) ConversationDocuments.message(doc.id, doc.data()),
          ]);
}
