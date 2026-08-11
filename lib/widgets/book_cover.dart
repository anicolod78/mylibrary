import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/book.dart';

/// Immagine di copertina con placeholder quando manca o fallisce il caricamento.
///
/// - Su **Android/iOS**: `cached_network_image` (con cache su disco).
/// - Su **Web**: `Image.network` con rendering via tag `<img>` HTML
///   (`webHtmlElementStrategy`), necessario perché l'host delle copertine di
///   Google Books (`books.google.com`) non invia gli header CORS e altrimenti
///   il caricamento a byte verrebbe bloccato dal browser.
class BookCover extends StatelessWidget {
  final Book book;
  final double? width;
  final double? height;
  final BoxFit fit;

  const BookCover({
    super.key,
    required this.book,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (!book.hasCover) {
      return _placeholder(context);
    }

    // Copertina locale (scelta da galleria/fotocamera): ha la precedenza.
    if (book.hasLocalCover) {
      try {
        final Uint8List bytes = base64Decode(book.coverData);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => _placeholder(context),
        );
      } catch (_) {
        return _placeholder(context);
      }
    }

    if (kIsWeb) {
      return Image.network(
        book.coverUrl,
        width: width,
        height: height,
        fit: fit,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _loading(),
        errorBuilder: (context, error, stack) => _placeholder(context),
      );
    }

    return CachedNetworkImage(
      imageUrl: book.coverUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => _loading(),
      errorWidget: (context, url, error) => _placeholder(context),
    );
  }

  Widget _loading() => const ColoredBox(
        color: Color(0xFFEDEDED),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFE8EDEE),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_outlined, size: 34, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            book.title.isNotEmpty ? book.title : 'Senza titolo',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
