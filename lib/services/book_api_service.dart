import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/book.dart';

/// Ricerca online dei libri, con più fonti in cascata:
///
/// 1. **Google Books API** (primaria; con chiave evita il 429).
/// 2. **OPAC SBN** (Servizio Bibliotecario Nazionale) — ottima per i libri
///    italiani, sia per ISBN che per titolo. Su Web può essere bloccata dal
///    CORS; su Android funziona.
/// 3. **Open Library** — ultimo fallback (buona per i titoli internazionali).
///
/// Ogni fonte viene provata solo se la precedente non risponde o non trova
/// nulla, così la ricerca resta funzionante anche quando una fonte è a quota.
class BookApiService {
  static const String _googleBase =
      'https://www.googleapis.com/books/v1/volumes';
  static const String _olBase = 'https://openlibrary.org';
  static const String _olCovers = 'https://covers.openlibrary.org/b';
  // OPAC SBN (Servizio Bibliotecario Nazionale) — API JSON mobile.
  static const String _sbnBase =
      'https://opac.sbn.it/opacmobilegw/search.json';

  final http.Client _client;

  /// Chiave API Google Books (opzionale). Se presente, le richieste a Google
  /// usano la quota del progetto dell'utente ed evitano l'errore 429.
  final String? apiKey;

  BookApiService({http.Client? client, this.apiKey})
      : _client = client ?? http.Client();

  bool get _hasKey => apiKey != null && apiKey!.trim().isNotEmpty;

  /// Cerca per ISBN interrogando **tutte le fonti in parallelo** e unendo i
  /// campi per ottenere la scheda più completa possibile. La priorità dei campi
  /// segue l'ordine: Google Books → OPAC SBN → Open Library.
  /// Restituisce null se nessuna fonte trova il libro.
  Future<Book?> searchByIsbn(String isbn) async {
    final clean = isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
    if (clean.isEmpty) return null;

    final results = await Future.wait<Book?>([
      _googleFirst('isbn:$clean'),
      _sbnFirst(clean, isbn: true),
      _openLibraryByIsbn(clean),
      _openLibrarySearchByIsbn(clean),
    ]);

    // Ordine di priorità: Google, SBN, Open Library (dettaglio), OL (ricerca).
    final merged = _mergeBooks(results);
    if (merged == null || merged.title.trim().isEmpty) return null;
    return merged;
  }

