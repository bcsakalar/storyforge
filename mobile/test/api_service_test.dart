import 'package:flutter_test/flutter_test.dart';
import 'package:storyforge_mobile/services/api_service.dart';

void main() {
  group('ApiService.extractChapterAudio', () {
    test('returns audio when payload contains a non-empty audio field', () {
      expect(ApiService.extractChapterAudio({'audio': 'base64-audio'}), 'base64-audio');
    });

    test('throws backend error when payload contains an error field', () {
      expect(
        () => ApiService.extractChapterAudio({'error': 'Cok fazla ses istegi. Biraz bekle.'}),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Cok fazla ses istegi. Biraz bekle.'),
          ),
        ),
      );
    });

    test('throws a generic error when payload has no usable audio data', () {
      expect(
        () => ApiService.extractChapterAudio({'audio': ''}),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Ses verisi alınamadı'),
          ),
        ),
      );
    });
  });
}