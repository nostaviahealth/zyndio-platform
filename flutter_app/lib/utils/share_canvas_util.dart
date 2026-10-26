import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';

/// Utility for capturing native widgets as pristine images and piping them to OS sharing dialogs.
/// We use completely native RepaintBoundary capturing instead of third-party screenshot packages
/// to guarantee zero crashes on iOS startup rendering engines.
class ShareCanvasUtil {
  
  static Future<void> captureWithKeyAndShare({
    required BuildContext context,
    required GlobalKey key,
    required String label,
  }) async {
    try {
      // 1. Give the UI thread a heartbeat to ensure the Brand Footer has rendered
      await Future.delayed(const Duration(milliseconds: 50));

      // 2. Extract the boundary explicitly from the widget tree
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not locate the RepaintBoundary capture context.');
      }

      // Removed debugNeedsPaint check: In Release mode, this getter throws a LateInitializationError
      // because its internal 'result' variable is only initialized inside an assert() block!
      // Instead, we just unconditionally wait a tiny bit for the frame to settle.
      await Future.delayed(const Duration(milliseconds: 50));

      // 3. High-Fidelity Capture (Scales perfectly for Retina and ProMotion devices)
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('Image engine failed to serialize to PNG byte format.');
      }

      final pngBytes = byteData.buffer.asUint8List();

      // 4. Secure File Drop to OS temporary cache
      final tempDirPath = Directory.systemTemp.path;
      final fileName = 'zyndio_certified_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File('$tempDirPath/$fileName');
      
      await imageFile.writeAsBytes(pngBytes, flush: true);

      // Sanitize Origin bounds for flawless iPad/Mac dialog rendering
      final originBox = context.findRenderObject() as RenderBox?;
      final origin = originBox != null ? originBox.localToGlobal(Offset.zero) & originBox.size : null;


      // 5. Native OS Sharing
      // Bypassing `Share.shareXFiles` to avoid an AOT compilation bug in the `share_plus` 
      // plugin's Dart interface where its internal `result` variable is uninitialized.
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      final params = <String, dynamic>{
        'paths': [imageFile.path],
        'mimeTypes': ['image/png'],
        'text': 'My $label progress decoded by Zyndio Intelligence 🧬',
      };
      
      if (origin != null) {
        params['originX'] = origin.left;
        params['originY'] = origin.top;
        params['originWidth'] = origin.width;
        params['originHeight'] = origin.height;
      }
      
      await channel.invokeMethod<String>('shareFiles', params);

    } catch (e) {
      debugPrint('Capture Utility Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('Capture failed: ${e.toString().split('\n').first}'),
             backgroundColor: Colors.red.withOpacity(0.9),
           ),
        );
      }
    }
  }
}

