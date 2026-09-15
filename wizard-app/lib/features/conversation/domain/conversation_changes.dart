import 'package:flutter/foundation.dart';

/// Fires whenever a conversation is saved, deleted or cleared through the
/// [ConversationRepository] implementation. Screens that list conversations
/// (Bargains History, Home) listen and reload, so features that save deals
/// (Express, Pro) need no extra wiring.
class ConversationChanges extends ChangeNotifier {
  ConversationChanges();

  /// App-wide instance used by the repository when none is injected.
  static final ConversationChanges instance = ConversationChanges();

  int _version = 0;

  /// Monotonic counter, incremented on every change.
  int get version => _version;

  void bump() {
    _version++;
    notifyListeners();
  }
}
