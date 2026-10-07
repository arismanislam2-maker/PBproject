import 'package:flutter/material.dart';
import 'transaction_report_page.dart';

class ExpenseReportPage extends StatelessWidget {
  const ExpenseReportPage({super.key});

  @override
  Widget build(BuildContext context) => const TransactionReportPage(isIncome: false);
}
