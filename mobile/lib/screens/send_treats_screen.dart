import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/send_controller.dart';
import '../widgets/cat_avatar.dart';
import '../widgets/cat_picker.dart';

class SendTreatsScreen extends StatefulWidget {
  const SendTreatsScreen({super.key, required this.controller});

  final SendController controller;

  @override
  State<SendTreatsScreen> createState() => _SendTreatsScreenState();
}

class _SendTreatsScreenState extends State<SendTreatsScreen> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  SendController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _controller.loadCats();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _amountController.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    if (_controller.status == SendStatus.success) _amountController.clear();
  }

  Future<void> _submit() async {
    // Dismissing the keyboard first stops the result banner appearing behind it.
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _controller.send(int.parse(_amountController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final sender = c.sender;
    final canSend = sender != null &&
        c.recipient != null &&
        c.status != SendStatus.loading;

    return Scaffold(
      backgroundColor: const Color(0xFF08090C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF08090C),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'MeowPay',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: c.loadCats,
          child: c.loadingCats && c.cats.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  // Always scrollable, so pull-to-refresh still works when the
                  // content is shorter than the screen -- including on the error
                  // state, which is exactly when someone will try to refresh.
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    if (c.loadError != null)
                      _ErrorPanel(message: c.loadError!, onRetry: c.loadCats)
                    else ...[
                      _BalanceCard(controller: c),
                      const SizedBox(height: 28),
                      _Label('Sending from'),
                      const SizedBox(height: 10),
                      CatPicker(
                        cats: c.cats,
                        selected: sender,
                        onSelect: c.selectSender,
                      ),
                      const SizedBox(height: 24),
                      _Label('To'),
                      const SizedBox(height: 10),
                      CatPicker(
                        cats: c.cats,
                        selected: c.recipient,
                        disabledId: sender?.id,
                        showBalance: false,
                        onSelect: c.selectRecipient,
                      ),
                      const SizedBox(height: 24),
                      _Label('Amount'),
                      const SizedBox(height: 10),
                      Form(key: _formKey, child: _amountField(c)),
                      const SizedBox(height: 20),
                      _SendButton(
                        enabled: canSend,
                        loading: c.status == SendStatus.loading,
                        recipientName: c.recipient?.name,
                        onPressed: _submit,
                      ),
                      if (c.message != null) ...[
                        const SizedBox(height: 20),
                        _ResultBanner(
                          message: c.message!,
                          success: c.status == SendStatus.success,
                          onDismiss: c.dismissMessage,
                        ),
                      ],
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _amountField(SendController c) {
    return TextFormField(
      controller: _amountController,
      // Numeric keyboard with no decimal point: treats are whole units, so the
      // keyboard should not offer a character the ledger cannot accept.
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: c.validateAmount,
      onFieldSubmitted: (_) => _submit(),
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Color(0xFFECEEF2),
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: const TextStyle(color: Color(0xFF3A414F), fontSize: 24),
        suffixText: 'treats',
        suffixStyle: const TextStyle(color: Color(0xFF6F7889), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF12151B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _border(const Color(0xFF1E222B)),
        enabledBorder: _border(const Color(0xFF1E222B)),
        focusedBorder: _border(const Color(0xFF3DDC97)),
        errorBorder: _border(const Color(0xFFFF8B6B)),
        focusedErrorBorder: _border(const Color(0xFFFF8B6B)),
        errorStyle: const TextStyle(color: Color(0xFFFF8B6B), fontSize: 12),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color),
      );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.controller});
  final SendController controller;

  @override
  Widget build(BuildContext context) {
    final sender = controller.sender;
    if (sender == null) return const SizedBox.shrink();
    final index = controller.cats.indexWhere((cat) => cat.id == sender.id);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF12151B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E222B)),
      ),
      child: Row(
        children: [
          CatAvatar(name: sender.name, colorIndex: index < 0 ? 0 : index, size: 44),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sender.name,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6F7889)),
              ),
              const SizedBox(height: 3),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${sender.balance}',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFECEEF2),
                        height: 1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const TextSpan(
                      text: '  treats',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6F7889)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.loading,
    required this.recipientName,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final String? recipientName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF3DDC97),
          foregroundColor: const Color(0xFF06231A),
          disabledBackgroundColor: const Color(0xFF1A1E26),
          disabledForegroundColor: const Color(0xFF4B5464),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Color(0xFF06231A),
                ),
              )
            // Naming the recipient makes the button state the consequence rather
            // than just the action.
            : Text(recipientName == null ? 'Send treats' : 'Send to $recipientName'),
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
    final color = success ? const Color(0xFF3DDC97) : const Color(0xFFFF8B6B);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
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
                style: const TextStyle(fontSize: 13.5, color: Color(0xFFECEEF2)),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 17),
              color: const Color(0xFF6F7889),
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8B6B).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF8B6B).withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFFECEEF2)),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFECEEF2),
              side: const BorderSide(color: Color(0xFF1E222B)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 0.9,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6F7889),
        ),
      );
}
