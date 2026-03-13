import 'dart:typed_data';

Future<String> writeTempFile(String filename, Uint8List bytes) async {
  throw UnsupportedError('File I/O not supported on this platform');
}

void deleteFileSync(String path) {}

Future<Uint8List> readFileBytes(String path) async {
  throw UnsupportedError('File I/O not supported on this platform');
}
