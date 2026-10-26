// Generates strictly opaque PNG icons for iOS alternate icon support.
// iOS REQUIRES: no alpha channel at all in app icons.
// This script composites the Plus logo onto a solid black background
// and exports at exact iOS icon sizes as RGB-only PNGs.

import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final srcPath = 'assets/icons/plus_logo.png';
  final srcBytes = File(srcPath).readAsBytesSync();
  final srcImage = img.decodePng(srcBytes);
  if (srcImage == null) {
    print('ERROR: Could not decode $srcPath');
    exit(1);
  }

  print('Source: ${srcImage.width}x${srcImage.height}, numChannels=${srcImage.numChannels}');

  // Composite onto solid black background to flatten alpha
  final composited = img.Image(width: srcImage.width, height: srcImage.height, numChannels: 3);
  
  // Fill with black
  for (int y = 0; y < composited.height; y++) {
    for (int x = 0; x < composited.width; x++) {
      composited.setPixelRgb(x, y, 0, 0, 0);
    }
  }
  
  // Alpha-composite the source onto the black background
  for (int y = 0; y < srcImage.height; y++) {
    for (int x = 0; x < srcImage.width; x++) {
      final srcPixel = srcImage.getPixel(x, y);
      final sr = srcPixel.r.toInt();
      final sg = srcPixel.g.toInt();
      final sb = srcPixel.b.toInt();
      final sa = srcImage.numChannels >= 4 ? srcPixel.a.toInt() : 255;
      
      // Alpha blend: result = src * alpha/255 + dst * (1 - alpha/255)
      final alpha = sa / 255.0;
      final r = (sr * alpha).clamp(0, 255).toInt();
      final g = (sg * alpha).clamp(0, 255).toInt();
      final b = (sb * alpha).clamp(0, 255).toInt();
      
      composited.setPixelRgb(x, y, r, g, b);
    }
  }

  // Define required iOS sizes
  final sizes = {
    'ios/Runner/Plus@2x.png': 120,
    'ios/Runner/Plus@3x.png': 180,
    'ios/Runner/Plus~ipad.png': 152,
    'ios/Runner/Plus@2x~ipad.png': 167,
    'ios/Runner/Plus.png': 1024,
  };

  for (final entry in sizes.entries) {
    final path = entry.key;
    final size = entry.value;
    
    // Resize with high quality
    final resized = img.copyResize(composited, width: size, height: size, interpolation: img.Interpolation.cubic);
    
    // Ensure 3-channel (RGB, no alpha)
    final rgb = img.Image(width: size, height: size, numChannels: 3);
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final p = resized.getPixel(x, y);
        rgb.setPixelRgb(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt());
      }
    }
    
    final pngBytes = img.encodePng(rgb);
    File(path).writeAsBytesSync(pngBytes);
    print('✅ Written $path (${size}x${size}, RGB only, ${pngBytes.length} bytes)');
  }

  print('\nDone! All icons are strictly opaque RGB PNGs.');
}
