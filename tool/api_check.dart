// ignore_for_file: avoid_print
// Verifica live del BookApiService: dato che Google Books qui risponde 429,
// questo script esercita di fatto il fallback su Open Library.
// Eseguire con:  dart run tool/api_check.dart
import 'package:mylibrary/services/book_api_service.dart';

Future<void> main() async {
  final api = BookApiService();

  print('== Ricerca per TITOLO: "il nome della rosa" ==');
  final byTitle = await api.searchByTitle('il nome della rosa', maxResults: 3);
  print('risultati: ${byTitle.length}');
  for (final b in byTitle) {
    print(' - ${b.title} | ${b.author} | ${b.publisher} | ${b.year} '
        '| cover=${b.coverUrl.isNotEmpty}');
  }

  print('\n== Ricerca per ISBN: 9788845292613 (presente su OL) ==');
  final byIsbn = await api.searchByIsbn('9788845292613');
  print('risultato: ${byIsbn?.title ?? "null"}');

  print('\n== ISBN vari (con numero di pagine) ==');
  for (final isbn in ['9788804668237', '9788817189040', '9788804739029']) {
    final b = await api.searchByIsbn(isbn);
    print(' $isbn → ${b == null ? "null" : "${b.title} | pagine=${b.pages}"}');
  }

  api.dispose();
}
