import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String> writeTempFile(String filename, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  return file.path;
}

void deleteFileSync(String path) {
  try {
    File(path).deleteSync();
  } catch (_) {}
}

Future<Uint8List> readFileBytes(String path) async {
  return await File(path).readAsBytes();
}
