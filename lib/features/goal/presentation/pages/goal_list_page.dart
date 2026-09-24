import 'package:flutter/material.dart';

class GoalListPage extends StatelessWidget {
  GoalListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เป้าหมายออมเงิน'),
      ),
      body: const Center(
        child: Text(
          'รายการเป้าหมายออมเงิน',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}