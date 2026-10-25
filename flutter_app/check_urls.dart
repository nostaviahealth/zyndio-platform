import 'dart:io';

void main() async {
  final urls = [
    'https://images.unsplash.com/photo-1576073719676-aa95576db207?w=500&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1607619056574-7b8d304f3b24?w=500&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=500&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1576671081837-49000212a370?w=500&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1614934898242-706509f6368d?w=500&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1611930022073-b7a4ba5fcccd?w=500&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=500&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=500&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1628773950672-0051edfa52a3?w=500&auto=format&fit=crop&q=80'
  ];

  for (final url in urls) {
    try {
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();
      print('${response.statusCode} - $url');
    } catch (e) {
      print('ERROR - $url - $e');
    }
  }
}
