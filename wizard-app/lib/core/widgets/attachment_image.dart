import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

typedef StorageBytesLoader = Future<Uint8List?> Function(String path);

/// Bytes of the user's own screenshots in Cloud Storage, cached per object path for the
/// app session. Storage rules let only the owner read `users/{uid}/…` (CONVERSATIONS.md §6).
class StorageImageCache {
  StorageImageCache._();

  static final StorageImageCache instance = StorageImageCache._();

  /// Server-side re-encoding keeps objects well under this.
  static const int maxBytes = 6 * 1024 * 1024;
  static const int maxEntries = 60;

  /// Test seam: replace to avoid touching Firebase.
  StorageBytesLoader loader = (path) => FirebaseStorage.instance.ref(path).getData(maxBytes);

  final Map<String, Future<Uint8List?>> _futures = {};

  Future<Uint8List?> load(String path) {
    final cached = _futures[path];
    if (cached != null) return cached;
    final future = _load(path);
    _futures[path] = future;
    while (_futures.length > maxEntries) {
      _futures.remove(_futures.keys.first);
    }
    return future;
  }

  Future<Uint8List?> _load(String path) async {
    try {
      return await loader(path);
    } on Object {
      _futures.remove(path); // let the next build retry
      return null;
    }
  }

  void clear() => _futures.clear();
}

/// A screenshot from a local file path or, for backend-stored attachments, from Cloud Storage.
///
/// Local paths are absolute (`/…`); anything else is treated as a Storage object path.
class AttachmentImage extends StatelessWidget {
  const AttachmentImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.gaplessPlayback = false,
    this.placeholder,
    this.errorWidget,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final bool gaplessPlayback;
  /// Shown while a stored image downloads.
  final Widget? placeholder;
  /// Shown when the file is missing or the download failed.
  final Widget? errorWidget;

  static bool isStoragePath(String path) =>
      path.isNotEmpty && !path.startsWith('/') && !path.startsWith('file:');

  @override
  Widget build(BuildContext context) {
    if (!isStoragePath(path)) {
      return Image.file(
        File(path),
        fit: fit,
        width: width,
        height: height,
        gaplessPlayback: gaplessPlayback,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return FutureBuilder<Uint8List?>(
      future: StorageImageCache.instance.load(path),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(
            bytes,
            fit: fit,
            width: width,
            height: height,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _fallback(),
          );
        }
        if (snapshot.connectionState == ConnectionState.done) return _fallback();
        return placeholder ?? _fallback();
      },
    );
  }

  Widget _fallback() =>
      errorWidget ?? SizedBox(width: width, height: height, child: const ColoredBox(color: Color(0x14000000)));
}
