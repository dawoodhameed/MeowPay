import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'models.dart';

/// Where the ledger API lives.
///
/// On the web build the app is served by nginx, which proxies `/api` to the
/// backend, so a relative path avoids a cross-origin request and the backend
/// needs no CORS policy. A native build has no such proxy and talks to the host
/// directly. Both can be overridden at build time:
///
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
///
/// which is what an Android emulator needs, since localhost there is the emulator
/// itself rather than the machine running the backend.
String get _defaultBaseUrl {
  const override = String.fromEnvironment('API_BASE_URL');
  if (override.isNotEmpty) return override;
  return kIsWeb ? '' : 'http://localhost:8080';
}

class MeowPayApi {
  MeowPayApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _defaultBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<List<Cat>> listCats() async {
    final response = await _send(() => _client.get(
          Uri.parse('$_baseUrl/api/v1/cats'),
          headers: const {'Accept': 'application/json'},
        ));

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => Cat.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Resolves an account number to the cat that holds it.
  ///
  /// Server-side rather than a filter over the already-loaded list: matching
  /// locally only works while every account is on the device, which stops being
  /// true past a demo.
  Future<Cat> lookupAccount(String accountNumber) async {
    final response = await _send(() => _client.get(
          Uri.parse('$_baseUrl/api/v1/cats/by-account/$accountNumber'),
          headers: const {'Accept': 'application/json'},
        ));
    return Cat.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Sends treats.
  ///
  /// [idempotencyKey] is supplied by the caller rather than generated here, and
  /// that is the whole point: it must identify the user's *intent*, so a retry
  /// after a timeout carries the key the first attempt used. Generating one per
  /// call would make every retry a second transfer.
  Future<Transfer> sendTreats({
    required String senderWalletId,
    required String recipientWalletId,
    required int amount,
    required String idempotencyKey,
  }) async {
    final response = await _send(() => _client.post(
          Uri.parse('$_baseUrl/api/v1/transfers'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-Idempotency-Key': idempotencyKey,
          },
          body: jsonEncode({
            'senderWalletId': senderWalletId,
            'recipientWalletId': recipientWalletId,
            'amount': amount,
          }),
        ));

    return Transfer.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Runs a request, turning transport failures into [NetworkFailure] and error
  /// responses into [ApiProblem].
  ///
  /// Keeping the two apart matters more here than in most clients: a refused
  /// transfer is final, while an unreachable server may have applied the transfer
  /// anyway and is the one case worth retrying with the same key.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 10));
    } catch (e) {
      throw NetworkFailure(e);
    }

    if (response.statusCode >= 400) {
      try {
        throw ApiProblem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      } on FormatException {
        // Not a problem document -- a proxy error page, say. Report it as a
        // failure rather than letting a JSON error surface as a crash.
        throw ApiProblem(
          type: 'unexpected-response',
          title: 'Unexpected response (${response.statusCode})',
        );
      }
    }

    return response;
  }

  void dispose() => _client.close();
}
