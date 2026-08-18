import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../providers/library_provider.dart';
import '../services/book_api_service.dart';
import '../widgets/book_cover.dart';
import '../widgets/star_rating.dart';
import 'book_form_screen.dart';

class BookDetailScreen extends StatelessWidget {
  final String bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    // Ci si aggancia al provider così le modifiche si riflettono subito.
    final provider = context.watch<LibraryProvider>();
    Book? book;
    for (final b in provider.books) {
      if (b.id == bookId) {
        book = b;
        break;
      }
    }

    if (book == null) {
      // Il libro è stato eliminato: torniamo indietro.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final b = book;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna dai dati online',
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: () => _updateFromSources(context, b),
          ),
          IconButton(
            tooltip: 'Modifica',
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookFormScreen(existing: b),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Elimina',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, b),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BookCover(book: b, width: 170, height: 240),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            b.title.isNotEmpty ? b.title : 'Senza titolo',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          if (b.author.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              b.author,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          _statusChips(context, b),
          const SizedBox(height: 14),
          _ratingRow(context, b),
          const SizedBox(height: 16),
          _row(context, Icons.shelves, 'Scaffale',
              b.shelf.isNotEmpty ? b.shelf : '—'),
          _row(context, Icons.category, 'Genere', b.categories),
          _row(context, Icons.business, 'Editore', b.publisher),
          _row(context, Icons.calendar_today, 'Anno', b.year),
          _row(context, Icons.menu_book, 'Pagine',
              b.pages > 0 ? '${b.pages}' : ''),
          _row(context, Icons.qr_code, 'ISBN', b.isbn),
          _readingSessions(context, b),
          if (b.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Sinossi',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(b.description,
                style: const TextStyle(fontSize: 14, height: 1.35)),
          ],
          if (b.review.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('La mia recensione',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(b.review,
                style: const TextStyle(
                    fontSize: 14, height: 1.35, fontStyle: FontStyle.italic)),
          ],
          if (b.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            _row(context, Icons.notes, 'Note', b.note),
          ],
        ],
      ),
    );
  }

  /// Valutazione a stelle modificabile direttamente dal dettaglio.
  Widget _ratingRow(BuildContext context, Book b) {
    final provider = context.read<LibraryProvider>();
    return Column(
      children: [
        const Text('Valutazione',
            style: TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 4),
        StarRating(
          rating: b.rating,
          size: 32,
          onChanged: (v) => provider.setRating(b, v),
        ),
      ],
    );
  }

  /// Chip per cambiare rapidamente lo stato di lettura.
  Widget _statusChips(BuildContext context, Book b) {
    final provider = context.read<LibraryProvider>();
    return Wrap(
      spacing: 8,
      alignment: WrapAlignment.center,
      children: ReadingStatus.values.map((s) {
        final selected = b.status == s;
        return ChoiceChip(
          label: Text(s.label),
          selected: selected,
          onSelected: (_) => provider.setStatus(b, s),
        );
      }).toList(),
    );
  }

  Widget _readingSessions(BuildContext context, Book b) {
    if (b.readingSessions.isEmpty) return const SizedBox.shrink();
    String fmt(DateTime? d) => d == null
        ? '—'
        : '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/${d.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_stories,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 14),
              const SizedBox(
                width: 80,
                child: Text('Letture',
                    style: TextStyle(
                        color: Colors.black54, fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in b.readingSessions)
                      Text('${fmt(s.start)} → ${fmt(s.end)}',
                          style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.black54, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  /// Recupera i dati dalle fonti online e **integra solo i campi mancanti**,
  /// senza toccare i dati personali (scaffale, stato, letture, recensione,
  /// note, copertina personalizzata).
  Future<void> _updateFromSources(BuildContext context, Book book) async {
    final provider = context.read<LibraryProvider>();
    final api = BookApiService(apiKey: provider.googleApiKey);

    // Dialog di caricamento non chiudibile.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Book? fetched;
    try {
      if (book.isbn.trim().isNotEmpty) {
        fetched = await api.searchByIsbn(book.isbn);
      } else if (book.title.trim().isNotEmpty) {
        final list = await api.searchByTitle(book.title, maxResults: 1);
        fetched = list.isNotEmpty ? list.first : null;
      }
    } catch (_) {
      fetched = null;
    } finally {
      api.dispose();
    }

    if (!context.mounted) return;
    Navigator.pop(context); // chiude il loader

    if (fetched == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun dato trovato online')),
      );
      return;
    }

    // Riempi solo i campi vuoti/mancanti.
    final f = fetched;
    final changed = <String>[];
    String keepOrFill(String cur, String neu, String label) {
      if (cur.trim().isEmpty && neu.trim().isNotEmpty) {
        changed.add(label);
        return neu;
      }
      return cur;
    }

    int newPages = book.pages;
    if (book.pages == 0 && f.pages > 0) {
      newPages = f.pages;
      changed.add('pagine');
    }
    final hasCover =
        book.coverData.isNotEmpty || book.coverUrl.trim().isNotEmpty;
    String newCover = book.coverUrl;
    if (!hasCover && f.coverUrl.trim().isNotEmpty) {
      newCover = f.coverUrl;
      changed.add('copertina');
    }

    final updated = book.copyWith(
      title: keepOrFill(book.title, f.title, 'titolo'),
      author: keepOrFill(book.author, f.author, 'autore'),
      publisher: keepOrFill(book.publisher, f.publisher, 'editore'),
      year: keepOrFill(book.year, f.year, 'anno'),
      description: keepOrFill(book.description, f.description, 'sinossi'),
      categories: keepOrFill(book.categories, f.categories, 'genere'),
      pages: newPages,
      coverUrl: newCover,
    );

    if (changed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun nuovo dato da integrare')),
      );
      return;
    }

    await provider.update(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aggiornati: ${changed.join(', ')}')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, Book book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare il libro?'),
        content: Text('"${book.title}" verrà rimosso dal catalogo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<LibraryProvider>().remove(book.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
