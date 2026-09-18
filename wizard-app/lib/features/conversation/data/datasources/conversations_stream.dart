import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:appwizard/features/conversation/data/models/conversation_documents.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';

/// Live reads of the user's conversations (Firestore listeners; owner-only rules, no writes).
abstract class ConversationsStream {
  /// Active (not archived) conversations, newest activity first.
  Stream<List<Conversation>> watchConversations(String uid);

  /// Messages of one conversation in server order.
  Stream<List<ProDealCloserMessage>> watchMessages(String uid, String conversationId);
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
  Stream<List<ProDealCloserMessage>> watchMessages(String uid, String conversationId) => _conversations(uid)
      .doc(conversationId)
      .collection('messages')
      .orderBy('seq')
      .snapshots()
      .map((snapshot) => [for (final doc in snapshot.docs) ConversationDocuments.message(doc.id, doc.data())]);
}
