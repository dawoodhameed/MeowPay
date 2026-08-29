import 'package:flutter/material.dart';

import 'api/meowpay_api.dart';
import 'screens/home_screen.dart';
import 'screens/sign_in_screen.dart';
import 'state/send_controller.dart';
import 'theme.dart';

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
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _controller.loadCats();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    _api.dispose();
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeowPay',
      debugShowCheckedModeBanner: false,
      theme: meowTheme(),
      home: _controller.isSignedIn
          ? HomeScreen(controller: _controller)
          : SignInScreen(controller: _controller),
    );
  }
}
