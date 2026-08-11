import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../providers/library_provider.dart';
import '../services/book_api_service.dart';
import '../widgets/book_cover.dart';
import 'book_form_screen.dart';
import 'scan_screen.dart';

/// Ricerca online per ISBN o titolo tramite Google Books.
///
/// Se [initialIsbn] è fornito (es. da scansione) la ricerca parte in automatico.
class OnlineSearchScreen extends StatefulWidget {
  final String? initialIsbn;
  const OnlineSearchScreen({super.key, this.initialIsbn});

  @override
  State<OnlineSearchScreen> createState() => _OnlineSearchScreenState();
}

class _OnlineSearchScreenState extends State<OnlineSearchScreen> {
  final _controller = TextEditingController();
  late final BookApiService _api;

  bool _loading = false;
  String? _error;
  List<Book> _results = [];
  bool _searched = false;
  String _lastQuery = '';

  bool _looksLikeIsbn(String s) {
    final d = s.trim().replaceAll(RegExp(r'[\s-]'), '');
    return (d.length == 10 || d.length == 13) &&
        RegExp(r'^[0-9]{9}[0-9Xx]$|^[0-9]{13}$').hasMatch(d);
  }

  @override
  void initState() {
    super.initState();
    // La chiave API (se impostata) viene passata al servizio.
    _api = BookApiService(
      apiKey: context.read<LibraryProvider>().googleApiKey,
    );
    if (widget.initialIsbn != null && widget.initialIsbn!.isNotEmpty) {
      _controller.text = widget.initialIsbn!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
      _lastQuery = q;
    });
    try {
      final results = await _api.searchSmart(q);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Ricerca non riuscita. Controlla la connessione.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Apre lo scanner e, con il nuovo ISBN, rilancia subito la ricerca
  /// (senza tornare alla home).
  Future<void> _rescan() async {
    final isbn = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (isbn != null && isbn.isNotEmpty && mounted) {
      _controller.text = isbn;
      _search();
    }
  }

  Future<void> _openPrefilled(Book book) async {
    final added = await Navigator.push<Book>(
      context,
      MaterialPageRoute(builder: (_) => BookFormScreen(prefill: book)),
    );
    if (added != null && mounted) {
      Navigator.pop(context, added); // torna alla home
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Cerca online')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: widget.initialIsbn == null,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      hintText: 'ISBN o titolo del libro',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  child: const Text('Cerca'),
                ),
              ],
            ),
          ),
          Expanded(child: _body(provider)),
        ],
      ),
    );
  }

  Widget _body(LibraryProvider provider) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _message(Icons.error_outline, _error!);
    }
    if (!_searched) {
      return _message(Icons.travel_explore,
          'Cerca un libro per ISBN o titolo.\nTocca un risultato per aggiungerlo.');
    }
    if (_results.isEmpty) {
      return _noResults(provider);
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final book = _results[i];
        final already = provider.findDuplicate(book) != null;
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: BookCover(book: book, width: 44, height: 64),
          ),
          title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              if (book.author.isNotEmpty) book.author,
              if (book.publisher.isNotEmpty) book.publisher,
              if (book.year.isNotEmpty) book.year,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: already
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.add_circle_outline),
          onTap: () {
            if (already) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Già presente in archivio')),
              );
            } else {
              _openPrefilled(book);
            }
          },
        );
      },
    );
  }

  /// Nessun risultato: se la query era un ISBN offriamo l'inserimento manuale
  /// (con l'ISBN già compilato) e, se manca la chiave, un suggerimento.
  Widget _noResults(LibraryProvider provider) {
    final wasIsbn = _looksLikeIsbn(_lastQuery);
    final noKey = provider.googleApiKey.trim().isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              wasIsbn
                  ? 'Nessun dato online per l\'ISBN $_lastQuery.'
                  : 'Nessun risultato trovato.',
              textAlign: TextAlign.center,
            ),
            if (wasIsbn && noKey) ...[
              const SizedBox(height: 10),
              const Text(
                'Suggerimento: imposta una chiave API Google Books (menu ⋮ → Impostazioni) '
                'per ottenere i dati dei libri italiani.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scansiona di nuovo'),
                  onPressed: _rescan,
                ),
                if (wasIsbn)
                  FilledButton.icon(
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Inserisci manualmente'),
                    onPressed: () => _openPrefilled(
                      Book.create(
                          isbn: _lastQuery.replaceAll(RegExp(r'[\s-]'), '')),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
