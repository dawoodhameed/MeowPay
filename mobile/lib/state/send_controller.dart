import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/meowpay_api.dart';
import '../api/models.dart';

enum SendStatus { idle, loading, success, failure }

/// How far through the send the user is.
///
/// Entering a payee and entering an amount are separate steps on purpose: it puts
/// a confirmation of *who* is being paid between typing an account number and
/// committing money to it, which is where a mistyped digit is still free to catch.
enum SendStep { enterPayee, enterAmount }

class SendController extends ChangeNotifier {
  SendController({required MeowPayApi api, Uuid? uuid})
      : _api = api,
        _uuid = uuid ?? const Uuid();

  final MeowPayApi _api;
  final Uuid _uuid;

  List<Cat> cats = const [];
  Cat? signedInAs;
  Cat? payee;

  SendStep step = SendStep.enterPayee;
  SendStatus status = SendStatus.idle;
  String? message;
  bool loadingCats = true;
  String? loadError;
  bool lookingUp = false;
  String? lookupError;

  /// Held across retries: see [send].
  String? _pendingKey;

  @visibleForTesting
  String? get pendingKey => _pendingKey;

  bool get isSignedIn => signedInAs != null;

  Future<void> loadCats() async {
    loadingCats = true;
    loadError = null;
    notifyListeners();

    try {
      cats = await _api.listCats();
      // Keep the signed-in cat pointed at a fresh object so its balance updates
      // without signing the user out.
      if (signedInAs != null) {
        for (final cat in cats) {
          if (cat.id == signedInAs!.id) signedInAs = cat;
        }
      }
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

  void signIn(Cat cat) {
    signedInAs = cat;
    _resetSend();
    notifyListeners();
  }

  void signOut() {
    signedInAs = null;
    _resetSend();
    notifyListeners();
  }

  /// Looks the typed account number up and, if it resolves, moves to the amount step.
  Future<void> lookUpPayee(String accountNumber) async {
    final trimmed = accountNumber.replaceAll(' ', '').trim();
    lookupError = null;

    if (trimmed.length != 8) {
      lookupError = 'Account numbers are 8 digits';
      notifyListeners();
      return;
    }
    // Checked before the request: sending to yourself is refused by the ledger
    // anyway, but saying so immediately is clearer than a round trip to find out.
    if (trimmed == signedInAs?.accountNumber) {
      lookupError = 'That is your own account';
      notifyListeners();
      return;
    }

    lookingUp = true;
    notifyListeners();

    try {
      payee = await _api.lookupAccount(trimmed);
      step = SendStep.enterAmount;
      lookupError = null;
    } on ApiProblem catch (e) {
      lookupError = e.userMessage;
    } on NetworkFailure {
      lookupError = 'Cannot reach MeowPay right now.';
    } finally {
      lookingUp = false;
      notifyListeners();
    }
  }

  void changePayee() {
    payee = null;
    step = SendStep.enterPayee;
    _clearResult();
    notifyListeners();
  }

  String? validateAmount(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) return 'Enter an amount';

    // int.tryParse rejects decimals and anything non-numeric, which is what keeps
    // a fractional treat from ever being submitted.
    final amount = int.tryParse(trimmed);
    if (amount == null) return 'Whole numbers only';
    if (amount <= 0) return 'Must be more than zero';
    if (signedInAs != null && amount > signedInAs!.balance) {
      return 'Only ${signedInAs!.balance} treats available';
    }
    return null;
  }

  Future<void> send(int amount) async {
    final from = signedInAs;
    final to = payee;
    if (from == null || to == null) return;

    status = SendStatus.loading;
    message = null;
    notifyListeners();

    // Reused if this is a retry of the same intent -- see the catch blocks.
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
      step = SendStep.enterPayee;
      payee = null;
      await loadCats();
    } on ApiProblem catch (e) {
      // The ledger considered the request and refused it. Nothing moved, so the
      // next attempt is a new intent and the key is retired.
      _pendingKey = null;
      status = SendStatus.failure;
      message = e.userMessage;
    } on NetworkFailure {
      // The outcome is unknown -- the transfer may have committed and only the
      // response gone missing. Keeping the key means a retry is recognised as the
      // same transfer rather than becoming a second one.
      status = SendStatus.failure;
      message = 'Could not reach MeowPay. Retrying is safe.';
    } finally {
      notifyListeners();
    }
  }

  void _resetSend() {
    payee = null;
    step = SendStep.enterPayee;
    lookupError = null;
    _pendingKey = null;
    _clearResult();
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
