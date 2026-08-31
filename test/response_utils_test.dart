import 'dart:convert';

import 'package:celechron/http/zjuServices/response_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodeResponseBody joins UTF-8 chunks within the limit', () async {
    final chunks = Stream<List<int>>.fromIterable([
      utf8.encode('校历'),
      utf8.encode(' JSON'),
    ]);

    expect(
      await decodeResponseBody(chunks, context: '测试', maxBytes: 32),
      '校历 JSON',
    );
  });

  test('decodeResponseBody rejects a chunked body above the limit', () async {
    final chunks = Stream<List<int>>.fromIterable([
      [1, 2, 3],
      [4, 5, 6],
    ]);

    await expectLater(
      decodeResponseBody(chunks, context: '测试', maxBytes: 5),
      throwsA(isA<ResponseBodyTooLargeException>()),
    );
  });
}
