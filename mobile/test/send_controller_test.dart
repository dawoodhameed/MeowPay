import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meowpay/api/meowpay_api.dart';
import 'package:meowpay/state/send_controller.dart';

/// A fake transport, not a fake ledger. Concurrency and locking are proven against
/// a real PostgreSQL in the backend suite; what matters here is how the client
/// behaves when the network fails, which cannot be provoked reliably against a
/// real server.
MockClient _client({
  required Future<http.Response> Function(http.Request) handler,
}) =>
    MockClient((request) => handler(request));

const _catsJson = '''
[
  {"id":"c1","name":"Whiskers","avatarUrl":null,"walletId":"w1","balance":100},
  {"id":"c2","name":"Mittens","avatarUrl":null,"walletId":"w2","balance":50}
]
''';

SendController _controllerWith(
  Future<http.Response> Function(http.Request) handler,
) =>
    SendController(
      api: MeowPayApi(client: _client(handler: handler), baseUrl: ''),
    );

void main() {
  group('loading cats', () {
    test('selects a sender and a different recipient by default', () async {
      final controller = _controllerWith(
        (_) async => http.Response(_catsJson, 200),
      );

      await controller.loadCats();

      expect(controller.cats, hasLength(2));
      expect(controller.sender!.name, 'Whiskers');
      expect(controller.recipient!.name, 'Mittens');
      expect(controller.loadError, isNull);
    });

    test('reports an unreachable API without throwing', () async {
      final controller = _controllerWith(
        (_) async => throw const SocketExceptionStub(),
      );

      await controller.loadCats();

      expect(controller.loadError, contains('Cannot reach'));
      expect(controller.cats, isEmpty);
    });
  });

  group('amount validation', () {
    late SendController controller;

    setUp(() async {
      controller = _controllerWith((_) async => http.Response(_catsJson, 200));
      await controller.loadCats();
    });

    test('rejects empty, non-numeric, zero and negative amounts', () {
      expect(controller.validateAmount(''), 'Enter an amount');
      expect(controller.validateAmount('abc'), 'Whole numbers only');
      // Decimals are rejected: a treat is a whole unit, and int.tryParse is what
      // keeps a fractional amount from ever reaching the ledger.
      expect(controller.validateAmount('1.5'), 'Whole numbers only');
      expect(controller.validateAmount('0'), 'Must be more than zero');
      expect(controller.validateAmount('-5'), 'Must be more than zero');
    });

    test('rejects more than the sender holds', () {
      expect(controller.validateAmount('101'), 'Only 100 treats available');
      expect(controller.validateAmount('100'), isNull);
    });
  });

  group('idempotency key lifecycle', () {
    test('reuses the key when the network failed, so a retry is not a second transfer',
        () async {
      final keysSeen = <String>[];
      var attempt = 0;

      final controller = _controllerWith((request) async {
        if (request.method == 'GET') return http.Response(_catsJson, 200);
        keysSeen.add(request.headers['X-Idempotency-Key']!);
        attempt++;
        // First send times out; the transfer may or may not have committed.
        if (attempt == 1) throw const SocketExceptionStub();
        return http.Response(
          jsonEncode({'id': 't1', 'amount': 10, 'senderBalanceAfter': 90}),
          201,
        );
      });

      await controller.loadCats();
      await controller.send(10);

      expect(controller.status, SendStatus.failure);
      // The key survives, because the outcome is unknown.
      expect(controller.pendingKey, isNotNull);

      await controller.send(10);

      expect(controller.status, SendStatus.success);
      expect(keysSeen, hasLength(2));
      // The critical assertion: the retry carried the same key, so the server can
      // recognise the duplicate rather than moving treats a second time.
      expect(keysSeen[0], keysSeen[1]);
      expect(controller.pendingKey, isNull);
    });

    test('retires the key when the ledger refuses the transfer', () async {
      final controller = _controllerWith((request) async {
        if (request.method == 'GET') return http.Response(_catsJson, 200);
        return http.Response(
          jsonEncode({
            'type': 'https://meowpay.co/problems/insufficient-funds',
            'title': 'Not enough treats',
            'balance': 12,
          }),
          422,
        );
      });

      await controller.loadCats();
      await controller.send(500);

      expect(controller.status, SendStatus.failure);
      expect(controller.message, contains('only 12 left'));
      // A refusal is final -- nothing moved, so the next attempt is a new intent
      // and must not reuse this key.
      expect(controller.pendingKey, isNull);
    });

    test('uses a fresh key for each successful send', () async {
      final keysSeen = <String>[];
      final controller = _controllerWith((request) async {
        if (request.method == 'GET') return http.Response(_catsJson, 200);
        keysSeen.add(request.headers['X-Idempotency-Key']!);
        return http.Response(
          jsonEncode({'id': 't', 'amount': 5, 'senderBalanceAfter': 95}),
          201,
        );
      });

      await controller.loadCats();
      await controller.send(5);
      await controller.send(5);

      expect(keysSeen, hasLength(2));
      expect(keysSeen[0], isNot(keysSeen[1]));
    });
  });

  group('selection rules', () {
    test('clears a recipient that becomes the sender', () async {
      final controller = _controllerWith(
        (_) async => http.Response(_catsJson, 200),
      );
      await controller.loadCats();

      expect(controller.recipient!.name, 'Mittens');
      controller.selectSender(controller.cats[1]); // Mittens

      // A cat cannot send to itself, so the now-invalid recipient is dropped
      // rather than left for the server to reject.
      expect(controller.sender!.name, 'Mittens');
      expect(controller.recipient, isNull);
    });
  });
}

/// Stands in for a transport-level failure. The real type differs between the VM
/// and the browser, so the client treats any thrown transport error alike.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
