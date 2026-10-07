import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Read-only receipt used when opening a previously saved transaction.
class TransactionSlipPage extends StatelessWidget {
  const TransactionSlipPage({
    super.key,
    required this.title,
    required this.amount,
    required this.date,
    required this.isIncome,
    this.category,
    this.account,
    this.note,
  });

  final String title;
  final double amount;
  final String date;
  final bool isIncome;
  final String? category;
  final String? account;
  final String? note;

  static const _brown = Color(0xFF5A3A28);
  static const _cream = Color(0xFFF8F4EE);
  static const _green = Color(0xFF5E8065);
  static const _red = Color(0xFFC45B5B);

  @override
  Widget build(BuildContext context) {
    final accent = isIncome ? _green : _red;
    final amountText = NumberFormat('#,##0.00').format(amount);

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        title: const Text('รายละเอียดรายการ'),
        centerTitle: true,
        backgroundColor: _cream,
        foregroundColor: _brown,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFECE7E1)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
                      color: accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${isIncome ? '+' : '-'}฿$amountText',
                    style: TextStyle(
                      color: accent,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isIncome ? 'รายรับ' : 'รายจ่าย',
                    style: const TextStyle(color: Color(0xFF8A817A)),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Color(0xFFECE7E1)),
                  _detailRow('รายการ', title),
                  _detailRow('หมวดหมู่', category?.trim().isNotEmpty == true ? category! : 'ไม่ระบุ'),
                  _detailRow('วันที่', date),
                  _detailRow('บัญชี', account?.trim().isNotEmpty == true ? account! : 'บัญชีของฉัน'),
                  if (note?.trim().isNotEmpty == true) _detailRow('หมายเหตุ', note!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(label, style: const TextStyle(color: Color(0xFF9A928B))),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Color(0xFF38312C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
