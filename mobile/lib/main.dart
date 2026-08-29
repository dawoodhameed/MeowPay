import 'package:flutter/material.dart';

void main() => runApp(const MeowPayApp());

class MeowPayApp extends StatelessWidget {
  const MeowPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeowPay',
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
      home: const SendTreatsPage(),
    );
  }
}

class SendTreatsPage extends StatelessWidget {
  const SendTreatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MeowPay')),
      body: const Center(child: Text('Send treats')),
    );
  }
}
