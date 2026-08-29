import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/send_controller.dart';
import '../theme.dart';
import '../widgets/cat_avatar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final SendController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _accountController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  SendController get _c => widget.controller;

  @override
  void dispose() {
    _accountController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    await _c.lookUpPayee(_accountController.text);
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _c.send(int.parse(_amountController.text.trim()));
    if (_c.status == SendStatus.success) {
      _amountController.clear();
      _accountController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _c.signedInAs!;
    final index = _c.cats.indexWhere((cat) => cat.id == me.id);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CatAvatar(name: me.name, colorIndex: index < 0 ? 0 : index, size: 30),
            const SizedBox(width: 10),
            Text(
              me.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _c.signOut,
            style: TextButton.styleFrom(foregroundColor: MeowColors.muted),
            child: const Text('Switch'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _c.loadCats,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              _BalanceCard(balance: me.balance, accountNumber: me.accountNumber),
              const SizedBox(height: 26),
              if (_c.step == SendStep.enterPayee) ..._payeeStep() else ..._amountStep(),
              if (_c.message != null) ...[
                const SizedBox(height: 20),
                _ResultBanner(
                  message: _c.message!,
                  success: _c.status == SendStatus.success,
                  onDismiss: _c.dismissMessage,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _payeeStep() => [
        const Text('SEND TO', style: meowLabel),
        const SizedBox(height: 10),
        TextField(
          controller: _accountController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          onSubmitted: (_) => _continue(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: MeowColors.navy,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            hintText: '1000 0002',
            hintStyle: const TextStyle(
              color: Color(0xFFC3C9CD),
              fontSize: 22,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
            helperText: _c.lookupError == null ? 'Account number, 8 digits' : null,
            helperStyle: const TextStyle(color: MeowColors.muted, fontSize: 12),
            errorText: _c.lookupError,
            filled: true,
            fillColor: MeowColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: _border(MeowColors.line),
            enabledBorder: _border(MeowColors.line),
            focusedBorder: _border(MeowColors.coral),
            errorBorder: _border(MeowColors.coralInk),
            focusedErrorBorder: _border(MeowColors.coralInk),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _c.lookingUp ? null : _continue,
          child: _c.lookingUp
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
              : const Text('Continue'),
        ),
      ];

  List<Widget> _amountStep() {
    final payee = _c.payee!;
    return [
      // Confirming the payee by name before any amount is entered is the point of
      // splitting these steps: a mistyped digit is caught here, for free.
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MeowColors.blush,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CatAvatar(name: payee.name, colorIndex: 0, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SENDING TO', style: meowLabel),
                  const SizedBox(height: 3),
                  Text(
                    payee.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MeowColors.navy,
                    ),
                  ),
                  Text(
                    formatAccountNumber(payee.accountNumber),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: MeowColors.slate,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _c.changePayee,
              style: TextButton.styleFrom(foregroundColor: MeowColors.coralInk),
              child: const Text('Change'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      const Text('AMOUNT', style: meowLabel),
      const SizedBox(height: 10),
      Form(
        key: _formKey,
        child: TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _c.validateAmount,
          onFieldSubmitted: (_) => _send(),
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: MeowColors.navy,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: const TextStyle(color: Color(0xFFC3C9CD), fontSize: 30),
            suffixText: 'treats',
            suffixStyle: const TextStyle(color: MeowColors.muted, fontSize: 13),
            filled: true,
            fillColor: MeowColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: _border(MeowColors.line),
            enabledBorder: _border(MeowColors.line),
            focusedBorder: _border(MeowColors.coral),
            errorBorder: _border(MeowColors.coralInk),
            focusedErrorBorder: _border(MeowColors.coralInk),
            errorStyle: const TextStyle(color: MeowColors.coralInk, fontSize: 12),
          ),
        ),
      ),
      const SizedBox(height: 18),
      FilledButton(
        onPressed: _c.status == SendStatus.loading ? null : _send,
        child: _c.status == SendStatus.loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              )
            : Text('Send to ${payee.name}'),
      ),
    ];
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: 1.4),
      );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.accountNumber});

  final int balance;
  final String accountNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [MeowColors.coral, Color(0xFFFF9B85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AVAILABLE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$balance',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: Colors.white,
                    height: 1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const TextSpan(
                  text: '  treats',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // The sender's own account number, shown so it can be read out to whoever
          // is paying them -- the other half of a transfer flow built on numbers.
          Row(
            children: [
              const Text(
                'YOUR ACCOUNT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatAccountNumber(accountNumber),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.2,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.message,
    required this.success,
    required this.onDismiss,
  });

  final String message;
  final bool success;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = success ? MeowColors.positive : MeowColors.coralInk;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: success ? const Color(0xFFEAF7F1) : MeowColors.blush,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              color: color,
              size: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13.5, color: MeowColors.navy),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 17),
              color: MeowColors.muted,
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }
}
