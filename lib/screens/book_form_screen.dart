import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../providers/library_provider.dart';
import '../widgets/book_cover.dart';

/// Form per l'aggiunta manuale o la modifica di un libro.
///
/// - Se [existing] è null → modalità inserimento (nuovo libro).
/// - Altrimenti → modalità modifica del libro esistente.
class BookFormScreen extends StatefulWidget {
  final Book? existing;

  /// Valori iniziali (es. proveniente da una ricerca online) usati solo in
  /// modalità inserimento.
  final Book? prefill;

  const BookFormScreen({super.key, this.existing, this.prefill});

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _publisher;
  late final TextEditingController _year;
  late final TextEditingController _isbn;
  late final TextEditingController _coverUrl;
  late final TextEditingController _note;
  late final TextEditingController _review;
  late final TextEditingController _description;
  late final TextEditingController _pages;

  String _shelf = ''; // '' = nessuno scaffale
  ReadingStatus _status = ReadingStatus.toRead;
  String _coverData = ''; // copertina locale in base64
  late Set<String> _genres; // generi selezionati (etichette)
  late List<ReadingSession> _sessions; // letture (anche riletture)
  final _picker = ImagePicker();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existing ?? widget.prefill;
    _title = TextEditingController(text: b?.title ?? '');
    _author = TextEditingController(text: b?.author ?? '');
    _publisher = TextEditingController(text: b?.publisher ?? '');
    _year = TextEditingController(text: b?.year ?? '');
    _isbn = TextEditingController(text: b?.isbn ?? '');
    _coverUrl = TextEditingController(text: b?.coverUrl ?? '');
    _note = TextEditingController(text: b?.note ?? '');
    _review = TextEditingController(text: b?.review ?? '');
    _description = TextEditingController(text: b?.description ?? '');
    _pages = TextEditingController(
        text: (b != null && b.pages > 0) ? '${b.pages}' : '');
    _genres = _splitGenres(b?.categories ?? '');
    _sessions = List<ReadingSession>.from(b?.readingSessions ?? const []);
    _status = b?.status ?? ReadingStatus.toRead;
    _coverData = b?.coverData ?? '';

