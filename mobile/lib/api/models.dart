/// A cat and the wallet it spends from.
class Cat {
  const Cat({
    required this.id,
    required this.name,
    required this.walletId,
    required this.balance,
  });

  final String id;
  final String name;
  final String walletId;
  final int balance;

  factory Cat.fromJson(Map<String, dynamic> json) => Cat(
        id: json['id'] as String,
        name: json['name'] as String,
        walletId: json['walletId'] as String,
        // Treats are whole units. Parsing as int rather than num keeps a
        // fractional value from silently entering the client.
        balance: json['balance'] as int,
      );
}

class Transfer {
  const Transfer({
    required this.id,
    required this.amount,
    required this.senderBalanceAfter,
  });

  final String id;
  final int amount;
  final int senderBalanceAfter;

  factory Transfer.fromJson(Map<String, dynamic> json) => Transfer(
        id: json['id'] as String,
        amount: json['amount'] as int,
        // The balance recorded when the transfer committed. Using it rather than
        // re-fetching means the UI shows the figure that belongs to *this*
        // transfer, not whatever the wallet holds by the time a second call lands.
        senderBalanceAfter: json['senderBalanceAfter'] as int,
      );
}

/// An RFC 9457 problem document.
///
/// [type] is the stable slug the UI branches on; [title] and [detail] are for
/// humans and may be reworded server-side at any time, so no logic reads them.
class ApiProblem implements Exception {
  const ApiProblem({
    required this.type,
    required this.title,
    this.detail,
    this.balance,
  });

  final String type;
  final String title;
  final String? detail;
  final int? balance;

  factory ApiProblem.fromJson(Map<String, dynamic> json) => ApiProblem(
        // The full type is a URI; the last segment is the slug.
        type: (json['type'] as String? ?? 'unknown').split('/').last,
        title: json['title'] as String? ?? 'Something went wrong',
        detail: json['detail'] as String?,
        balance: json['balance'] as int?,
      );

  /// Message written for the person holding the phone, not for a log.
  String get userMessage {
    switch (type) {
      case 'insufficient-funds':
        return balance != null
            ? 'Not enough treats — only $balance left.'
            : 'Not enough treats.';
      case 'self-transfer':
        return 'Pick a different cat to send treats to.';
      case 'amount-not-positive':
        return 'Enter an amount greater than zero.';
      case 'wallet-not-found':
        return 'That cat no longer exists. Pull to refresh.';
      case 'idempotency-key-reuse':
        return 'That transfer was already sent.';
      case 'lock-timeout':
        return 'The ledger is busy. Try again in a moment.';
      default:
        return title;
    }
  }

  @override
  String toString() => 'ApiProblem($type)';
}

/// The API could not be reached at all, which is different from the API refusing
/// the request. Only this case is safe to retry with the same idempotency key.
class NetworkFailure implements Exception {
  const NetworkFailure(this.cause);
  final Object cause;

  @override
  String toString() => 'NetworkFailure($cause)';
}
