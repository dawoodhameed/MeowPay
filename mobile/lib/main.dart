import 'package:flutter/material.dart';

import 'api/meowpay_api.dart';
import 'screens/send_treats_screen.dart';
import 'state/send_controller.dart';

void main() => runApp(const MeowPayApp());

class MeowPayApp extends StatefulWidget {
  const MeowPayApp({super.key});

  @override
  State<MeowPayApp> createState() => _MeowPayAppState();
}

class _MeowPayAppState extends State<MeowPayApp> {
  late final MeowPayApi _api = MeowPayApi();
  late final SendController _controller = SendController(api: _api);

  @override
  void dispose() {
    _controller.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeowPay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08090C),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3DDC97),
          brightness: Brightness.dark,
        ),
      ),
      home: SendTreatsScreen(controller: _controller),
    );
  }
}
