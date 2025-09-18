import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

void main() async {
  // Create a 200x200 white canvas with a red circle and 'LFC' text
  final pictureRecorder = ui.PictureRecorder();
  final canvas = Canvas(pictureRecorder);
  final size = Size(200, 200);

  // Fill with white background
  final paint = Paint()..color = Colors.white;
  canvas.drawRect(Offset.zero & size, paint);

  // Draw red circle
  paint.color = Colors.red[900]!;
  canvas.drawCircle(Offset(100, 100), 90, paint);

  // Draw text
  final textPainter = TextPainter(
    text: TextSpan(
      text: 'LFC',
      style: TextStyle(
        color: Colors.white,
        fontSize: 48,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    ),
  );

  // Convert to image
  final picture = pictureRecorder.endRecording();
  final img = await picture.toImage(200, 200);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final buffer = byteData!.buffer.asUint8List();

  // Save to file
  final outputFile = File(
    path.join(Directory.current.path, 'assets', 'logos', 'clubs', 'liv.png'),
  );

  await outputFile.create(recursive: true);
  await outputFile.writeAsBytes(buffer);

  print('Liverpool logo generated at: ${outputFile.path}');
}
