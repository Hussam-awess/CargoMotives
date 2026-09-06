import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('multipart list encoding (regression)', () {
    // TruckRepository.submit() relies on ListFormat.multiCompatible to send
    // multiple photos as `photos[]` (repeated). Dio's *default*
    // ListFormat.multi only brackets a list entry when the entry is itself
    // a Map/List — a MultipartFile isn't, so every photo would be sent
    // under the exact same bare `photos` field name, and Laravel/PHP keeps
    // only the LAST of several same-named non-bracketed multipart parts,
    // not an array — silently dropping every photo but one. This test
    // pins Dio's actual behavior so a future Dio upgrade, or someone
    // "simplifying" the ListFormat argument back to the default, is
    // caught here rather than as a live upload bug.
    test('multiCompatible sends each file under a bracketed key', () {
      final formData = FormData.fromMap({
        'photos': [
          MultipartFile.fromBytes([1], filename: 'a.jpg'),
          MultipartFile.fromBytes([2], filename: 'b.jpg'),
        ],
      }, ListFormat.multiCompatible);

      expect(formData.files.map((e) => e.key), ['photos[]', 'photos[]']);
    });

    test('the default ListFormat.multi does NOT bracket file list entries', () {
      final formData = FormData.fromMap({
        'photos': [
          MultipartFile.fromBytes([1], filename: 'a.jpg'),
          MultipartFile.fromBytes([2], filename: 'b.jpg'),
        ],
      });

      expect(formData.files.map((e) => e.key), ['photos', 'photos']);
    });
  });
}
