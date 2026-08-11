// ignore_for_file: avoid_print
// Genera l'icona dell'app (una pila di libri) a 1024x1024.
// Produce:
//  - assets/icon/icon.png            (sfondo teal + libri)  → icona legacy
//  - assets/icon/icon_foreground.png (solo libri, trasparente) → adaptive
// Eseguire con:  dart run tool/gen_icon.dart
import 'dart:io';
import 'package:image/image.dart' as img;

const int size = 1024;

// Palette
final teal = img.ColorRgba8(0x3E, 0x7C, 0x88, 255); // sfondo tema
final outline = img.ColorRgba8(38, 40, 48, 255);
final pages = img.ColorRgba8(245, 241, 230, 255);
final transparent = img.ColorRgba8(0, 0, 0, 0);

// Colori dei 4 libri (dal basso verso l'alto)
final bookColors = <img.Color>[
  img.ColorRgba8(0xD9, 0x65, 0x4E, 255), // rosso mattone
  img.ColorRgba8(0xE8, 0xB0, 0x4B, 255), // senape
  img.ColorRgba8(0x4F, 0xA3, 0xA5, 255), // verde acqua
  img.ColorRgba8(0x3E, 0x6D, 0xA8, 255), // blu
];
// Larghezza (frazione della regione) e offset orizzontale per un look "impilato a mano"
final bookW = <double>[0.80, 0.66, 0.84, 0.70];
final bookDx = <double>[-0.02, 0.05, -0.03, 0.03];

void drawStack(img.Image image, int left, int top, int region) {
  final cx = left + region ~/ 2;
  final bookH = (region * 0.155).round();
  final gap = (region * 0.025).round();
  final totalH = bookH * 4 + gap * 3;
  var y = top + (region - totalH) ~/ 2 + totalH - bookH; // parte dal basso
  final thickness = (region * 0.012).clamp(2, 12).round();
  final radius = (bookH * 0.28).round();

  for (var i = 0; i < 4; i++) {
    final bw = (region * bookW[i]).round();
    final bx = cx + (region * bookDx[i]).round();
    final x1 = bx - bw ~/ 2;
    final x2 = bx + bw ~/ 2;
    final y1 = y;
    final y2 = y + bookH;

    img.fillRect(image,
        x1: x1, y1: y1, x2: x2, y2: y2, color: bookColors[i], radius: radius);

    // Taglio pagine (fore-edge) sul lato destro del libro.
    final edge = (bw * 0.10).round();
    img.fillRect(image,
        x1: x2 - edge,
        y1: y1 + thickness,
        x2: x2 - thickness,
        y2: y2 - thickness,
        color: pages,
        radius: (radius * 0.6).round());

    img.drawRect(image,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        color: outline,
        thickness: thickness,
        radius: radius);

    y -= (bookH + gap); // libro successivo più in alto
  }
}

void main() {
  final dir = Directory('assets/icon');
  dir.createSync(recursive: true);

  // 1) Icona completa: sfondo teal + libri.
  final icon = img.Image(width: size, height: size, numChannels: 4);
  img.fill(icon, color: teal);
  drawStack(icon, 180, 180, 664);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(icon));

  // 2) Foreground adaptive: solo libri, sfondo trasparente, entro la safe-zone.
  final fg = img.Image(width: size, height: size, numChannels: 4);
  img.fill(fg, color: transparent);
  drawStack(fg, 232, 232, 560);
  File('assets/icon/icon_foreground.png').writeAsBytesSync(img.encodePng(fg));

  print('Icone generate in assets/icon/ (icon.png, icon_foreground.png)');
}
