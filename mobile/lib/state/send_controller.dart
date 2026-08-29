import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/meowpay_api.dart';
import '../api/models.dart';

enum SendStatus { idle, loading, success, failure }

class SendController extends ChangeNotifier {
  SendController({required MeowPayApi api, Uuid? uuid})
      : _api = api,
        _uuid = uuid ?? const Uuid();

  final MeowPayApi _api;
  final Uuid _uuid;

  List<Cat> cats = const [];
  Cat? sender;
  Cat? recipient;

  SendStatus status = SendStatus.idle;
  String? message;
  bool loadingCats = true;
  String? loadError;

  /// The key for the transfer the user is currently trying to make.
  ///
  /// Held across retries on purpose. If the first attempt times out, the server
  /// may have committed it -- the response is what went missing, not necessarily
  /// the transfer. Retrying with the same key lets the server recognise the
  /// duplicate and replay the original instead of moving treats twice. Generating
  /// a fresh key per attempt would turn one intent into several transfers, which
  /// is the exact bug idempotency keys exist to prevent.
  ///
  /// Cleared once the outcome is known: on success, and on a business rejection
  /// (which is final -- the ledger did not change and the next attempt is a new
  /// intent).
  String? _pendingKey;

  @visibleForTesting
  String? get pendingKey => _pendingKey;

  Future<void> loadCats() async {
    loadingCats = true;
    loadError = null;
    notifyListeners();

    try {
      cats = await _api.listCats();
      // Keep the current selections pointed at fresh objects so balances update,
      // rather than resetting the form under the user on every refresh.
      sender = _reselect(sender) ?? (cats.isNotEmpty ? cats.first : null);
      recipient = _reselect(recipient) ??
          cats.cast<Cat?>().firstWhere(
                (cat) => cat!.id != sender?.id,
                orElse: () => null,
              );
      loadError = null;
    } on NetworkFailure {
      loadError = 'Cannot reach MeowPay. Check the backend is running.';
    } on ApiProblem catch (e) {
      loadError = e.userMessage;
    } finally {
      loadingCats = false;
      notifyListeners();
    }
  }

  Cat? _reselect(Cat? previous) {
    if (previous == null) return null;
    for (final cat in cats) {
      if (cat.id == previous.id) return cat;
    }
    return null;
  }

  void selectSender(Cat cat) {
    sender = cat;
    // A cat cannot send to itself, so clear a recipient that just became invalid
    // rather than letting the user submit a request the server will refuse.
    if (recipient?.id == cat.id) recipient = null;
    _clearResult();
    notifyListeners();
  }

  void selectRecipient(Cat cat) {
    recipient = cat;
    _clearResult();
    notifyListeners();
  }

  /// Validates the typed amount, returning an error message or null.
  String? validateAmount(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) return 'Enter an amount';

    // int.tryParse rejects decimals and anything non-numeric, which is what keeps
    // a fractional treat from ever being submitted.
    final amount = int.tryParse(trimmed);
    if (amount == null) return 'Whole numbers only';
    if (amount <= 0) return 'Must be more than zero';
    if (sender != null && amount > sender!.balance) {
      return 'Only ${sender!.balance} treats available';
    }
    return null;
  }

  Future<void> send(int amount) async {
    final from = sender;
    final to = recipient;
    if (from == null || to == null) return;

    status = SendStatus.loading;
    message = null;
    notifyListeners();

    // Reuse the pending key if this is a retry of the same intent.
    final key = _pendingKey ??= _uuid.v4();

    try {
      final transfer = await _api.sendTreats(
        senderWalletId: from.walletId,
        recipientWalletId: to.walletId,
        amount: amount,
        idempotencyKey: key,
      );

      _pendingKey = null;
      status = SendStatus.success;
      message = 'Sent ${transfer.amount} treats to ${to.name}. '
          '${transfer.senderBalanceAfter} left.';
      await loadCats();
    } on ApiProblem catch (e) {
      // The ledger considered the request and refused it. Nothing moved, and the
      // next attempt is a new intent, so the key is retired.
      _pendingKey = null;
      status = SendStatus.failure;
      message = e.userMessage;
    } on NetworkFailure {
      // The outcome is genuinely unknown. Keep the key so a retry is recognised
      // as the same transfer rather than becoming a second one.
      status = SendStatus.failure;
      message = 'Could not reach MeowPay. Retrying is safe.';
    } finally {
      notifyListeners();
    }
  }

  void _clearResult() {
    status = SendStatus.idle;
    message = null;
  }

  void dismissMessage() {
    _clearResult();
    notifyListeners();
  }
}
