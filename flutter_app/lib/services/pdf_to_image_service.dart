import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';

class PdfToImageService {
  /// Converts PDF pages to images.
  /// [filePath] is the path to the PDF file.
  /// [startPage] and [endPage] are 0-indexed.
  static Future<List<File>> convertPdfToImages(String filePath, {int startPage = 0, int? endPage, Function(int, int)? onProgress}) async {
    final List<File> imageFiles = [];
    
    try {
      // On iOS, some PDFs (like Lal Path Lab) fail with "Invalid PDF format" when opened via path.
      // Opening via bytes (openData) is more robust as it bypasses path/sandbox issues in the native layer.
      final bytes = await File(filePath).readAsBytes();
      final document = await PdfDocument.openData(bytes);
      final int actualEndPage = endPage ?? document.pagesCount;
      
      final tempDir = await getTemporaryDirectory();
      
      for (int i = startPage; i < actualEndPage && i < document.pagesCount; i++) {
        onProgress?.call(i + 1, actualEndPage);
        final page = await document.getPage(i + 1); // pdfx is 1-indexed for pages
        
        final pageImage = await page.render(
          width: page.width * 1.5, // 1.5x gives good OCR accuracy for 2-page chunks
          height: page.height * 1.5,
          format: PdfPageImageFormat.jpeg,
          quality: 80, // Good balance: 2 images at 80% < 1 image at 90% in payload
        );

        if (pageImage != null) {
          final File imageFile = File('${tempDir.path}/page_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await imageFile.writeAsBytes(pageImage.bytes);
          debugPrint('PdfToImage: Converted page ${i+1} (${pageImage.bytes.length} bytes)');
          
          imageFiles.add(imageFile);
        }
        
        await page.close();
      }
      
      await document.close();
    } catch (e) {
      debugPrint('Error converting PDF to images: $e');
      rethrow;
    }
    
    return imageFiles;
  }
}
