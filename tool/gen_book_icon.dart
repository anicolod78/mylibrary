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

// Colore di sfondo desiderato ("azzurro puffo") e luminanza di riferimento
// del teal originale (canale G del teal di sfondo), per la ricolorazione.
const int sr = 79, sg = 195, sb = 247; // #4FC3F7
const double baseG = 93.0;

int _cl(num v) => v.round().clamp(0, 255);

/// True se il pixel appartiene alla famiglia "teal" (sfondo/ombre/barcode).
/// I libri (rosso/giallo/blu navy/crema) restano esclusi.
bool _isTeal(int r, int g, int b) =>
    g > r && b > r && (g - b).abs() <= 25 && g < 210;

/// Ricolora il teal in azzurro preservando la luminosità relativa (così il
/// barcode, teal più chiaro, resta visibile come azzurro più chiaro).
img.Image _recolor(img.Image src) {
  final out = img.Image(width: src.width, height: src.height, numChannels: 3);
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
      if (_isTeal(r, g, b)) {
        final s = g / baseG;
        out.setPixelRgb(x, y, _cl(sr * s), _cl(sg * s), _cl(sb * s));
      } else {
        out.setPixelRgb(x, y, r, g, b);
      }
    }
  }
  return out;
}

void main() {
  final original = img.decodePng(File('assets/icon/books.png').readAsBytesSync())!;
  final src = _recolor(original);

  final br = sr, bg = sg, bb = sb;
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
