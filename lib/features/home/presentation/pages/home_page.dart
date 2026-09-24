import 'package:flutter/material.dart';

import '../../../account/presentation/pages/account_list_page.dart';
import '../../../goal/presentation/pages/goal_list_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const brown = Color(0xFF5A3A28);
  static const cream = Color(0xFFF8F4EE);
  static const green = Color(0xFF5E8065);
  static const red = Color(0xFFC45B5B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Column(
          children: [
            // ================= HEADER =================
            Container(
              height: 155,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              decoration: const BoxDecoration(
                color: brown,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MyFinance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'วางแผนการเงิน... เพื่ออนาคตที่ดีกว่า',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ยังไม่มีการแจ้งเตือน'),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.notifications_none_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

            // ================= CONTENT =================
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Balance Card
                    Transform.translate(
                      offset: const Offset(0, -42),
                      child: _buildBalanceCard(),
                    ),

                    // Accounts
                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: _buildAccounts(context),
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // BALANCE CARD
  // =====================================================

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ยอดเงินคงเหลือ',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF77716C),
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            '฿18,750.00',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2F2925),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _summary(
                  icon: Icons.arrow_downward_rounded,
                  title: 'รายรับเดือนนี้',
                  amount: '฿25,000.00',
                  color: green,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _summary(
                  icon: Icons.arrow_upward_rounded,
                  title: 'รายจ่ายเดือนนี้',
                  amount: '฿6,250.00',
                  color: red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // INCOME / EXPENSE SUMMARY
  // =====================================================

  Widget _summary({
    required IconData icon,
    required String title,
    required String amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5F1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 21,
            color: color,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF817A74),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // MY ACCOUNTS
  // =====================================================

  Widget _buildAccounts(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'บัญชีของฉัน',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4C4038),
          ),
        ),

        const SizedBox(height: 12),

        // ================= DEPOSIT =================

        _accountCard(
          icon: Icons.account_balance_rounded,
          iconColor: brown,
          title: 'ยอดเงินฝาก',
          amount: '฿18,750.00',
          subtitle: 'ยอดคงเหลือ',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AccountListPage(),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // ================= SAVING GOAL =================

        _accountCard(
          icon: Icons.track_changes_rounded,
          iconColor: const Color(0xFFC97864),
          title: 'เป้าหมายออมเงิน',
          amount: '฿5,000.00',
          subtitle: '',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GoalListPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  // =====================================================
  // ACCOUNT CARD
  // =====================================================

  Widget _accountCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String amount,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 76,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: iconColor,
                ),
              ),

              const SizedBox(width: 12),

              // Text
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF77716C),
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      amount,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38312C),
                      ),
                    ),

                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9A928B),
                        ),
                      ),
                  ],
                ),
              ),

              // Arrow
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9A928B),
                size: 25,
              ),
            ],
          ),
        ),
      ),
    );
  }
}