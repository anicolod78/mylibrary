import 'package:flutter/foundation.dart';

import '../data/book_repository.dart';
import '../models/book.dart';

enum BookSort { titleAsc, titleDesc, authorAsc, yearDesc, recent }

extension BookSortLabel on BookSort {
  String get label {
    switch (this) {
      case BookSort.titleAsc:
        return 'Titolo (A-Z)';
      case BookSort.titleDesc:
        return 'Titolo (Z-A)';
      case BookSort.authorAsc:
        return 'Autore (A-Z)';
      case BookSort.yearDesc:
        return 'Anno (recenti)';
      case BookSort.recent:
        return 'Aggiunti di recente';
    }
  }
}

/// Stato centrale del catalogo: lista, filtri, ordinamento e operazioni CRUD.
class LibraryProvider extends ChangeNotifier {
  final BookRepository _repo;

  LibraryProvider(this._repo) {
    _reload();
  }

  List<Book> _all = [];

  // Filtri
  String _titleFilter = '';
  String _authorFilter = '';
  String _yearFilter = '';
  String _publisherFilter = '';
  BookSort _sort = BookSort.titleAsc;
  String _shelfFilter = ''; // '' = tutti; [noShelf] = senza scaffale; else nome
  ReadingStatus? _statusFilter; // null = tutti gli stati
  String _genreFilter = ''; // '' = tutti
  String _finishYearFilter = ''; // '' = tutti; else anno di fine lettura
  int _ratingFilter = 0; // 0 = tutti; 1-5 = voto esatto; -1 = senza voto

  /// Valore speciale del filtro scaffale per "senza scaffale".
  static const String noShelf = '__no_shelf__';

  String get titleFilter => _titleFilter;
  String get authorFilter => _authorFilter;
  String get yearFilter => _yearFilter;
  String get publisherFilter => _publisherFilter;
  String get shelfFilter => _shelfFilter;
  ReadingStatus? get statusFilter => _statusFilter;
  String get genreFilter => _genreFilter;
  String get finishYearFilter => _finishYearFilter;
  int get ratingFilter => _ratingFilter;
  BookSort get sort => _sort;

  int get totalCount => _all.length;

  bool get hasActiveFilters =>
      _titleFilter.isNotEmpty ||
      _authorFilter.isNotEmpty ||
      _yearFilter.isNotEmpty ||
      _publisherFilter.isNotEmpty ||
      _shelfFilter.isNotEmpty ||
      _statusFilter != null ||
      _genreFilter.isNotEmpty ||
      _finishYearFilter.isNotEmpty ||
      _ratingFilter != 0;

