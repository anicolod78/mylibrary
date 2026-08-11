import 'dart:convert';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/book.dart';

/// Persistenza locale del catalogo su Hive.
///
/// I libri sono salvati come `Map` in un box, con chiave = `Book.id`.
/// Funziona in modo identico su Android e Web (nessuna dipendenza nativa).
class BookRepository {
  static const String boxName = 'books';
  static const String settingsBoxName = 'settings';

  Box get _box => Hive.box(boxName);
  Box get _settings => Hive.box(settingsBoxName);

  /// Da chiamare una sola volta all'avvio dell'app.
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(boxName);
    await Hive.openBox(settingsBoxName);
  }

  /// Chiave API Google Books (opzionale). Se impostata, evita l'errore 429.
  String get googleApiKey =>
      (_settings.get('googleApiKey') ?? '').toString();

  Future<void> setGoogleApiKey(String key) =>
      _settings.put('googleApiKey', key.trim());

  /// Elenco degli scaffali definiti dall'utente (salvato nelle impostazioni).
  List<String> getShelves() {
    final raw = _settings.get('shelves');
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return <String>[];
  }

  Future<void> setShelves(List<String> shelves) async {
    final clean = shelves
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    await _settings.put('shelves', clean);
  }

  /// Scaffale predefinito per i nuovi inserimenti ('' = nessuno).
  String getDefaultShelf() => (_settings.get('defaultShelf') ?? '').toString();

  Future<void> setDefaultShelf(String name) =>
      _settings.put('defaultShelf', name.trim());

  /// Categorie/generi personali aggiunti dall'utente.
  List<String> getCustomGenres() {
    final raw = _settings.get('genres');
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return <String>[];
  }

  Future<void> setCustomGenres(List<String> genres) async {
    final clean =
        genres.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    await _settings.put('genres', clean);
  }

  List<Book> getAll() {
    return _box.values
        .whereType<Map>()
        .map((m) => Book.fromMap(m))
        .toList();
  }

  Future<void> save(Book book) async {
    await _box.put(book.id, book.toMap());
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  /// True se esiste già un libro con questo ISBN (ISBN non vuoto).
  bool existsByIsbn(String isbn) {
    final clean = _normIsbn(isbn);
    if (clean.isEmpty) return false;
    return getAll().any((b) => _normIsbn(b.isbn) == clean);
  }

  /// Restituisce un libro già in archivio considerato **duplicato** di
  /// [candidate], oppure null se non esiste.
  ///
  /// Criterio: stesso ISBN (quando entrambi lo hanno); in mancanza di ISBN,
  /// stesso titolo + autore normalizzati. [excludeId] permette di escludere un
  /// libro (es. quello che si sta modificando).
  Book? findDuplicate(Book candidate, {String? excludeId}) {
    final isbn = _normIsbn(candidate.isbn);
    final title = _normText(candidate.title);
    final author = _normText(candidate.author);
    if (isbn.isEmpty && title.isEmpty) return null;

    for (final b in getAll()) {
      if (excludeId != null && b.id == excludeId) continue;
      final bIsbn = _normIsbn(b.isbn);
      if (isbn.isNotEmpty && bIsbn.isNotEmpty) {
        if (isbn == bIsbn) return b;
      } else if (title.isNotEmpty) {
        if (_normText(b.title) == title && _normText(b.author) == author) {
          return b;
        }
      }
    }
    return null;
  }

  String _normIsbn(String s) => s.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();

  String _normText(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  // --- Export / Import ---

  /// Serializza l'intero catalogo in una stringa JSON.
  String exportToJson() {
    final data = {
      'app': 'mylibrary',
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'shelves': getShelves(),
      'books': getAll().map((b) => b.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Esporta il catalogo in formato CSV (tutti i dati **tranne l'immagine**).
  /// Include un BOM UTF-8 così Excel apre correttamente le lettere accentate.
  String exportToCsv() {
    const headers = [
      'Titolo',
      'Autore',
      'Editore',
      'Anno',
      'ISBN',
      'Pagine',
      'Scaffale',
      'Stato',
      'Genere',
      'Letture',
      'Sinossi',
      'Recensione',
      'Note',
      'URL copertina',
      'Data aggiunta',
    ];

    String fmtDate(DateTime? d) => d == null
        ? ''
        : '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/${d.year}';

    String cell(String v) {
      // Racchiude tra virgolette se contiene ; , " o a capo; raddoppia le ".
      final needsQuote = v.contains(RegExp(r'[",;\n\r]'));
      final escaped = v.replaceAll('"', '""');
      return needsQuote ? '"$escaped"' : escaped;
    }

    String row(List<String> cells) => cells.map(cell).join(',');

    final buffer = StringBuffer('﻿'); // BOM
    buffer.writeln(row(headers));

    for (final b in getAll()) {
      final date =
          DateTime.fromMillisecondsSinceEpoch(b.dateAdded).toIso8601String();
      final letture = b.readingSessions
          .map((s) => '${fmtDate(s.start)}-${fmtDate(s.end)}')
          .join(' ; ');
      buffer.writeln(row([
        b.title,
        b.author,
        b.publisher,
        b.year,
        b.isbn,
        b.pages > 0 ? '${b.pages}' : '',
        b.shelf,
        b.status.label,
        b.categories,
        letture,
        b.description,
        b.review,
        b.note,
        b.coverUrl,
        date,
      ]));
    }
    return buffer.toString();
  }

  /// Importa da una stringa JSON, **saltando i duplicati**.
  ///
  /// Se [merge] è true i libri vengono aggiunti al catalogo esistente; se false
  /// il catalogo viene prima svuotato. In entrambi i casi non vengono creati
  /// duplicati (né rispetto ai libri già presenti né all'interno del file).
  /// Restituisce quanti libri sono stati aggiunti e quanti saltati.
  Future<({int added, int skipped})> importFromJson(String jsonStr,
      {bool merge = true}) async {
    final decoded = jsonDecode(jsonStr);
    final List<dynamic> rawBooks = decoded is Map && decoded['books'] is List
        ? decoded['books'] as List
        : decoded is List
            ? decoded
            : <dynamic>[];

    if (!merge) {
      await _box.clear();
    }

    // Importa anche l'elenco scaffali (unione con quelli esistenti).
    if (decoded is Map && decoded['shelves'] is List) {
      final incoming =
          (decoded['shelves'] as List).map((e) => e.toString()).toList();
      await setShelves([...getShelves(), ...incoming]);
    }

    int added = 0;
    int skipped = 0;
    for (final raw in rawBooks) {
      if (raw is! Map) continue;
      final book = Book.fromMap(raw);
      // Confronta con lo stato aggiornato del box (così anche i duplicati
      // interni al file vengono scartati).
      if (findDuplicate(book) != null) {
        skipped++;
        continue;
      }
      // Evita collisioni di id mantenendo l'invariante chiave-box == id.
      final map = book.toMap();
      var key = book.id;
      if (_box.containsKey(key)) {
        key = '${book.id}_${DateTime.now().microsecondsSinceEpoch}';
        map['id'] = key;
      }
      await _box.put(key, map);
      added++;
    }
    return (added: added, skipped: skipped);
  }
}
