import 'package:flutter/material.dart';

class TransactionSuccessPage extends StatefulWidget {
  final bool isIncome;
  final String category;
  final double amount;
  final String date;
  final String? accountLabel;
  final String? accountSub;

  const TransactionSuccessPage({
    super.key,
    required this.isIncome,
    required this.category,
    required this.amount,
    required this.date,
    this.accountLabel,
    this.accountSub,
  });

  @override
  State<TransactionSuccessPage> createState() => _TransactionSuccessPageState();
}

class _TransactionSuccessPageState extends State<TransactionSuccessPage>
    with SingleTickerProviderStateMixin {
  static const cream = Color(0xFFF8F4EE);
  static const brown = Color(0xFF5A3A28);
  static const green = Color(0xFF5E8065);
  static const dividerColor = Color(0xFFEBE6E0);
  static const mutedText = Color(0xFF9A928B);
  static const darkText = Color(0xFF38312C);

  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = widget.isIncome ? 'รายรับ' : 'รายจ่าย';

    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Animated Checkmark ──
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: green.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Title ──
              FadeTransition(
                opacity: _fadeAnim,
                child: const Text(
                  'บันทึกรายการสำเร็จ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // ── Detail Card ──
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: dividerColor),
                  ),
                  child: Column(
                    children: [
                      // Row: ประเภท
                      _buildRow(typeLabel, widget.category),
                      _buildDivider(),

                      // Row: จำนวนเงิน
                      _buildRow(
                        'จำนวนเงิน',
                        '฿ ${_formatAmount(widget.amount)}',
                        trailing2: widget.date,
                        amountStyle: true,
                      ),
                      _buildDivider(),

                      // Row: บัญชี (ถ้ามี)
                      _buildRow(
                        'บัญชี',
                        widget.accountLabel ?? 'บัญชี',
                        trailing2: widget.accountSub ?? 'ยอดเงินที่มี',
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // ── Done Button ──
              FadeTransition(
                opacity: _fadeAnim,
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brown,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'เสร็จสิ้น',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, color: dividerColor, indent: 16, endIndent: 16);
  }

  Widget _buildRow(
    String label,
    String value, {
    String? trailing2,
    bool amountStyle = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: mutedText,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: amountStyle ? 18 : 15,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
              if (trailing2 != null)
                Text(
                  trailing2,
                  style: const TextStyle(
                    fontSize: 13,
                    color: mutedText,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