  /// Elenco scaffali: unione di quelli definiti e di quelli usati dai libri.
  List<String> get shelves {
    final set = <String>{..._repo.getShelves()};
    for (final b in _all) {
      if (b.shelf.trim().isNotEmpty) set.add(b.shelf.trim());
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  void _reload() {
    _all = _repo.getAll();
    notifyListeners();
  }

  /// Lista filtrata e ordinata, pronta per la UI.
  List<Book> get books {
    Iterable<Book> list = _all;

    bool match(String field, String filter) =>
        filter.isEmpty ||
        field.toLowerCase().contains(filter.toLowerCase().trim());

    bool matchShelf(Book b) {
      if (_shelfFilter.isEmpty) return true;
      if (_shelfFilter == noShelf) return b.shelf.trim().isEmpty;
      return b.shelf.trim() == _shelfFilter;
    }

    bool matchGenre(Book b) {
      if (_genreFilter.isEmpty) return true;
      final target = _genreFilter.toLowerCase();
      return b.categories
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .contains(target);
    }

    bool matchFinishYear(Book b) {
      if (_finishYearFilter.isEmpty) return true;
      final y = int.tryParse(_finishYearFilter);
      if (y == null) return true;
      return b.readingSessions
          .any((s) => s.end != null && s.end!.year == y);
    }

    bool matchRating(Book b) {
      if (_ratingFilter == 0) return true;
      if (_ratingFilter == -1) return b.rating == 0; // senza voto
      return b.rating == _ratingFilter;
    }

    list = list.where((b) =>
        match(b.title, _titleFilter) &&
        match(b.author, _authorFilter) &&
        match(b.year, _yearFilter) &&
        match(b.publisher, _publisherFilter) &&
        matchShelf(b) &&
        (_statusFilter == null || b.status == _statusFilter) &&
        matchGenre(b) &&
        matchFinishYear(b) &&
        matchRating(b));

    final result = list.toList();
    result.sort((a, b) {
      switch (_sort) {
        case BookSort.titleAsc:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case BookSort.titleDesc:
          return b.title.toLowerCase().compareTo(a.title.toLowerCase());
        case BookSort.authorAsc:
          return a.author.toLowerCase().compareTo(b.author.toLowerCase());
        case BookSort.yearDesc:
          return b.year.compareTo(a.year);
        case BookSort.recent:
          return b.dateAdded.compareTo(a.dateAdded);
      }
    });
    return result;
  }

  // --- Filtri ---

  void setTitleFilter(String v) {
    _titleFilter = v;
    notifyListeners();
  }

  void setAuthorFilter(String v) {
    _authorFilter = v;
    notifyListeners();
  }

  void setYearFilter(String v) {
    _yearFilter = v;
    notifyListeners();
  }

  void setPublisherFilter(String v) {
    _publisherFilter = v;
    notifyListeners();
  }

  void setShelfFilter(String v) {
    _shelfFilter = v;
    notifyListeners();
  }

  void setStatusFilter(ReadingStatus? s) {
    _statusFilter = s;
    notifyListeners();
  }

  void setGenreFilter(String v) {
    _genreFilter = v;
    notifyListeners();
  }

  void setFinishYearFilter(String v) {
    _finishYearFilter = v;
    notifyListeners();
  }

  void setRatingFilter(int v) {
    _ratingFilter = v;
    notifyListeners();
  }

  /// Anni di fine lettura presenti nel catalogo (per il filtro).
  List<int> get finishYears {
    final set = <int>{};
    for (final b in _all) {
      for (final s in b.readingSessions) {
        if (s.end != null) set.add(s.end!.year);
      }
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  void setSort(BookSort s) {
    _sort = s;
    notifyListeners();
  }

  void clearFilters() {
    _titleFilter = '';
    _authorFilter = '';
    _yearFilter = '';
    _publisherFilter = '';
    _shelfFilter = '';
    _statusFilter = null;
    _genreFilter = '';
    _finishYearFilter = '';
    _ratingFilter = 0;
    notifyListeners();
  }

  // --- Statistiche di lettura (per il grafico) ---

  /// Numero di libri con fine lettura per anno (le riletture contano).
  Map<int, int> booksReadPerYear() {
    final map = <int, int>{};
    for (final b in _all) {
      for (final s in b.readingSessions) {
        if (s.end != null) {
          map[s.end!.year] = (map[s.end!.year] ?? 0) + 1;
        }
      }
    }
    return map;
  }

  /// Numero di pagine lette per anno (somma delle pagine dei libri finiti).
  Map<int, int> pagesReadPerYear() {
    final map = <int, int>{};
    for (final b in _all) {
      for (final s in b.readingSessions) {
        if (s.end != null) {
          map[s.end!.year] = (map[s.end!.year] ?? 0) + b.pages;
        }
      }
    }
    return map;
  }

  /// Chiave mese ordinabile: anno*100 + mese (es. 202403 = marzo 2024).
  static int _ym(DateTime d) => d.year * 100 + d.month;

  /// Numero di libri con fine lettura per mese.
  Map<int, int> booksReadPerMonth() {
    final map = <int, int>{};
    for (final b in _all) {
      for (final s in b.readingSessions) {
        if (s.end != null) {
          final k = _ym(s.end!);
          map[k] = (map[k] ?? 0) + 1;
        }
      }
    }
    return map;
  }

  /// Numero di pagine lette per mese.
  Map<int, int> pagesReadPerMonth() {
    final map = <int, int>{};
    for (final b in _all) {
      for (final s in b.readingSessions) {
        if (s.end != null) {
          final k = _ym(s.end!);
          map[k] = (map[k] ?? 0) + b.pages;
        }
      }
    }
    return map;
  }

  // --- CRUD ---

  /// Aggiunge un libro solo se non è un duplicato.
  /// Restituisce il libro duplicato esistente se l'inserimento è stato
  /// bloccato, altrimenti null (inserimento avvenuto).
  Future<Book?> add(Book book) async {
    final dup = _repo.findDuplicate(book);
    if (dup != null) return dup;
    await _repo.save(book);
    _reload();
    return null;
  }

  /// Aggiorna un libro esistente, impedendo che la modifica lo renda duplicato
  /// di un altro libro. Restituisce il duplicato se bloccato, altrimenti null.
  Future<Book?> update(Book book) async {
    final dup = _repo.findDuplicate(book, excludeId: book.id);
    if (dup != null) return dup;
    await _repo.save(book);
    _reload();
    return null;
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    _reload();
  }

  bool existsByIsbn(String isbn) => _repo.existsByIsbn(isbn);

  Book? findDuplicate(Book book) => _repo.findDuplicate(book);

  /// Cambia rapidamente lo stato di lettura di un libro.
  Future<void> setStatus(Book book, ReadingStatus status) async {
    await _repo.save(book.copyWith(status: status));
    _reload();
  }

  /// Cambia rapidamente la valutazione (0-5) di un libro.
  Future<void> setRating(Book book, int rating) async {
    await _repo.save(book.copyWith(rating: rating));
    _reload();
  }

  // --- Scaffale di default ---

  String get defaultShelf => _repo.getDefaultShelf();

  Future<void> setDefaultShelf(String name) async {
    await _repo.setDefaultShelf(name);
    notifyListeners();
  }

  // --- Generi (etichette estendibili) ---

  /// Generi suggeriti di base (estendibili con categorie personali).
  static const List<String> defaultGenres = [
    'Narrativa',
    'Romanzo',
    'Giallo',
    'Thriller',
    'Fantasy',
    'Fantascienza',
    'Horror',
    'Rosa',
    'Storico',
    'Avventura',
    'Biografia',
    'Saggistica',
    'Poesia',
    'Fumetti / Graphic novel',
    'Ragazzi',
    'Young adult',
    'Classici',
    'Cucina',
    'Viaggi',
    'Arte',
  ];

  /// Elenco completo dei generi: base + personali + quelli già usati dai libri.
  List<String> get genres {
    final set = <String>{...defaultGenres, ..._repo.getCustomGenres()};
    for (final b in _all) {
      for (final g in b.categories.split(',')) {
        final t = g.trim();
        if (t.isNotEmpty) set.add(t);
      }
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Future<void> addGenre(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    await _repo.setCustomGenres([..._repo.getCustomGenres(), clean]);
    notifyListeners();
  }

  // --- Gestione scaffali ---

  Future<void> addShelf(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    await _repo.setShelves([..._repo.getShelves(), clean]);
    notifyListeners();
  }

  /// Rinomina uno scaffale, aggiornando anche i libri che vi appartengono.
  Future<void> renameShelf(String oldName, String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty || oldName == clean) return;
    final shelves = _repo.getShelves().map((s) => s == oldName ? clean : s).toList();
    await _repo.setShelves(shelves);
    for (final b in _all.where((b) => b.shelf == oldName)) {
      await _repo.save(b.copyWith(shelf: clean));
    }
    if (_shelfFilter == oldName) _shelfFilter = clean;
    if (_repo.getDefaultShelf() == oldName) await _repo.setDefaultShelf(clean);
    _reload();
  }

  /// Elimina uno scaffale; i libri che vi appartenevano restano senza scaffale.
  Future<void> deleteShelf(String name) async {
    final shelves = _repo.getShelves().where((s) => s != name).toList();
    await _repo.setShelves(shelves);
    for (final b in _all.where((b) => b.shelf == name)) {
      await _repo.save(b.copyWith(shelf: ''));
    }
    if (_shelfFilter == name) _shelfFilter = '';
    if (_repo.getDefaultShelf() == name) await _repo.setDefaultShelf('');
    _reload();
  }

  int booksOnShelf(String name) =>
      _all.where((b) => b.shelf.trim() == name).length;

  // --- Impostazioni ---

  String get googleApiKey => _repo.googleApiKey;

  Future<void> setGoogleApiKey(String key) async {
    await _repo.setGoogleApiKey(key);
    notifyListeners();
  }

  // --- Export / Import ---

  String exportToJson() => _repo.exportToJson();

  String exportToCsv() => _repo.exportToCsv();

  Future<({int added, int skipped})> importFromJson(String json,
      {bool merge = true}) async {
    final result = await _repo.importFromJson(json, merge: merge);
    _reload();
    return result;
  }
}
