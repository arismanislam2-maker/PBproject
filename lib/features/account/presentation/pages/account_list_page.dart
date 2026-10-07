import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/models/transaction_item.dart';
import '../../../../shared/providers/transaction_provider.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../transaction/data/models/transaction_model.dart';
import '../../../transaction/data/repositories/transaction_repository.dart';
import '../../../transaction/presentation/pages/add_transaction_page.dart';
import '../../../../shared/widgets/transaction_slip_page.dart';
import '../../../ai/presentation/pages/ai_account_chat_page.dart';
class AccountListPage extends StatefulWidget {
  const AccountListPage({super.key});

  @override
  State<AccountListPage> createState() => _AccountListPageState();
}

class _AccountListPageState extends State<AccountListPage> {
  // ──────────────────────────── สีหลัก ────────────────────────────
  static const brown = Color(0xFF5A3A28);
  static const cream = Color(0xFFF8F4EE);
  static const green = Color(0xFF5E8065);
  static const red = Color(0xFFC45B5B);
  final TransactionRepository _transactionRepository = TransactionRepository();
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

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  // ──────────────────────────── เปิดหน้าเพิ่มรายการ ────────────────────────────
  Future<void> _openAddTransaction(bool isIncome) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionPage(
          isIncome: isIncome,
          onAdd: (TransactionItem item) async {
            final userId = context.read<UserProvider>().user?.id;
            if (userId == null) throw StateError('กรุณาเข้าสู่ระบบอีกครั้ง');
            final accountId = await _transactionRepository.getDefaultAccountId(userId);
            if (accountId == null) throw StateError('ไม่พบบัญชีเงินสด');
            final transactionId = await _transactionRepository.createTransaction(
              TransactionModel(
                userId: userId,
                fromAccountId: item.isIncome ? null : accountId,
                toAccountId: item.isIncome ? accountId : null,
                amount: item.amount,
                transactionType: item.isIncome ? 'INCOME' : 'EXPENSE',
                description: item.title,
                transactionDate: DateTime.now().toIso8601String(),
              ),
            );
            if (!mounted) return;
            context.read<TransactionProvider>().addTransaction(
              TransactionItem(
                id: transactionId,
                title: item.title,
                date: item.date,
                amount: item.amount,
                isIncome: item.isIncome,
                iconCodePoint: item.iconCodePoint,
                transactionDate: item.transactionDate,
              ),
            );
            context.read<UserProvider>().notifyDataChanged();
          },
        ),
      ),
    );
    if (saved != true || !mounted) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: brown,
          duration: const Duration(seconds: 5),
          content: Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiAccountChatPage()),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('AI สรุปบัญชี · แตะเพื่อถาม AI'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }

  // ──────────────────────────── ลบรายการ ────────────────────────────
  Future<void> _deleteTransaction(int index) async {
    final provider = context.read<TransactionProvider>();
    final transaction = provider.transactions[index];
    final userId = context.read<UserProvider>().user?.id;
    if (transaction.id == null || userId == null) return;
    try {
      await _transactionRepository.deleteTransaction(transaction.id!);
      if (!mounted) return;
      provider.removeTransaction(index);
      context.read<UserProvider>().notifyDataChanged();
    } catch (error) {
      if (!mounted) return;
      await provider.reloadForUser(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบรายการไม่สำเร็จ: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: brown,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'บัญชีของฉัน',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: _buildDepositTab(),
    );
  }

  Widget _buildDepositTab() {
    final transactionProvider = context.watch<TransactionProvider>();
    final transactions = transactionProvider.transactions;
    
    return Column(
      children: [
        // ── การ์ดยอดเงิน ──
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: brown.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  size: 26,
                  color: brown,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _databaseBalance == null
                          ? (_balanceError == null ? 'กำลังโหลด…' : 'โหลดไม่สำเร็จ')
                          : '฿ ${_formatAmount(_databaseBalance!)}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2F2925),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'ยอดคงเหลือ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9A928B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── หัวข้อรายการ ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'รายการล่าสุด (เดือนนี้)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4C4038),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.arrow_downward_rounded, size: 13, color: green),
                  const SizedBox(width: 2),
                  Text(
                    '฿${_formatAmount(transactionProvider.totalIncome)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_upward_rounded, size: 13, color: red),
                  const SizedBox(width: 2),
                  Text(
                    '฿${_formatAmount(transactionProvider.totalExpense)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── รายการธุรกรรม ──
        Expanded(
          child: transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'ยังไม่มีรายการ\nกดปุ่มด้านล่างเพื่อเพิ่มรายการ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _buildTransactionTile(transactions[index], index);
                  },
                ),
        ),

        // ── ปุ่มรายรับ / รายจ่าย ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          color: cream,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openAddTransaction(true),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'รายรับ',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openAddTransaction(false),
                  icon: const Icon(Icons.remove_rounded, size: 20),
                  label: const Text(
                    'รายจ่าย',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────── รายการธุรกรรม ────────────────────────────
  Widget _buildTransactionTile(TransactionItem t, int index) {
    final color = t.isIncome ? green : red;
    final sign = t.isIncome ? '+' : '-';

    // กำหนดสี icon ตาม codePoint
    final Map<int, Color> iconColors = {
      0xe4d7: green,                    // payments_rounded
      0xe56c: const Color(0xFFC97864),  // restaurant_rounded
      0xe3a3: const Color(0xFF8DAA6E),  // local_gas_station_rounded
      0xe62d: const Color(0xFF5A8DA8),  // swap_horiz_rounded
      0xe1ba: red,                      // credit_card_rounded
      0xe19f: const Color(0xFFC97864),  // card_giftcard_rounded
      0xe6db: const Color(0xFF7A6EA0),  // trending_up_rounded
      0xe40c: const Color(0xFF5A8DA8),  // movie_rounded
      0xf07b7: const Color(0xFF7A6EA0), // shopping_bag_rounded
      0xe145: const Color(0xFFD4A843),  // bolt_rounded
      0xe5d3: const Color(0xFF9A928B),  // more_horiz_rounded
    };

    final iconColor = iconColors[t.iconCodePoint] ?? (t.isIncome ? green : red);
    // ignore: prefer_const_constructors, non_const_argument_for_const_parameter
    final Widget iconWidget = Icon(
      // ignore: non_const_argument_for_const_parameter
      IconData(t.iconCodePoint, fontFamily: 'MaterialIcons'),
      size: 20,
      color: iconColor,
    );

    return Dismissible(
      key: ValueKey(t.id ?? '${t.title}_${t.date}_$index'),
      direction: t.id == null ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.delete_rounded, color: red, size: 26),
      ),
      onDismissed: (_) => _deleteTransaction(index),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionSlipPage(
                title: t.title,
                amount: t.amount,
                date: t.date,
                isIncome: t.isIncome,
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            // Icon วงกลม
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: iconWidget,
            ),

            const SizedBox(width: 12),

            // ชื่อ + วันที่
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF38312C),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    t.date,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9A928B),
                    ),
                  ),
                ],
              ),
            ),

            // จำนวนเงิน
            Text(
              '$sign ฿${_formatAmount(t.amount)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }
}
