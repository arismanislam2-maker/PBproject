import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../../../../shared/models/goal_model.dart';
import '../../../../shared/models/goal_transaction.dart';
import '../../../../shared/models/transaction_item.dart';
import '../../../../shared/providers/transaction_provider.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../data/repositories/goal_repository.dart';
import '../../../../shared/widgets/transaction_success_page.dart';
import '../../../../shared/widgets/month_year_selector.dart';
import '../../../../shared/widgets/transaction_slip_page.dart';

class GoalDetailPage extends StatefulWidget {
  final GoalModel goal;
  final void Function(GoalModel updatedGoal)? onGoalUpdated;

  const GoalDetailPage({
    super.key,
    required this.goal,
    this.onGoalUpdated,
  });

  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage> {
  static const brown = Color(0xFF5A3A28);
  static const cream = Color(0xFFF8F4EE);
  static const green = Color(0xFF5E8065);
  static const red = Color(0xFFC45B5B);

  late double _currentAmount;
  final List<GoalTransaction> _transactions = [];
  final GoalRepository _goalRepository = GoalRepository();
  late ConfettiController _confettiController;

  late int _selectedMonth;
  late int _selectedYear;

  final List<String> _months = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
  ];

  @override
  void initState() {
    super.initState();
    _currentAmount = widget.goal.currentAmount;
    // ตั้งค่าเดือน/ปีปัจจุบัน
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    if (_currentAmount >= widget.goal.targetAmount) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final monthTh = _months[(dt.month - 1) % 12];
    final year = (dt.year + 543).toString();
    return '$day $monthTh $year';
  }

