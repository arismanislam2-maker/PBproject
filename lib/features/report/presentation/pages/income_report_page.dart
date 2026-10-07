import 'package:flutter/material.dart';
import 'transaction_report_page.dart';

class IncomeReportPage extends StatelessWidget {
  const IncomeReportPage({super.key});

  @override
  Widget build(BuildContext context) => const TransactionReportPage(isIncome: true);
}