    // Scaffale: in modifica quello del libro; in inserimento usa l'eventuale
    // scaffale del prefill o, altrimenti, lo scaffale predefinito.
    final provider = context.read<LibraryProvider>();
    if (_isEditing) {
      _shelf = widget.existing!.shelf;
    } else {
      final pre = widget.prefill?.shelf ?? '';
      _shelf = pre.isNotEmpty ? pre : provider.defaultShelf;
    }
  }

  Set<String> _splitGenres(String s) => s
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _publisher.dispose();
    _year.dispose();
    _isbn.dispose();
    _coverUrl.dispose();
    _note.dispose();
    _review.dispose();
    _description.dispose();
    _pages.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<LibraryProvider>();

    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        title: _title.text.trim(),
        author: _author.text.trim(),
        publisher: _publisher.text.trim(),
        year: _year.text.trim(),
        isbn: _isbn.text.trim(),
        coverUrl: _coverUrl.text.trim(),
        coverData: _coverData,
        note: _note.text.trim(),
        review: _review.text.trim(),
        description: _description.text.trim(),
        categories: _genres.join(', '),
        pages: int.tryParse(_pages.text.trim()) ?? 0,
        readingSessions: _sessions,
        shelf: _shelf,
        status: _status,
      );
      final dup = await provider.update(updated);
      if (!mounted) return;
      if (dup != null) {
        await _showDuplicateDialog(dup);
        return;
      }
      Navigator.pop(context, updated);
    } else {
      final book = Book.create(
        title: _title.text.trim(),
        author: _author.text.trim(),
        publisher: _publisher.text.trim(),
        year: _year.text.trim(),
        isbn: _isbn.text.trim(),
        coverUrl: _coverUrl.text.trim(),
        coverData: _coverData,
        note: _note.text.trim(),
        review: _review.text.trim(),
        description: _description.text.trim(),
        categories: _genres.join(', '),
        pages: int.tryParse(_pages.text.trim()) ?? 0,
        readingSessions: _sessions,
        shelf: _shelf,
        status: _status,
      );
      final dup = await provider.add(book);
      if (!mounted) return;
      if (dup != null) {
        await _showDuplicateDialog(dup);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Libro aggiunto al catalogo')),
      );
      Navigator.pop(context, book);
    }
  }

  /// Avvisa che il libro è già presente e non lo salva.
  Future<void> _showDuplicateDialog(Book existing) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Libro già in archivio'),
        content: Text(
          'Un libro con gli stessi dati è già presente:\n\n'
          '«${existing.title}»'
          '${existing.author.isNotEmpty ? ' — ${existing.author}' : ''}'
          '${existing.isbn.isNotEmpty ? '\nISBN ${existing.isbn}' : ''}\n\n'
          'Non è stato aggiunto un duplicato.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Sceglie una copertina da galleria o fotocamera, consente il **ritaglio**
  /// e la salva (base64).
  Future<void> _pickCover(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 92,
      );
      if (file == null) return;
      if (!mounted) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        maxWidth: 800,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 82,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ritaglia copertina',
            toolbarColor: const Color(0xFF3E7C88),
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
          WebUiSettings(context: context),
        ],
      );
      if (cropped == null) return; // ritaglio annullato

      final bytes = await cropped.readAsBytes();
      if (!mounted) return;
      setState(() => _coverData = base64Encode(bytes));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile caricare l\'immagine')),
      );
    }
  }

  Future<void> _createShelf() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuovo scaffale'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome scaffale'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Crea'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty && mounted) {
      await context.read<LibraryProvider>().addShelf(name);
      setState(() => _shelf = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    final shelves = provider.shelves;

    // Anteprima copertina: immagine locale se presente, altrimenti URL.
    final previewBook = Book.create(
      title: _title.text,
      coverUrl: _coverUrl.text.trim(),
      coverData: _coverData,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifica libro' : 'Aggiungi libro'),
        actions: [
          IconButton(
            tooltip: 'Salva',
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      // Pulsante Salva sempre visibile, sopra la barra di navigazione di sistema.
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: Text(_isEditing ? 'Salva modifiche' : 'Aggiungi'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: BookCover(book: previewBook, width: 120, height: 170),
              ),
            ),
            const SizedBox(height: 10),
            _coverButtons(),
            const SizedBox(height: 16),
            _field(_title, 'Titolo', required: true),
            _field(_author, 'Autore'),
            _field(_publisher, 'Editore'),
            _field(_year, 'Anno',
                keyboardType: TextInputType.number, maxLength: 4),
            _field(_isbn, 'ISBN', keyboardType: TextInputType.number),
            _field(_pages, 'Numero di pagine',
                keyboardType: TextInputType.number, maxLength: 6),
            _genreSelector(provider),
            const SizedBox(height: 14),
            _shelfSelector(shelves),
            const SizedBox(height: 6),
            _statusSelector(),
            const SizedBox(height: 16),
            _sessionsEditor(),
            const SizedBox(height: 16),
            _field(_description, 'Sinossi / descrizione', maxLines: 5),
            _field(_review, 'La mia recensione', maxLines: 4),
            _field(
              _coverUrl,
              'URL copertina',
              onChanged: (_) => setState(() {}),
            ),
            _field(_note, 'Note', maxLines: 3),
          ],
        ),
      ),
    );
  }

  Widget _genreSelector(LibraryProvider provider) {
    // Mostra i generi disponibili + quelli già selezionati (anche non in lista).
    final all = <String>{...provider.genres, ..._genres}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text('Generi / etichette',
              style: TextStyle(color: Colors.black54, fontSize: 12)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ...all.map((g) {
              final selected = _genres.contains(g);
              return FilterChip(
                label: Text(g),
                selected: selected,
                onSelected: (v) => setState(() {
                  if (v) {
                    _genres.add(g);
                  } else {
                    _genres.remove(g);
                  }
                }),
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Aggiungi'),
              onPressed: _addGenre,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addGenre() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuovo genere / etichetta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty && mounted) {
      await context.read<LibraryProvider>().addGenre(name);
      setState(() => _genres.add(name));
    }
  }

  Widget _coverButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () => _pickCover(ImageSource.gallery),
          icon: const Icon(Icons.photo_library, size: 18),
          label: const Text('Galleria'),
        ),
        OutlinedButton.icon(
          onPressed: () => _pickCover(ImageSource.camera),
          icon: const Icon(Icons.photo_camera, size: 18),
          label: const Text('Fotocamera'),
        ),
        if (_coverData.isNotEmpty)
          TextButton.icon(
            onPressed: () => setState(() => _coverData = ''),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Rimuovi'),
          ),
      ],
    );
  }

  Widget _shelfSelector(List<String> shelves) {
    // Valori del dropdown: nessuno, gli scaffali esistenti, e "nuovo".
    const noneValue = '';
    const newValue = '__new__';
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: noneValue, child: Text('Nessuno scaffale')),
      ...shelves.map((s) => DropdownMenuItem(value: s, child: Text(s))),
      const DropdownMenuItem(
        value: newValue,
        child: Row(
          children: [
            Icon(Icons.add, size: 18),
            SizedBox(width: 6),
            Text('Nuovo scaffale…'),
          ],
        ),
      ),
    ];
    // Se lo scaffale corrente non è più nell'elenco lo aggiungiamo.
    final currentValue =
        _shelf.isEmpty || shelves.contains(_shelf) ? _shelf : noneValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        key: ValueKey('shelf-$currentValue'),
        initialValue: currentValue,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Scaffale',
          prefixIcon: Icon(Icons.shelves),
        ),
        items: items,
        onChanged: (v) {
          if (v == newValue) {
            _createShelf();
          } else {
            setState(() => _shelf = v ?? '');
          }
        },
      ),
    );
  }

  Widget _sessionsEditor() {
    String fmt(DateTime? d) =>
        d == null ? '—' : '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Letture',
                style: TextStyle(color: Colors.black54, fontSize: 12)),
            const Spacer(),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _sessions.add(const ReadingSession())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Aggiungi lettura'),
            ),
          ],
        ),
        if (_sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 4),
            child: Text('Nessuna lettura registrata.',
                style: TextStyle(color: Colors.black45, fontSize: 13)),
          ),
        ...List.generate(_sessions.length, (i) {
          final s = _sessions[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _dateTile(
                      'Inizio',
                      fmt(s.start),
                      () => _pickSessionDate(i, isStart: true),
                    ),
                  ),
                  Expanded(
                    child: _dateTile(
                      'Fine',
                      fmt(s.end),
                      () => _pickSessionDate(i, isStart: false),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rimuovi lettura',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => setState(() => _sessions.removeAt(i)),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _dateTile(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSessionDate(int index, {required bool isStart}) async {
    final s = _sessions[index];
    final initial = (isStart ? s.start : s.end) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: isStart ? 'Data di inizio lettura' : 'Data di fine lettura',
    );
    if (picked == null) return;
    setState(() {
      _sessions[index] =
          isStart ? s.copyWith(start: picked) : s.copyWith(end: picked);
    });
  }

  Widget _statusSelector() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text('Stato di lettura',
                style: TextStyle(color: Colors.black54, fontSize: 12)),
          ),
          SegmentedButton<ReadingStatus>(
            segments: ReadingStatus.values
                .map((s) => ButtonSegment(value: s, label: Text(s.label)))
                .toList(),
            selected: {_status},
            showSelectedIcon: false,
            onSelectionChanged: (sel) =>
                setState(() => _status = sel.first),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          counterText: '',
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null
            : null,
      ),
    );
  }
}
