import 'dart:convert';
import 'dart:typed_data';

import 'package:cargo_motives/core/network/api_client.dart';
import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_session_store.dart';

/// Plays back a scripted sequence of outcomes, one per request: an int is
/// an HTTP status (with a JSON body), 'drop' is a dropped connection.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.script);

  final List<Object> script;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final outcome = script[requests.length - 1];
    if (outcome == 'drop') {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    }
    final status = outcome as int;
    return ResponseBody.fromString(
      jsonEncode(status < 400 ? {'ok': true} : {'message': 'Server Error'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_ScriptedAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api'))..httpClientAdapter = adapter;
  return ApiClient(sessionStore: FakeSessionStore(), dio: dio, retryDelay: (_) => Duration.zero);
}

void main() {
  test('a GET that hits a dropped connection is retried and then succeeds', () async {
    final adapter = _ScriptedAdapter(['drop', 200]);

    final body = await _client(adapter).get('/jobs');

    expect(body['ok'], isTrue);
    expect(adapter.requests, hasLength(2));
  });

  test('a GET retries a momentary 503 but gives up after two retries', () async {
    final adapter = _ScriptedAdapter([503, 503, 503, 200]);

    await expectLater(_client(adapter).get('/jobs'), throwsA(isA<ApiException>()));
    expect(adapter.requests, hasLength(3));
  });

  test('a 4xx is never retried', () async {
    final adapter = _ScriptedAdapter([422, 200]);

    await expectLater(_client(adapter).get('/jobs'), throwsA(isA<ApiException>()));
    expect(adapter.requests, hasLength(1));
  });

  test('a POST is never retried, even on a dropped connection', () async {
    final adapter = _ScriptedAdapter(['drop', 200]);

    await expectLater(_client(adapter).post('/bids', data: {'price': 1}), throwsA(isA<ApiException>()));
    expect(adapter.requests, hasLength(1));
  });

  test('every request carries a fresh request id', () async {
    final adapter = _ScriptedAdapter([200, 200]);
    final client = _client(adapter);

    await client.get('/a');
    await client.get('/b');

    final ids = adapter.requests.map((r) => r.headers['X-Request-Id']).toList();
    expect(ids.every((id) => id is String && RegExp(r'^m-[0-9a-f]{12}$').hasMatch(id)), isTrue);
    expect(ids.toSet(), hasLength(2));
  });

  test('a server error shows a friendly message with a reference, not the raw body', () async {
    final adapter = _ScriptedAdapter([500]);

    try {
      await _client(adapter).post('/jobs');
      fail('expected an ApiException');
    } on ApiException catch (e) {
      expect(e.message, isNot(contains('Server Error')));
      expect(e.requestId, isNotNull);
      expect(e.message, contains(e.requestId!));
    }
  });
}
