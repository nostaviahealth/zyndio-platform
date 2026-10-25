import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  print('Starting true transparency optimization...');
  final bytes = await File('flutter_app/assets/icons/plus_logo.png').readAsBytes();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Failed to decode image');
    return;
  }

  final rgba = image.convert(numChannels: 4);

  for (var pixel in rgba) {
    int r = pixel.r.toInt();
    int g = pixel.g.toInt();
    int b = pixel.b.toInt();

    // Find max value to determine original alpha
    int maxVal = r;
    if (g > maxVal) maxVal = g;
    if (b > maxVal) maxVal = b;

    if (maxVal == 0) {
      pixel.a = 0;
      pixel.r = 0;
      pixel.g = 0;
      pixel.b = 0;
    } else {
      // Scale alpha to keep bright colors solid
      double intensity = maxVal / 255.0;
      // aggressively compress alpha to opaque to prevent text see-through
      double alphaDouble = intensity * 1.5; 
      if (alphaDouble > 1.0) alphaDouble = 1.0;

      pixel.a = (alphaDouble * 255).toInt();
      
      // Un-premultiply RGB to restore original silver/white colors
      pixel.r = (r / alphaDouble).clamp(0, 255).toInt();
      pixel.g = (g / alphaDouble).clamp(0, 255).toInt();
      pixel.b = (b / alphaDouble).clamp(0, 255).toInt();
    }
  }

  final optimized = img.encodePng(rgba);
  await File('flutter_app/assets/icons/plus_logo_transparent.png').writeAsBytes(optimized);
  print('✅ Perfectly transparent logo created: assets/icons/plus_logo_transparent.png');
}
