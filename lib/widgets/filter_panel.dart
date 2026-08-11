import 'package:flutter/material.dart';

import '../models/book.dart';
import '../providers/library_provider.dart';

/// Pannello con i quattro filtri di ricerca: titolo, autore, anno, editore.
class FilterPanel extends StatefulWidget {
  final LibraryProvider provider;
  const FilterPanel({super.key, required this.provider});

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _year;
  late final TextEditingController _publisher;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.provider.titleFilter);
    _author = TextEditingController(text: widget.provider.authorFilter);
    _year = TextEditingController(text: widget.provider.yearFilter);
    _publisher = TextEditingController(text: widget.provider.publisherFilter);
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _year.dispose();
    _publisher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    return Container(
      color: const Color(0xFFEDF2F3),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _filterField(
                  _title,
                  'Titolo',
                  Icons.title,
                  p.setTitleFilter,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _filterField(
                  _author,
                  'Autore',
                  Icons.person_outline,
                  p.setAuthorFilter,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _filterField(
                  _publisher,
                  'Editore',
                  Icons.business,
                  p.setPublisherFilter,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _filterField(
                  _year,
                  'Anno',
                  Icons.calendar_today,
                  p.setYearFilter,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _shelfDropdown(p)),
              const SizedBox(width: 10),
              Expanded(child: _statusDropdown(p)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _genreDropdown(p)),
              const SizedBox(width: 10),
              Expanded(child: _finishYearDropdown(p)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _genreDropdown(LibraryProvider p) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('Tutti i generi')),
      ...p.genres.map((g) => DropdownMenuItem(value: g, child: Text(g))),
    ];
    final value = p.genres.contains(p.genreFilter) ? p.genreFilter : '';
    return DropdownButtonFormField<String>(
      key: ValueKey('genre-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Genere',
        prefixIcon: Icon(Icons.category, size: 20),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items,
      onChanged: (v) => p.setGenreFilter(v ?? ''),
    );
  }

  Widget _finishYearDropdown(LibraryProvider p) {
    final years = p.finishYears;
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('Qualsiasi anno')),
      ...years
          .map((y) => DropdownMenuItem(value: '$y', child: Text('$y'))),
    ];
    final value =
        years.map((y) => '$y').contains(p.finishYearFilter) ? p.finishYearFilter : '';
    return DropdownButtonFormField<String>(
      key: ValueKey('fy-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Fine lettura',
        prefixIcon: Icon(Icons.event_available, size: 20),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items,
      onChanged: (v) => p.setFinishYearFilter(v ?? ''),
    );
  }

  Widget _shelfDropdown(LibraryProvider p) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('Tutti gli scaffali')),
      const DropdownMenuItem(
          value: LibraryProvider.noShelf, child: Text('Senza scaffale')),
      ...p.shelves.map((s) => DropdownMenuItem(value: s, child: Text(s))),
    ];
    final value =
        (p.shelfFilter == LibraryProvider.noShelf || p.shelfFilter.isEmpty)
            ? p.shelfFilter
            : (p.shelves.contains(p.shelfFilter) ? p.shelfFilter : '');
    return DropdownButtonFormField<String>(
      key: ValueKey('shelf-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Scaffale',
        prefixIcon: Icon(Icons.shelves, size: 20),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items,
      onChanged: (v) => p.setShelfFilter(v ?? ''),
    );
  }

  Widget _statusDropdown(LibraryProvider p) {
    final items = <DropdownMenuItem<ReadingStatus?>>[
      const DropdownMenuItem(value: null, child: Text('Tutti gli stati')),
      ...ReadingStatus.values
          .map((s) => DropdownMenuItem(value: s, child: Text(s.label))),
    ];
    return DropdownButtonFormField<ReadingStatus?>(
      key: ValueKey('status-${p.statusFilter}'),
      initialValue: p.statusFilter,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Stato',
        prefixIcon: Icon(Icons.menu_book, size: 20),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items,
      onChanged: (v) => p.setStatusFilter(v),
    );
  }

  Widget _filterField(
    TextEditingController c,
    String label,
    IconData icon,
    ValueChanged<String> onChanged, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: c,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: c.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  c.clear();
                  onChanged('');
                  setState(() {});
                },
              ),
      ),
    );
  }
}
