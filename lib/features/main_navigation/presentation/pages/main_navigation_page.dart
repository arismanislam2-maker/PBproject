import 'package:flutter/material.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../account/presentation/pages/account_list_page.dart';
import '../../../report/presentation/pages/income_report_page.dart';
import '../../../report/presentation/pages/expense_report_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const AccountListPage(),
    const IncomeReportPage(),
    const ExpenseReportPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'หน้าหลัก',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'บัญชี',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            activeIcon: Icon(Icons.trending_up),
            label: 'สรุปรายรับ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_down),
            activeIcon: Icon(Icons.trending_down),
            label: 'สรุปรายจ่าย',
          ),
        ],
      ),
    );
  }
}