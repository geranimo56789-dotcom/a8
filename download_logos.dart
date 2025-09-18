import 'dart:io';
import 'dart:typed_data';

void main() async {
  final logos = {
    'ful':
        'https://upload.wikimedia.org/wikipedia/en/thumb/e/eb/Fulham_FC_%28shield%29.svg/1200px-Fulham_FC_%28shield%29.svg.png',
    'avl':
        'https://upload.wikimedia.org/wikipedia/en/thumb/f/f9/Aston_Villa_FC_crest_%282023%29.svg/1200px-Aston_Villa_FC_crest_%282023%29.svg.png',
    'new':
        'https://upload.wikimedia.org/wikipedia/en/thumb/5/56/Newcastle_United_Logo.svg/1200px-Newcastle_United_Logo.svg.png',
    'bou':
        'https://upload.wikimedia.org/wikipedia/en/thumb/e/e5/AFC_Bournemouth_%282013%29.svg/1200px-AFC_Bournemouth_%282013%29.svg.png',
    'bha':
        'https://upload.wikimedia.org/wikipedia/en/thumb/f/fd/Brighton_%26_Hove_Albion_logo.svg/1200px-Brighton_%26_Hove_Albion_logo.svg.png',
  };

  final client = HttpClient();
  final targetDir = Directory('assets/logos/clubs');

  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }

  for (var entry in logos.entries) {
    final code = entry.key;
    final url = entry.value;
    final file = File('${targetDir.path}/$code.png');

    if (!await file.exists()) {
      print('Downloading $code.png...');
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();

        if (response.statusCode == 200) {
          final bytes = await response
              .fold<BytesBuilder>(
                BytesBuilder(),
                (builder, chunk) => builder..add(chunk),
              )
              .then((builder) => builder.takeBytes());
          await file.writeAsBytes(bytes);
          print('Saved ${file.path}');
        } else {
          print('Failed to download $code.png: Status ${response.statusCode}');
        }
      } catch (e) {
        print('Error downloading $code.png: $e');
      }
    } else {
      print('$code.png already exists.');
    }
  }

  client.close();
}
