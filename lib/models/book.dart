/// Stato di lettura di un libro.
enum ReadingStatus {
  toRead,
  reading,
  read;

  String get storageValue => name;

  String get label {
    switch (this) {
      case ReadingStatus.toRead:
        return 'Da leggere';
      case ReadingStatus.reading:
        return 'In lettura';
      case ReadingStatus.read:
        return 'Letto';
    }
  }

  static ReadingStatus fromStorage(String? v) {
    switch (v) {
      case 'reading':
        return ReadingStatus.reading;
      case 'read':
        return ReadingStatus.read;
      default:
        return ReadingStatus.toRead;
    }
  }
}

/// Una sessione di lettura (con eventuale data di inizio e di fine).
/// Un libro può averne più di una in caso di rilettura.
class ReadingSession {
  final DateTime? start;
  final DateTime? end;

  const ReadingSession({this.start, this.end});

  ReadingSession copyWith({DateTime? start, DateTime? end}) =>
      ReadingSession(start: start ?? this.start, end: end ?? this.end);

  Map<String, dynamic> toMap() => {
        'start': start?.millisecondsSinceEpoch,
        'end': end?.millisecondsSinceEpoch,
      };

  static DateTime? _date(dynamic v) {
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    final n = int.tryParse('$v');
    return n != null ? DateTime.fromMillisecondsSinceEpoch(n) : null;
  }

  factory ReadingSession.fromMap(Map<dynamic, dynamic> m) =>
      ReadingSession(start: _date(m['start']), end: _date(m['end']));
}

/// Modello che rappresenta un libro nel catalogo.
///
/// Viene salvato su Hive come semplice `Map<String, dynamic>` (nessun adapter
/// generato) e serializzato in JSON per l'export/import.
class Book {
  final String id;
  final String isbn;
  final String title;
  final String author;
  final String publisher;
  final String year;
  final String coverUrl;
  final String coverData; // copertina locale in base64 (vuoto = nessuna)
  final String note;
  final String review; // recensione personale
  final String shelf; // scaffale (vuoto = nessuno)
  final ReadingStatus status; // stato di lettura
  final String description; // sinossi/descrizione
  final String categories; // genere/categorie (separati da virgola)
  final int pages; // numero di pagine (0 = sconosciuto)
  final List<ReadingSession> readingSessions; // letture (anche riletture)
  final int dateAdded; // millisecondi epoch

  const Book({
    required this.id,
    this.isbn = '',
    this.title = '',
    this.author = '',
    this.publisher = '',
    this.year = '',
    this.coverUrl = '',
    this.coverData = '',
    this.note = '',
    this.review = '',
    this.shelf = '',
    this.status = ReadingStatus.toRead,
    this.description = '',
    this.categories = '',
    this.pages = 0,
    this.readingSessions = const [],
    required this.dateAdded,
  });

  /// Crea un nuovo libro assegnando id e data di inserimento automaticamente.
  factory Book.create({
    String isbn = '',
    String title = '',
    String author = '',
    String publisher = '',
    String year = '',
    String coverUrl = '',
    String coverData = '',
    String note = '',
    String review = '',
    String shelf = '',
    ReadingStatus status = ReadingStatus.toRead,
    String description = '',
    String categories = '',
    int pages = 0,
    List<ReadingSession> readingSessions = const [],
  }) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return Book(
      id: now.toString(),
      isbn: isbn,
      title: title,
      author: author,
      publisher: publisher,
      year: year,
      coverUrl: coverUrl,
      coverData: coverData,
      note: note,
      review: review,
      shelf: shelf,
      status: status,
      description: description,
      categories: categories,
      pages: pages,
      readingSessions: readingSessions,
      dateAdded: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Book copyWith({
    String? isbn,
    String? title,
    String? author,
    String? publisher,
    String? year,
    String? coverUrl,
    String? coverData,
    String? note,
    String? review,
    String? shelf,
    ReadingStatus? status,
    String? description,
    String? categories,
    int? pages,
    List<ReadingSession>? readingSessions,
  }) {
    return Book(
      id: id,
      isbn: isbn ?? this.isbn,
      title: title ?? this.title,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      year: year ?? this.year,
      coverUrl: coverUrl ?? this.coverUrl,
      coverData: coverData ?? this.coverData,
      note: note ?? this.note,
      review: review ?? this.review,
      shelf: shelf ?? this.shelf,
      status: status ?? this.status,
      description: description ?? this.description,
      categories: categories ?? this.categories,
      pages: pages ?? this.pages,
      readingSessions: readingSessions ?? this.readingSessions,
      dateAdded: dateAdded,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'isbn': isbn,
        'title': title,
        'author': author,
        'publisher': publisher,
        'year': year,
        'coverUrl': coverUrl,
        'coverData': coverData,
        'note': note,
        'review': review,
        'shelf': shelf,
        'status': status.storageValue,
        'description': description,
        'categories': categories,
        'pages': pages,
        'readingSessions':
            readingSessions.map((s) => s.toMap()).toList(),
        'dateAdded': dateAdded,
      };

  factory Book.fromMap(Map<dynamic, dynamic> map) {
    return Book(
      id: (map['id'] ?? DateTime.now().microsecondsSinceEpoch.toString())
          .toString(),
      isbn: (map['isbn'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      author: (map['author'] ?? '').toString(),
      publisher: (map['publisher'] ?? '').toString(),
      year: (map['year'] ?? '').toString(),
      coverUrl: (map['coverUrl'] ?? '').toString(),
      coverData: (map['coverData'] ?? '').toString(),
      note: (map['note'] ?? '').toString(),
      review: (map['review'] ?? '').toString(),
      shelf: (map['shelf'] ?? '').toString(),
      status: ReadingStatus.fromStorage(map['status']?.toString()),
      description: (map['description'] ?? '').toString(),
      categories: (map['categories'] ?? '').toString(),
      pages: map['pages'] is int
          ? map['pages'] as int
          : int.tryParse('${map['pages']}') ?? 0,
      readingSessions: map['readingSessions'] is List
          ? (map['readingSessions'] as List)
              .whereType<Map>()
              .map((m) => ReadingSession.fromMap(m))
              .toList()
          : const [],
      dateAdded: map['dateAdded'] is int
          ? map['dateAdded'] as int
          : int.tryParse('${map['dateAdded']}') ??
              DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool get hasCover => coverData.isNotEmpty || coverUrl.trim().isNotEmpty;
  bool get hasLocalCover => coverData.isNotEmpty;
}