  // ── Dialog กรอกจำนวนเงิน ──
  Future<void> _showAmountDialog(bool isIncome) async {
    final controller = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDD8D2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title
                  Text(
                    isIncome ? 'เงินเข้า' : 'ถอนออก',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isIncome ? green : red,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Amount field
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E2620),
                    ),
                    decoration: InputDecoration(
                      prefixText: '฿  ',
                      prefixStyle: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isIncome ? green : red,
                      ),
                      hintText: '0',
                      hintStyle: const TextStyle(
                        fontSize: 28,
                        color: Color(0xFFCCC7C2),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF7F4EF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'กรุณากรอกจำนวนเงิน';
                      final val = double.tryParse(v);
                      if (val == null || val <= 0) return 'จำนวนเงินต้องมากกว่า 0';
                      if (!isIncome && val > _currentAmount) {
                        return 'ยอดเงินไม่เพียงพอ (มี ${_formatAmount(_currentAmount)} บาท)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Note field (optional)
                  TextFormField(
                    controller: noteController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'หมายเหตุ (ไม่จำเป็น)',
                      hintStyle: const TextStyle(color: Color(0xFFADA9A4)),
                      filled: true,
                      fillColor: const Color(0xFFF7F4EF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Confirm button
                  ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(ctx, true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isIncome ? green : red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'ยืนยัน${isIncome ? 'เงินเข้า' : 'ถอนออก'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      if (!mounted) return;
      final amount = double.tryParse(controller.text) ?? 0;
      if (amount <= 0) return;

      final userId = context.read<UserProvider>().user?.id;
      final transactionProvider = context.read<TransactionProvider>();
      final goalId = int.tryParse(widget.goal.id);
      if (userId == null || goalId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบข้อมูลผู้ใช้หรือเป้าหมาย')),
          );
        }
        return;
      }

      double updatedAmount;
      try {
        updatedAmount = await _goalRepository.transferToGoal(
          userId: userId,
          goalId: goalId,
          amount: amount,
          deposit: isIncome,
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        );
        transactionProvider.reflectGoalTransfer(isIncome ? -amount : amount);
      } on StateError catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
        return;
      }

      if (!mounted) return;

      final now = DateTime.now();
      transactionProvider.addTransaction(
        TransactionItem(
          title: isIncome
              ? 'ถอนจากเป้าหมาย: ${widget.goal.title}'
              : 'เข้าเป้าหมาย: ${widget.goal.title}',
          date: _formatDate(now),
          amount: amount,
          isIncome: !isIncome,
          iconCodePoint: widget.goal.iconCodePoint,
          transactionDate: now,
          // ยอดคงเหลือถูกปรับแยกแล้ว ป้องกันหัก/บวกซ้ำ
          affectsBalance: false,
        ),
      );
      final tx = GoalTransaction(
        id: now.millisecondsSinceEpoch.toString(),
        amount: amount,
        isIncome: isIncome,
        date: _formatDate(now),
        createdAt: now,
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
      );

      setState(() {
        _transactions.insert(0, tx);
        _currentAmount = updatedAmount;
        if (isIncome) {
          if (_currentAmount >= widget.goal.targetAmount) {
             _confettiController.play();
          }
        }
      });

      // แจ้ง parent ให้อัปเดต GoalModel
      widget.onGoalUpdated?.call(
        widget.goal.copyWith(
          currentAmount: _currentAmount,
          isCompleted: _currentAmount >= widget.goal.targetAmount,
        ),
      );
      context.read<UserProvider>().notifyDataChanged();

      // ── Show success screen ──
      if (!mounted) return;
      final dateStr = _formatDate(now);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionSuccessPage(
            isIncome: isIncome,
            category: isIncome ? 'เงินเข้า' : 'ถอนออก',
            amount: amount,
            date: dateStr,
            accountLabel: widget.goal.title,
            accountSub: 'เป้าหมายออมเงิน',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = _currentAmount >= widget.goal.targetAmount;
    final createdAt = context.watch<UserProvider>().user?.createdAt ?? DateTime.now();
    final filteredTransactions = _transactions.where((tx) =>
      tx.createdAt.year == _selectedYear && tx.createdAt.month == _selectedMonth,
    ).toList();

    return Stack(
      children: [
        Scaffold(
          backgroundColor: cream,
          appBar: AppBar(
        backgroundColor: cream,
        foregroundColor: Colors.black,
        title: Text(
          widget.goal.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MonthYearSelector(
                      year: _selectedYear,
                      month: _selectedMonth,
                      firstYear: createdAt.year,
                      firstMonth: createdAt.month,
                      onChanged: (selected) => setState(() {
                        _selectedYear = selected.year;
                        _selectedMonth = selected.month;
                      }),
                    ),
                    const SizedBox(height: 16),

                    // ── Balance Card ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: brown,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: brown.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ยอดคงเหลือ',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatAmount(_currentAmount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Recent Transactions ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'รายการล่าสุด',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF77716C),
                          ),
                        ),
                        if (filteredTransactions.isNotEmpty)
                          Text(
                            '${filteredTransactions.length} รายการ',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9A928B),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── รายการจริง ──
                    if (filteredTransactions.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        alignment: Alignment.center,
                        child: const Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: Color(0xFFCCC7C2),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'ยังไม่มีรายการ\nกด + รายรับ หรือ - ถอนออก เพื่อเริ่มต้น',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFFADA9A4),
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...filteredTransactions.map((tx) => _buildTransactionItem(tx)),
                  ],
                ),
              ),
            ),

            // ── Bottom Action Buttons ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: cream,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'รายรับ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _showAmountDialog(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCompleted ? Colors.grey : red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.remove_rounded, size: 20),
                      label: const Text(
                        'ถอนออก',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: isCompleted ? null : () => _showAmountDialog(false),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    if (isCompleted)
      Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _confettiController,
          blastDirection: 3.14 / 2, // Straight down
          maxBlastForce: 5,
          minBlastForce: 2,
          emissionFrequency: 0.05,
          numberOfParticles: 20,
          gravity: 0.1,
        ),
      ),
  ],
);
}

  Widget _buildTransactionItem(GoalTransaction tx) {
    final color = tx.isIncome ? green : red;
    final sign = tx.isIncome ? '+' : '-';
    final iconData = tx.isIncome ? Icons.attach_money_rounded : Icons.money_off_rounded;
    final bgColor = tx.isIncome
        ? const Color(0xFFE8F2EA)
        : const Color(0xFFFDECEE);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionSlipPage(
            title: tx.note ?? (tx.isIncome ? 'เงินเข้าเป้าหมาย' : 'เงินออกจากเป้าหมาย'),
            category: widget.goal.title,
            amount: tx.amount,
            date: tx.date,
            isIncome: tx.isIncome,
            account: widget.goal.title,
            note: tx.note,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(iconData, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.isIncome ? 'เงินเข้า' : 'เงินออก',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF38312C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tx.note != null ? '${tx.note} • ${tx.date}' : tx.date,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9A928B)),
                ),
              ],
            ),
          ),
          Text(
            '$sign ${_formatAmount(tx.amount)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
        ),
      ),
    );
  }
}
