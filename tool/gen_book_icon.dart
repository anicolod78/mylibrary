// ignore_for_file: avoid_print
// Genera l'icona dell'app da assets/icon/books.png, SENZA ricolorazioni:
//  - libri ridotti con margine (non vengono tagliati dalla mascheratura)
//  - bordi sfumati sullo sfondo (campionato dall'immagine) → nessun riquadro
// Produce books_icon.png (1024) usato sia per l'icona legacy sia per il
// foreground adattivo. Stampa il colore di sfondo da usare come background.
// Eseguire con:  dart run tool/gen_book_icon.dart
import 'dart:io';
import 'package:image/image.dart' as img;

const int size = 1024;
const int content = 880; // ~86% → i libri hanno già un margine interno
const double fadeStart = 0.88; // sfumatura solo sul bordo estremo
const double fadeEnd = 0.99;

int _cl(num v) => v.round().clamp(0, 255);

void main() {
  final src = img.decodePng(File('assets/icon/books.png').readAsBytesSync())!;

  // Colore di sfondo: media dei pixel del bordo dell'immagine.
  int rs = 0, gs = 0, bs = 0, n = 0;
  void acc(int x, int y) {
    final c = src.getPixel(x, y);
    rs += c.r.toInt();
    gs += c.g.toInt();
    bs += c.b.toInt();
    n++;
  }

  for (var x = 6; x < src.width - 6; x += 6) {
    acc(x, 3);
    acc(x, src.height - 4);
  }
  for (var y = 6; y < src.height - 6; y += 6) {
    acc(3, y);
    acc(src.width - 4, y);
  }
  final br = (rs / n).round(), bg = (gs / n).round(), bb = (bs / n).round();
  final fill = img.ColorRgba8(br, bg, bb, 255);
  final hex = '#${br.toRadixString(16).padLeft(2, '0')}'
      '${bg.toRadixString(16).padLeft(2, '0')}'
      '${bb.toRadixString(16).padLeft(2, '0')}';

  // Canvas con lo stesso colore di sfondo.
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas, color: fill);

  // Immagine ridotta, con bordi sfumati verso lo sfondo.
  final books = img.copyResize(src,
      width: content, height: content, interpolation: img.Interpolation.cubic);
  const off = (size - content) ~/ 2;
  final half = content / 2;
  for (var y = 0; y < content; y++) {
    for (var x = 0; x < content; x++) {
      final nx = (x - half).abs() / half;
      final ny = (y - half).abs() / half;
      final d = nx > ny ? nx : ny;
      double a;
      if (d <= fadeStart) {
        a = 1.0;
      } else if (d >= fadeEnd) {
        a = 0.0;
      } else {
        a = 1.0 - (d - fadeStart) / (fadeEnd - fadeStart);
      }
      final p = books.getPixel(x, y);
      canvas.setPixelRgba(
        off + x,
        off + y,
        _cl(p.r * a + br * (1 - a)),
        _cl(p.g * a + bg * (1 - a)),
        _cl(p.b * a + bb * (1 - a)),
        255,
      );
    }
  }

  File('assets/icon/books_icon.png').writeAsBytesSync(img.encodePng(canvas));
  print('Sfondo: $hex');
  print('Generato: books_icon.png (senza ricolorazioni)');
}
