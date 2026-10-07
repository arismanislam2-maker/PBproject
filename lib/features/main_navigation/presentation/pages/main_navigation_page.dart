import 'package:flutter/material.dart';

import '../../../home/presentation/pages/home_page.dart';
import '../../../account/presentation/pages/account_list_page.dart';
import '../../../report/presentation/pages/income_report_page.dart';
import '../../../report/presentation/pages/expense_report_page.dart';
import '../../../ai/presentation/pages/ai_account_chat_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() =>
      _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const AccountListPage(),
    const AiAccountChatPage(),
    const IncomeReportPage(),
    const ExpenseReportPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,

        selectedItemColor: const Color(0xFF5A3A28),
        unselectedItemColor: const Color(0xFF9A928B),

        selectedFontSize: 10,
        unselectedFontSize: 10,

        backgroundColor: Colors.white,

        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'หน้าแรก',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'บัญชี',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: Icon(Icons.auto_awesome_rounded),
            label: 'ถาม AI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.arrow_downward_rounded),
            label: 'สรุปรายรับ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.arrow_upward_rounded),
            label: 'สรุปรายจ่าย',
          ),
        ],
      ),
    );
  }
}
