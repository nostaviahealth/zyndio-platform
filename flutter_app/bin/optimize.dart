import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  print('Starting true transparency optimization...');
  final bytes = await File('assets/icons/plus_logo.png').readAsBytes();
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

    int maxVal = r;
    if (g > maxVal) maxVal = g;
    if (b > maxVal) maxVal = b;

    if (maxVal == 0) {
      pixel.a = 0;
      pixel.r = 0;
      pixel.g = 0;
      pixel.b = 0;
    } else {
      double intensity = maxVal / 255.0;
      double alphaDouble = intensity * 1.5; 
      if (alphaDouble > 1.0) alphaDouble = 1.0;

      pixel.a = (alphaDouble * 255).toInt();
      pixel.r = (r / alphaDouble).clamp(0, 255).toInt();
      pixel.g = (g / alphaDouble).clamp(0, 255).toInt();
      pixel.b = (b / alphaDouble).clamp(0, 255).toInt();
    }
  }

  final optimized = img.encodePng(rgba);
  await File('assets/icons/plus_logo_transparent.png').writeAsBytes(optimized);
  print('✅ perfectly transparent logo created => assets/icons/plus_logo_transparent.png');
}
