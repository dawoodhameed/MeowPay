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
  {"id":"c1","name":"Whiskers","accountNumber":"10000001","avatarUrl":null,"walletId":"w1","balance":100},
  {"id":"c2","name":"Mittens","accountNumber":"10000002","avatarUrl":null,"walletId":"w2","balance":50}
]
''';

const _mittensJson =
    '{"id":"c2","name":"Mittens","accountNumber":"10000002","avatarUrl":null,"walletId":"w2","balance":50}';

/// Signs in as Whiskers and resolves Mittens as the payee, which is the state every
/// send starts from.
Future<void> _readyToSend(SendController c) async {
  await c.loadCats();
  c.signIn(c.cats.first);
  await c.lookUpPayee('10000002');
}

SendController _controllerWith(
  Future<http.Response> Function(http.Request) handler,
) =>
    SendController(
      api: MeowPayApi(client: _client(handler: handler), baseUrl: ''),
    );

void main() {
  group('loading cats', () {
    test('loads cats without signing anyone in', () async {
      final controller = _controllerWith(
        (_) async => http.Response(_catsJson, 200),
      );

      await controller.loadCats();

      expect(controller.cats, hasLength(2));
      expect(controller.cats.first.accountNumber, '10000001');
      // Identity is chosen on the sign-in screen, never assumed.
      expect(controller.isSignedIn, isFalse);
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
      controller.signIn(controller.cats.first); // Whiskers, 100 treats
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

    test('rejects more than the signed-in cat holds', () {
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
        if (request.url.path.contains('by-account')) {
          return http.Response(_mittensJson, 200);
        }
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

      await _readyToSend(controller);
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
        if (request.url.path.contains('by-account')) {
          return http.Response(_mittensJson, 200);
        }
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

      await _readyToSend(controller);
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
        if (request.url.path.contains('by-account')) {
          return http.Response(_mittensJson, 200);
        }
        if (request.method == 'GET') return http.Response(_catsJson, 200);
        keysSeen.add(request.headers['X-Idempotency-Key']!);
        return http.Response(
          jsonEncode({'id': 't', 'amount': 5, 'senderBalanceAfter': 95}),
          201,
        );
      });

      await _readyToSend(controller);
      await controller.send(5);
      await _readyToSend(controller);
      await controller.send(5);

      expect(keysSeen, hasLength(2));
      expect(keysSeen[0], isNot(keysSeen[1]));
    });
  });

  group('payee lookup', () {
    test('resolves an account number to a payee and advances the step', () async {
      final controller = _controllerWith((request) async {
        if (request.url.path.contains('by-account')) {
          return http.Response(_mittensJson, 200);
        }
        return http.Response(_catsJson, 200);
      });
      await controller.loadCats();
      controller.signIn(controller.cats.first);

      await controller.lookUpPayee('10000002');

      // Naming the payee before an amount is entered is what makes a mistyped
      // digit cheap to catch.
      expect(controller.payee!.name, 'Mittens');
      expect(controller.step, SendStep.enterAmount);
      expect(controller.lookupError, isNull);
    });

    test('rejects an account number that is not eight digits', () async {
      final controller = _controllerWith((_) async => http.Response(_catsJson, 200));
      await controller.loadCats();
      controller.signIn(controller.cats.first);

      await controller.lookUpPayee('123');

      expect(controller.lookupError, 'Account numbers are 8 digits');
      expect(controller.step, SendStep.enterPayee);
    });

    test('refuses your own account before making a request', () async {
      var requests = 0;
      final controller = _controllerWith((request) async {
        if (request.url.path.contains('by-account')) requests++;
        return http.Response(_catsJson, 200);
      });
      await controller.loadCats();
      controller.signIn(controller.cats.first); // Whiskers, 10000001

      await controller.lookUpPayee('10000001');

      expect(controller.lookupError, 'That is your own account');
      expect(requests, 0);
    });

    test('surfaces an unknown account number', () async {
      final controller = _controllerWith((request) async {
        if (request.url.path.contains('by-account')) {
          return http.Response(
            jsonEncode({
              'type': 'https://meowpay.co/problems/account-not-found',
              'title': 'No cat with that account number',
            }),
            404,
          );
        }
        return http.Response(_catsJson, 200);
      });
      await controller.loadCats();
      controller.signIn(controller.cats.first);

      await controller.lookUpPayee('99999999');

      expect(controller.lookupError, 'No cat has that account number.');
      expect(controller.step, SendStep.enterPayee);
    });
  });

  group('sign in', () {
    test('signing out clears the payee and any pending key', () async {
      final controller = _controllerWith((request) async {
        if (request.url.path.contains('by-account')) {
          return http.Response(_mittensJson, 200);
        }
        return http.Response(_catsJson, 200);
      });
      await _readyToSend(controller);
      expect(controller.payee, isNotNull);

      controller.signOut();

      expect(controller.isSignedIn, isFalse);
      expect(controller.payee, isNull);
      expect(controller.step, SendStep.enterPayee);
    });
  });
}

/// Stands in for a transport-level failure. The real type differs between the VM
/// and the browser, so the client treats any thrown transport error alike.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
