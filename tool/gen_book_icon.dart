// ignore_for_file: avoid_print
// Genera l'icona dell'app da assets/icon/books.png:
//  - libri ridotti con margine (non vengono tagliati dalla mascheratura)
//  - bordi sfumati nello sfondo teal uniforme → nessun riquadro/bordo netto
// Produce books_icon.png (1024) usato sia per l'icona legacy sia per il
// foreground adattivo. Stampa il colore di sfondo da usare come background.
// Eseguire con:  dart run tool/gen_book_icon.dart
import 'dart:io';
import 'package:image/image.dart' as img;

const int size = 1024;
const int content = 720; // ~70% → più margine attorno ai libri
const double fadeStart = 0.78; // inizio sfumatura (frazione del semi-lato)
const double fadeEnd = 0.99; // fine sfumatura (bordo completamente sfumato)

void main() {
  final src = img.decodePng(File('assets/icon/books.png').readAsBytesSync())!;

  // Colore teal di sfondo: media del bordo escludendo gli angoli scuri.
  int rs = 0, gs = 0, bs = 0, n = 0;
  void acc(int x, int y) {
    final c = src.getPixel(x, y);
    rs += c.r.toInt();
    gs += c.g.toInt();
    bs += c.b.toInt();
    n++;
  }

  for (var x = 20; x < src.width - 20; x += 10) {
    acc(x, 4);
    acc(x, src.height - 5);
  }
  for (var y = 20; y < src.height - 20; y += 10) {
    acc(4, y);
    acc(src.width - 5, y);
  }
  final br = (rs / n).round(), bg = (gs / n).round(), bb = (bs / n).round();
  final fill = img.ColorRgba8(br, bg, bb, 255);
  final hex = '#${br.toRadixString(16).padLeft(2, '0')}'
      '${bg.toRadixString(16).padLeft(2, '0')}'
      '${bb.toRadixString(16).padLeft(2, '0')}';

  // Canvas teal uniforme.
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas, color: fill);

  // Libri ridotti, sfumati verso il teal ai bordi.
  final books =
      img.copyResize(src, width: content, height: content, interpolation: img.Interpolation.cubic);
  const off = (size - content) ~/ 2;
  final half = content / 2;
  for (var y = 0; y < content; y++) {
    for (var x = 0; x < content; x++) {
      final nx = (x - half).abs() / half;
      final ny = (y - half).abs() / half;
      final d = nx > ny ? nx : ny; // distanza "quadrata" dal centro
      double a;
      if (d <= fadeStart) {
        a = 1.0;
      } else if (d >= fadeEnd) {
        a = 0.0;
      } else {
        a = 1.0 - (d - fadeStart) / (fadeEnd - fadeStart);
      }
      final p = books.getPixel(x, y);
      final bx = off + x, by = off + y;
      final r = (p.r * a + br * (1 - a)).round();
      final g = (p.g * a + bg * (1 - a)).round();
      final b = (p.b * a + bb * (1 - a)).round();
      canvas.setPixelRgba(bx, by, r, g, b, 255);
    }
  }

  File('assets/icon/books_icon.png').writeAsBytesSync(img.encodePng(canvas));
  print('Sfondo teal: $hex');
  print('Generato: books_icon.png (libri ~$content px, con sfumatura)');
}
