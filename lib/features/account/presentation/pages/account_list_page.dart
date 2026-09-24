import 'package:flutter/material.dart';

class AccountListPage extends StatelessWidget {
  const AccountListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('บัญชี'),
      ),
      body: const Center(
        child: Text(
          'รายการบัญชี',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}