import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../providers/library_provider.dart';
import '../widgets/book_cover.dart';
import '../widgets/filter_panel.dart';
import '../widgets/star_rating.dart';
import 'book_detail_screen.dart';
import 'book_form_screen.dart';
import 'online_search_screen.dart';
import 'scan_screen.dart';
import 'shelves_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showFilters = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    final books = provider.books;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        actions: [
          IconButton(
            tooltip: 'Filtri',
            icon: Icon(
              _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          _sortMenu(provider),
          _overflowMenu(provider),
        ],
      ),
      body: Column(
        children: [
          if (_showFilters) FilterPanel(provider: provider),
          _countBar(context, provider, books.length),
          Expanded(
            child: books.isEmpty
                ? _emptyState(context, provider)
                : _grid(context, books),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(context),
    );
  }

  // --- Griglia copertine ---

  Widget _grid(BuildContext context, List<Book> books) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: books.length,
      itemBuilder: (_, i) {
        final book = books[i];
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookDetailScreen(bookId: book.id),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: BookCover(book: book),
                      ),
                    ),
                    if (book.status != ReadingStatus.toRead)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _statusBadge(book.status),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, height: 1.15),
              ),
              if (book.rating > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Center(child: StarRating(rating: book.rating, size: 12)),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Piccolo badge di stato (mostrato solo per "in lettura" e "letto").
  Widget _statusBadge(ReadingStatus status) {
    final read = status == ReadingStatus.read;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: read ? Colors.green : Colors.orange,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
      ),
      child: Icon(
        read ? Icons.check : Icons.menu_book,
        size: 13,
        color: Colors.white,
      ),
    );
  }

  Widget _countBar(
      BuildContext context, LibraryProvider provider, int shown) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF3F5F6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            provider.hasActiveFilters
                ? '$shown di ${provider.totalCount} libri'
                : '${provider.totalCount} libri',
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const Spacer(),
          if (provider.hasActiveFilters)
            TextButton.icon(
              onPressed: provider.clearFilters,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Azzera filtri'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  // --- Stato vuoto ---

  Widget _emptyState(BuildContext context, LibraryProvider provider) {
    final filtered = provider.hasActiveFilters;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(filtered ? Icons.search_off : Icons.auto_stories_outlined,
                size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              filtered
                  ? 'Nessun libro corrisponde ai filtri.'
                  : 'Il tuo catalogo è vuoto.\nAggiungi un libro dai pulsanti in basso.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  // --- Menu ordinamento ---

  Widget _sortMenu(LibraryProvider provider) {
    return PopupMenuButton<BookSort>(
      tooltip: 'Ordina',
      icon: const Icon(Icons.swap_vert),
      initialValue: provider.sort,
      onSelected: provider.setSort,
      itemBuilder: (_) => BookSort.values
          .map((s) => PopupMenuItem(value: s, child: Text(s.label)))
          .toList(),
    );
  }

  // --- Menu overflow (export/import) ---

  Widget _overflowMenu(LibraryProvider provider) {
    return PopupMenuButton<String>(
      tooltip: 'Altro',
      onSelected: (v) {
        if (v == 'shelves') {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ShelvesScreen()));
        }
        if (v == 'stats') {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const StatsScreen()));
        }
        if (v == 'export') _export(provider);
        if (v == 'export_csv') _exportCsv(provider);
        if (v == 'import') _import(provider);
        if (v == 'settings') _openSettings(provider);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'shelves',
          child: ListTile(
            leading: Icon(Icons.shelves),
            title: Text('Gestisci scaffali'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'stats',
          child: ListTile(
            leading: Icon(Icons.bar_chart),
            title: Text('Statistiche di lettura'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'export',
          child: ListTile(
            leading: Icon(Icons.upload_file),
            title: Text('Esporta libreria'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'export_csv',
          child: ListTile(
            leading: Icon(Icons.table_view),
            title: Text('Esporta CSV'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'import',
          child: ListTile(
            leading: Icon(Icons.download),
            title: Text('Importa libreria'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.key),
            title: Text('Impostazioni'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  // --- Barra azioni inferiore ---

  Widget _bottomBar(BuildContext context) {
    return BottomAppBar(
      color: const Color(0xFFF3F5F6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomAction(
            icon: Icons.search,
            label: 'Cerca online',
            onTap: () => _openOnlineSearch(context),
          ),
          _bottomAction(
            icon: Icons.qr_code_scanner,
            label: 'Scansione ISBN',
            onTap: () => _startScan(context),
          ),
          _bottomAction(
            icon: Icons.edit_note,
            label: 'Aggiungi manuale',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookFormScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF3E7C88)),
              const SizedBox(height: 3),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF3E7C88))),
            ],
          ),
        ),
      ),
    );
  }

  // --- Azioni ---

  Future<void> _openOnlineSearch(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnlineSearchScreen()),
    );
  }

  Future<void> _startScan(BuildContext context) async {
    final isbn = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (isbn != null && isbn.isNotEmpty && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineSearchScreen(initialIsbn: isbn),
        ),
      );
    }
  }

  Future<void> _export(LibraryProvider provider) async {
    try {
      final json = provider.exportToJson();
      final bytes = Uint8List.fromList(utf8.encode(json));
      final name = 'mylibrary_${DateTime.now().millisecondsSinceEpoch}';
      // saveAs apre il dialog "Salva con nome" (Android/desktop) o avvia il
      // download (Web). Restituisce null se l'utente annulla.
      final path = await FileSaver.instance.saveAs(
        name: name,
        bytes: bytes,
        fileExtension: 'json',
        mimeType: MimeType.json,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Libreria esportata (${provider.totalCount} libri)')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export non riuscito')),
        );
      }
    }
  }

  Future<void> _exportCsv(LibraryProvider provider) async {
    try {
      final csv = provider.exportToCsv();
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final name = 'mylibrary_${DateTime.now().millisecondsSinceEpoch}';
      final path = await FileSaver.instance.saveAs(
        name: name,
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('CSV esportato (${provider.totalCount} libri, senza immagini)')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export CSV non riuscito')),
        );
      }
    }
  }

  Future<void> _import(LibraryProvider provider) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      if (file.bytes == null) {
        throw Exception('File non leggibile');
      }
      final content = utf8.decode(file.bytes!);

      if (!mounted) return;
      final merge = await _askMerge();
      if (merge == null) return;

      final r = await provider.importFromJson(content, merge: merge);
      if (mounted) {
        final msg = r.skipped > 0
            ? 'Importati ${r.added} libri (${r.skipped} duplicati ignorati)'
            : 'Importati ${r.added} libri';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import non riuscito: file non valido')),
        );
      }
    }
  }

  Future<void> _openSettings(LibraryProvider provider) async {
    final controller =
        TextEditingController(text: provider.googleApiKey);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chiave API Google Books'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Serve per la ricerca affidabile dei libri (soprattutto ISBN italiani) '
              'ed evita l\'errore 429. È gratuita: creala su Google Cloud Console, '
              'attiva "Books API" e genera una chiave API.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Chiave API',
                hintText: 'AIza...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await provider.setGoogleApiKey(controller.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(controller.text.trim().isEmpty
                ? 'Chiave rimossa'
                : 'Chiave API salvata'),
          ),
        );
      }
    }
    controller.dispose();
  }

  Future<bool?> _askMerge() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importa libreria'),
        content: const Text(
            'Vuoi unire i libri al catalogo esistente o sostituirlo completamente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Sostituisci'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unisci'),
          ),
        ],
      ),
    );
  }
}
