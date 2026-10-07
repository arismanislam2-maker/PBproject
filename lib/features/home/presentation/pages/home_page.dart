import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/providers/transaction_provider.dart';
import '../../../account/presentation/pages/account_list_page.dart';
import '../../../goal/presentation/pages/goal_list_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../transaction/data/repositories/transaction_repository.dart';
import '../../../auth/data/services/session_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const brown = Color(0xFF5A3A28);
  static const cream = Color(0xFFF8F4EE);
  static const green = Color(0xFF5E8065);
  static const red = Color(0xFFC45B5B);

  final _transactionRepository = TransactionRepository();
  int? _balanceUserId;
  double? _databaseBalance;
  String? _balanceError;
  int _dataRevision = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = context.watch<UserProvider>();
    final userId = userProvider.user?.id;
    if (userId != _balanceUserId || userProvider.dataRevision != _dataRevision) {
      _balanceUserId = userId;
      _dataRevision = userProvider.dataRevision;
      _databaseBalance = userId == null ? 0 : null;
      _balanceError = null;
      if (userId != null) _loadDatabaseBalance(userId);
    }
  }

  Future<void> _loadDatabaseBalance(int userId) async {
    try {
      final balance = await _transactionRepository.getTotalBalance(userId);
      if (!mounted || userId != _balanceUserId) return;
      setState(() {
        _databaseBalance = balance;
        _balanceError = null;
      });
    } catch (error) {
      if (!mounted || userId != _balanceUserId) return;
      setState(() => _balanceError = 'โหลดข้อมูลยอดเงินไม่สำเร็จ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดข้อมูลยอดเงินไม่สำเร็จ: $error')),
      );
    }
  }

  Future<void> _openPage(BuildContext context, Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ออกจากระบบ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text('คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Color(0xFF77716C))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFC45B5B)),
            child: const Text('ออกจากระบบ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await SessionService.clearSession();
      if (!context.mounted) return;
      context.read<UserProvider>().clearUser();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Future<void> _resetFinancialData(BuildContext context) async {
    final userId = context.read<UserProvider>().user?.id;
    if (userId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('รีเซ็ตข้อมูลการเงินทั้งหมด?'),
        content: const Text(
          'รายการรับจ่าย เป้าหมาย บัญชี และหมวดหมู่ที่สร้างเองจะถูกลบ '
          'ระบบจะสร้างบัญชีเงินสดยอด 0 บาทให้ใหม่ ข้อมูลเข้าสู่ระบบและหมวดหมู่มาตรฐานจะยังอยู่',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: red),
            child: const Text('รีเซ็ตข้อมูล'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await DatabaseHelper.instance.resetUserFinancialData(userId);
      final preferences = await SharedPreferences.getInstance();
      final storedSessions = preferences.getString('ai_chat_sessions_$userId');
      if (storedSessions != null) {
        try {
          final sessions = jsonDecode(storedSessions) as List<dynamic>;
          for (final session in sessions.whereType<Map>()) {
            final sessionId = session['id']?.toString();
            if (sessionId != null) {
              await preferences.remove('ai_chat_messages_${userId}_$sessionId');
            }
          }
        } catch (_) {}
      }
      await preferences.remove('ai_chat_sessions_$userId');
      await preferences.remove('ai_chat_counter_$userId');
      await preferences.remove('ai_active_chat_$userId');
      await preferences.remove('ai_chat_history_$userId');
      if (!context.mounted) return;
      await context.read<TransactionProvider>().reloadForUser(userId);
      if (!context.mounted) return;
      context.read<UserProvider>().notifyDataReset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รีเซ็ตข้อมูลการเงินเรียบร้อยแล้ว')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('รีเซ็ตข้อมูลไม่สำเร็จ: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final displayName = user?.displayName ?? 'MyFinance';
    final avatarUrl = user?.avatarUrl;

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
                  GestureDetector(
                    onTap: () => _openPage(context, const ProfilePage()),
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.white24,
                      backgroundImage: avatarUrl != null ? FileImage(File(avatarUrl)) : null,
                      child: avatarUrl == null 
                          ? const Icon(Icons.person, color: Colors.white, size: 30)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _openPage(context, const ProfilePage()),
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.status.trim().isNotEmpty == true
                                ? user!.status
                                : 'วางแผนการเงิน... เพื่ออนาคตที่ดีกว่า',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip: 'รีเซ็ตข้อมูลการเงิน',
                    onPressed: () => _resetFinancialData(context),
                    icon: const Icon(Icons.restart_alt_rounded, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'ออกจากระบบ',
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 26),
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
                      child: _databaseBalance == null
                          ? SizedBox(
                              height: 158,
                              child: Center(
                                child: _balanceError == null
                                    ? const CircularProgressIndicator()
                                    : Text(_balanceError!),
                              ),
                            )
                          : _buildBalanceCard(context, _databaseBalance!),
                    ),

                    // Accounts
                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: _databaseBalance == null
                          ? const SizedBox.shrink()
                          : _buildAccounts(context, _databaseBalance!),
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

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  Widget _buildBalanceCard(BuildContext context, double balance) {
    final transactionProvider = context.watch<TransactionProvider>();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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

          Text(
            '฿${_formatAmount(balance)}',
            style: const TextStyle(
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
                  amount: '฿${_formatAmount(transactionProvider.totalIncome)}',
                  color: green,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _summary(
                  icon: Icons.arrow_upward_rounded,
                  title: 'รายจ่ายเดือนนี้',
                  amount: '฿${_formatAmount(transactionProvider.totalExpense)}',
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

  Widget _buildAccounts(BuildContext context, double balance) {
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
          title: 'ยอดเงินคงเหลือ',
          amount: '฿${_formatAmount(balance)}',
          subtitle: 'ยอดคงเหลือ',
          onTap: () {
            _openPage(context, const AccountListPage());
          },
        ),

        const SizedBox(height: 12),

        // ================= SAVING GOAL =================

        _accountCard(
          icon: Icons.track_changes_rounded,
          iconColor: const Color(0xFFC97864),
          title: 'เป้าหมายออมเงิน',
          amount: 'รายการเป้าหมายทั้งหมด',
          subtitle: '',
          onTap: () {
            _openPage(context, const GoalListPage());
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
                color: Colors.black.withValues(alpha: 0.04),
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
                  color: iconColor.withValues(alpha: 0.10),
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
