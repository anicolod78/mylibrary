// Test unitari sul modello Book (logica pura, senza Hive né UI).

import 'package:flutter_test/flutter_test.dart';
import 'package:mylibrary/models/book.dart';

void main() {
  test('toMap/fromMap è un roundtrip fedele', () {
    final book = Book.create(
      isbn: '9788804668237',
      title: 'Titolo di prova',
      author: 'Autore',
      publisher: 'Editore',
      year: '2021',
      coverUrl: 'https://example.com/c.jpg',
      note: 'una nota',
    );

    final restored = Book.fromMap(book.toMap());

    expect(restored.id, book.id);
    expect(restored.isbn, book.isbn);
    expect(restored.title, book.title);
    expect(restored.author, book.author);
    expect(restored.publisher, book.publisher);
    expect(restored.year, book.year);
    expect(restored.coverUrl, book.coverUrl);
    expect(restored.note, book.note);
    expect(restored.dateAdded, book.dateAdded);
  });

  test('copyWith modifica solo i campi indicati', () {
    final book = Book.create(title: 'Originale', author: 'A');
    final updated = book.copyWith(title: 'Nuovo');

    expect(updated.id, book.id);
    expect(updated.title, 'Nuovo');
    expect(updated.author, 'A');
  });

  test('hasCover riflette la presenza di un URL copertina', () {
    expect(Book.create(coverUrl: '').hasCover, isFalse);
    expect(Book.create(coverUrl: 'https://x/y.jpg').hasCover, isTrue);
  });
}
