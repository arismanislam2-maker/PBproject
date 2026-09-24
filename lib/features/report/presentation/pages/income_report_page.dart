import 'package:flutter/material.dart';

class IncomeReportPage extends StatelessWidget {
  const IncomeReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายรับ'),
      ),
      body: const Center(
        child: Text('รายการรายรับ'),
      ),
    );
  }
}