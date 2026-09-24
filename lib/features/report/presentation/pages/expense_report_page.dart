import 'package:flutter/material.dart';

class ExpenseReportPage extends StatelessWidget {
  const ExpenseReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายจ่าย'),
      ),
      body: const Center(
        child: Text('รายการรายจ่าย'),
      ),
    );
  }
}