  /// Cerca per titolo interrogando le fonti **in parallelo** e unendo i
  /// risultati che rappresentano lo stesso libro, per schede più complete.
  Future<List<Book>> searchByTitle(String query, {int maxResults = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final lists = await Future.wait<List<Book>>([
      _googleList('intitle:${Uri.encodeComponent(q)}', maxResults: maxResults),
      _opacSbn(q, isbn: false, maxResults: maxResults),
      _openLibrarySearch(q, maxResults: maxResults),
    ]);

    return _combineLists(lists, maxResults: maxResults);
  }

  /// Ricerca generica: ISBN se il testo lo è, altrimenti titolo.
  Future<List<Book>> searchSmart(String input, {int maxResults = 20}) async {
    final trimmed = input.trim();
    final digits = trimmed.replaceAll(RegExp(r'[\s-]'), '');
    final isIsbn = (digits.length == 10 || digits.length == 13) &&
        RegExp(r'^[0-9]{9}[0-9Xx]$|^[0-9]{13}$').hasMatch(digits);
    if (isIsbn) {
      final b = await searchByIsbn(digits);
      return b == null ? [] : [b];
    }
    return searchByTitle(trimmed, maxResults: maxResults);
  }

  // ----------------- Helper multi-fonte (parallelo + merge) -----------------

  /// Google Books tollerante agli errori (429, rete): [] invece di eccezione.
  Future<List<Book>> _googleList(String q, {int maxResults = 20}) async {
    try {
      return await _google(q, maxResults: maxResults);
    } catch (_) {
      return [];
    }
  }

  Future<Book?> _googleFirst(String q) async {
    final list = await _googleList(q, maxResults: 1);
    return list.isEmpty ? null : list.first;
  }

  Future<Book?> _sbnFirst(String query, {required bool isbn}) async {
    final list = await _opacSbn(query, isbn: isbn, maxResults: 1);
    return list.isEmpty ? null : list.first;
  }

  /// Unisce più versioni dello stesso libro prendendo, per ciascun campo, il
  /// primo valore non vuoto secondo l'ordine di priorità della lista.
  Book? _mergeBooks(List<Book?> candidates) {
    final list = candidates.whereType<Book>().where((b) => b.title.trim().isNotEmpty).toList();
    if (list.isEmpty) return null;

    String pick(String Function(Book) f) {
      for (final b in list) {
        final v = f(b).trim();
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    int pickInt(int Function(Book) f) {
      for (final b in list) {
        final v = f(b);
        if (v > 0) return v;
      }
      return 0;
    }

    return list.first.copyWith(
      isbn: pick((b) => b.isbn),
      title: pick((b) => b.title),
      author: pick((b) => b.author),
      publisher: pick((b) => b.publisher),
      year: pick((b) => b.year),
      coverUrl: pick((b) => b.coverUrl),
      description: pick((b) => b.description),
      categories: pick((b) => b.categories),
      pages: pickInt((b) => b.pages),
    );
  }

  /// Combina liste da più fonti (in ordine di priorità): deduplica per ISBN o
  /// titolo+autore e arricchisce i campi mancanti dalle altre fonti.
  List<Book> _combineLists(List<List<Book>> lists, {int maxResults = 20}) {
    final ordered = <Book>[];
    final index = <String, int>{}; // chiave → posizione in ordered

    String keyOf(Book b) {
      final isbn = b.isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
      if (isbn.isNotEmpty) return 'i:$isbn';
      return 't:${b.title.toLowerCase().trim()}|${b.author.toLowerCase().trim()}';
    }

    for (final list in lists) {
      for (final b in list) {
        if (b.title.trim().isEmpty) continue;
        final key = keyOf(b);
        if (index.containsKey(key)) {
          // Arricchisce il record già presente con i campi mancanti.
          ordered[index[key]!] = _mergeBooks([ordered[index[key]!], b])!;
        } else {
          index[key] = ordered.length;
          ordered.add(b);
        }
      }
    }
    return ordered.take(maxResults).toList();
  }

  // ----------------- Google Books -----------------

  Future<List<Book>> _google(String q, {int maxResults = 20}) async {
    final keyParam = _hasKey ? '&key=${apiKey!.trim()}' : '';
    // projection=full garantisce i campi completi (pageCount, description, ...).
    final uri = Uri.parse(
        '$_googleBase?q=$q&maxResults=$maxResults&printType=books&projection=full$keyParam');
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Google Books HTTP ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final items = data['items'];
    if (items is! List) return [];
    return items.map(_parseGoogleVolume).whereType<Book>().toList();
  }

  Book? _parseGoogleVolume(dynamic item) {
    if (item is! Map) return null;
    final info = item['volumeInfo'];
    if (info is! Map) return null;

    final title = (info['title'] ?? '').toString();
    final subtitle = (info['subtitle'] ?? '').toString();
    final fullTitle = subtitle.isNotEmpty ? '$title. $subtitle' : title;

    final authors = info['authors'];
    final author = authors is List ? authors.join(', ') : '';
    final publisher = (info['publisher'] ?? '').toString();
    final published = (info['publishedDate'] ?? '').toString();
    final year = published.length >= 4 ? published.substring(0, 4) : published;
    final isbn = _extractGoogleIsbn(info['industryIdentifiers']);

    String cover = '';
    final images = info['imageLinks'];
    if (images is Map) {
      cover = (images['thumbnail'] ??
              images['smallThumbnail'] ??
              images['small'] ??
              '')
          .toString();
      cover = cover.replaceFirst('http://', 'https://');
      cover = cover.replaceAll('&edge=curl', '');
    }
    if (cover.isEmpty && isbn.isNotEmpty) cover = _coverByIsbn(isbn);

    final description = (info['description'] ?? '').toString();
    final cats = info['categories'];
    final categories = cats is List ? cats.join(', ') : '';
    final pages = info['pageCount'] is int ? info['pageCount'] as int : 0;

    return Book.create(
      isbn: isbn,
      title: fullTitle,
      author: author,
      publisher: publisher,
      year: year,
      coverUrl: cover,
      description: description,
      categories: categories,
      pages: pages,
    );
  }

  String _extractGoogleIsbn(dynamic identifiers) {
    if (identifiers is! List) return '';
    String isbn13 = '';
    String isbn10 = '';
    for (final id in identifiers) {
      if (id is Map) {
        final type = (id['type'] ?? '').toString();
        final value = (id['identifier'] ?? '').toString();
        if (type == 'ISBN_13') isbn13 = value;
        if (type == 'ISBN_10') isbn10 = value;
      }
    }
    return isbn13.isNotEmpty ? isbn13 : isbn10;
  }

  // ----------------- Open Library (fallback) -----------------

  Future<Book?> _openLibraryByIsbn(String isbn) async {
    try {
      final res = await _client.get(Uri.parse('$_olBase/isbn/$isbn.json'));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is! Map) return null;

      final title = (data['title'] ?? '').toString();
      final publishers = data['publishers'];
      final publisher =
          publishers is List && publishers.isNotEmpty ? '${publishers.first}' : '';
      final publishDate = (data['publish_date'] ?? '').toString();
      final year = _yearFrom(publishDate);
      final author = await _openLibraryAuthors(data['authors']);
      final pages =
          data['number_of_pages'] is int ? data['number_of_pages'] as int : 0;

      return Book.create(
        isbn: isbn,
        title: title,
        author: author,
        publisher: publisher,
        year: year,
        coverUrl: _coverByIsbn(isbn),
        pages: pages,
      );
    } catch (_) {
      return null;
    }
  }

  /// Ricerca OL per ISBN tramite search.json (fornisce number_of_pages_median,
  /// utile quando l'endpoint /isbn/ non ha il numero di pagine).
  Future<Book?> _openLibrarySearchByIsbn(String isbn) async {
    try {
      final uri = Uri.parse('$_olBase/search.json'
          '?q=isbn:$isbn'
          '&fields=title,author_name,publisher,first_publish_year,cover_i,isbn,number_of_pages_median'
          '&limit=1');
      final res = await _client.get(uri);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final docs = data is Map ? data['docs'] : null;
      if (docs is! List || docs.isEmpty) return null;
      final doc = docs.first;
      if (doc is! Map) return null;

      final title = (doc['title'] ?? '').toString();
      final authorNames = doc['author_name'];
      final author = authorNames is List ? authorNames.take(2).join(', ') : '';
      final publishers = doc['publisher'];
      final publisher =
          publishers is List && publishers.isNotEmpty ? '${publishers.first}' : '';
      final year = doc['first_publish_year']?.toString() ?? '';
      final pages = doc['number_of_pages_median'] is int
          ? doc['number_of_pages_median'] as int
          : 0;
      String cover = '';
      final coverId = doc['cover_i'];
      if (coverId != null) cover = '$_olCovers/id/$coverId-L.jpg';

      return Book.create(
        isbn: isbn,
        title: title,
        author: author,
        publisher: publisher,
        year: year,
        coverUrl: cover,
        pages: pages,
      );
    } catch (_) {
      return null;
    }
  }

  /// Risolve i nomi degli autori (Open Library li restituisce come riferimenti).
  Future<String> _openLibraryAuthors(dynamic authors) async {
    if (authors is! List || authors.isEmpty) return '';
    final names = <String>[];
    for (final a in authors.take(2)) {
      String? key;
      if (a is Map && a['key'] != null) key = a['key'].toString();
      if (a is Map && a['author'] is Map) {
        key = (a['author']['key'] ?? '').toString();
      }
      if (key == null || key.isEmpty) continue;
      try {
        final res = await _client.get(Uri.parse('$_olBase$key.json'));
        if (res.statusCode == 200) {
          final d = jsonDecode(utf8.decode(res.bodyBytes));
          if (d is Map && d['name'] != null) names.add(d['name'].toString());
        }
      } catch (_) {
        // ignora singolo autore non risolto
      }
    }
    return names.join(', ');
  }

  Future<List<Book>> _openLibrarySearch(String query,
      {int maxResults = 20}) async {
    try {
      final uri = Uri.parse('$_olBase/search.json'
          '?title=${Uri.encodeComponent(query)}'
          '&fields=title,author_name,publisher,first_publish_year,cover_i,isbn,number_of_pages_median'
          '&limit=$maxResults');
      final res = await _client.get(uri);
      if (res.statusCode != 200) return [];
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final docs = data is Map ? data['docs'] : null;
      if (docs is! List) return [];

      return docs.map<Book?>((doc) {
        if (doc is! Map) return null;
        final title = (doc['title'] ?? '').toString();
        final authorNames = doc['author_name'];
        final author = authorNames is List ? authorNames.take(2).join(', ') : '';
        final publishers = doc['publisher'];
        final publisher =
            publishers is List && publishers.isNotEmpty ? '${publishers.first}' : '';
        final year = doc['first_publish_year']?.toString() ?? '';

        final isbnList = doc['isbn'];
        final isbn =
            isbnList is List && isbnList.isNotEmpty ? '${isbnList.first}' : '';

        String cover = '';
        final coverId = doc['cover_i'];
        if (coverId != null) {
          cover = '$_olCovers/id/$coverId-L.jpg';
        } else if (isbn.isNotEmpty) {
          cover = _coverByIsbn(isbn);
        }

        final pages = doc['number_of_pages_median'] is int
            ? doc['number_of_pages_median'] as int
            : 0;

        return Book.create(
          isbn: isbn,
          title: title,
          author: author,
          publisher: publisher,
          year: year,
          coverUrl: cover,
          pages: pages,
        );
      }).whereType<Book>().toList();
    } catch (_) {
      return [];
    }
  }

  // ----------------- OPAC SBN (fallback italiano) -----------------

  /// Interroga l'API JSON dell'OPAC SBN. Ottima copertura dei libri italiani.
  /// Nota: su Web la richiesta può essere bloccata dal CORS (SBN non invia gli
  /// header) — in tal caso la funzione restituisce [] e si passa oltre. Su
  /// Android funziona regolarmente.
  Future<List<Book>> _opacSbn(String query,
      {required bool isbn, int maxResults = 20}) async {
    try {
      final param = isbn
          ? 'isbn=${Uri.encodeComponent(query)}'
          : 'any=${Uri.encodeComponent(query)}';
      final uri = Uri.parse('$_sbnBase?$param&rows=$maxResults');
      final res = await _client.get(uri);
      if (res.statusCode != 200) return [];
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final records = data is Map ? data['briefRecords'] : null;
      if (records is! List) return [];
      return records.map(_parseSbnRecord).whereType<Book>().toList();
    } catch (_) {
      return [];
    }
  }

  Book? _parseSbnRecord(dynamic r) {
    if (r is! Map) return null;

    // Titolo: "Titolo / responsabilità" → teniamo solo la parte prima di " / ".
    final rawTitle = (r['titolo'] ?? '').toString();
    var title = rawTitle.split(' / ').first.trim();
    if (title.isEmpty) title = rawTitle.trim();
    if (title.isEmpty) return null;

    final author = _formatSbnAuthor((r['autorePrincipale'] ?? '').toString());

    // Pubblicazione: "Luogo : Editore, Anno".
    final pub = (r['pubblicazione'] ?? '').toString();
    final publisher = _sbnPublisher(pub);
    final year = _yearFrom(pub);

    final clean =
        (r['isbn'] ?? '').toString().replaceAll(RegExp(r'[^0-9Xx]'), '');

    return Book.create(
      isbn: clean,
      title: title,
      author: author,
      publisher: publisher,
      year: year,
      // La copertina di SBN (LibraryThing) richiede un referer e dà 403:
      // usiamo il fallback per ISBN (placeholder se assente).
      coverUrl: clean.isNotEmpty ? _coverByIsbn(clean) : '',
    );
  }

  /// "Cognome, Nome" → "Nome Cognome"; lascia invariato se non nel formato.
  String _formatSbnAuthor(String a) {
    final s = a.trim();
    if (s.isEmpty) return '';
    final i = s.indexOf(', ');
    if (i > 0) {
      final surname = s.substring(0, i).trim();
      final name = s.substring(i + 2).trim();
      if (name.isNotEmpty) return '$name $surname';
    }
    return s;
  }

  /// Estrae l'editore da "Luogo : Editore, Anno".
  String _sbnPublisher(String pub) {
    if (pub.isEmpty) return '';
    var s = pub;
    final colon = s.indexOf(' : ');
    if (colon >= 0) s = s.substring(colon + 3);
    // Rimuove ", 2026" / ", [2026]." finale.
    s = s.replaceAll(RegExp(r',\s*\[?\d{4}\]?\.?\s*$'), '');
    return s.trim();
  }

  // ----------------- utils -----------------

  String _coverByIsbn(String isbn) {
    final clean = isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
    // ?default=false → se la copertina non esiste risponde 404 (così la UI
    // mostra il placeholder invece di un'immagine grigia vuota).
    return clean.isEmpty ? '' : '$_olCovers/isbn/$clean-L.jpg?default=false';
  }

  String _yearFrom(String date) {
    final match = RegExp(r'(\d{4})').firstMatch(date);
    return match != null ? match.group(1)! : date;
  }

  void dispose() => _client.close();
}
