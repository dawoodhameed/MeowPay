import 'package:flutter/material.dart';

import '../state/send_controller.dart';
import '../theme.dart';
import '../widgets/cat_avatar.dart';

/// Stands in for authentication.
///
/// There is no auth in this slice, so this picks an identity rather than proving
/// one. It exists because everything after it -- a balance, an account number, a
/// payee -- only means something from *somebody's* point of view, and a picker
/// buried in a form does not establish that the way a sign-in screen does.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, required this.controller});

  final SendController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.loadCats,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
            children: [
              const Text('MeowPay', style: meowLabel),
              const SizedBox(height: 10),
              const Text('Who\'s paying?', style: meowHeadline),
              const SizedBox(height: 8),
              const Text(
                'Pick a cat to sign in as. No password — this is a demo ledger.',
                style: TextStyle(fontSize: 14, color: MeowColors.slate, height: 1.4),
              ),
              const SizedBox(height: 28),
              if (controller.loadingCats && controller.cats.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (controller.loadError != null)
                _LoadError(message: controller.loadError!, onRetry: controller.loadCats)
              else
                for (var i = 0; i < controller.cats.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CatRow(
                      cat: controller.cats[i],
                      colorIndex: i,
                      onTap: () => controller.signIn(controller.cats[i]),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatRow extends StatelessWidget {
  const _CatRow({required this.cat, required this.colorIndex, required this.onTap});

  final dynamic cat;
  final int colorIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MeowColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MeowColors.line),
          ),
          child: Row(
            children: [
              CatAvatar(name: cat.name, colorIndex: colorIndex, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.name,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: MeowColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatAccountNumber(cat.accountNumber),
                      style: const TextStyle(
                        fontSize: 13,
                        color: MeowColors.muted,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${cat.balance}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MeowColors.navy,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: MeowColors.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MeowColors.blush,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: MeowColors.navy),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: MeowColors.navy,
              side: const BorderSide(color: MeowColors.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
