import 'package:flutter/material.dart';
import '../../../../shared/models/transaction_item.dart';
import '../../../../shared/widgets/transaction_success_page.dart';

class AddTransactionPage extends StatefulWidget {
  final bool isIncome;
  final Future<void> Function(TransactionItem) onAdd;

  const AddTransactionPage({
    super.key,
    required this.isIncome,
    required this.onAdd,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  static const brown = Color(0xFF5A3A28);
  static const cream = Color(0xFFF8F4EE);
  static const green = Color(0xFF5E8065);
  static const red = Color(0xFFC45B5B);

  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  String _selectedCategory = '';

  final List<Map<String, dynamic>> _incomeCategories = [
    {
      'label': 'เงินเดือน',
      'icon': Icons.payments_rounded,
      'color': const Color(0xFF5E8065)
    },
    {
      'label': 'โบนัส',
      'icon': Icons.card_giftcard_rounded,
      'color': const Color(0xFFC97864)
    },
    {
      'label': 'โอนเงิน',
      'icon': Icons.swap_horiz_rounded,
      'color': const Color(0xFF5A8DA8)
    },
    {
      'label': 'ลงทุน',
      'icon': Icons.trending_up_rounded,
      'color': const Color(0xFF7A6EA0)
    },
    {
      'label': 'อื่นๆ',
      'icon': Icons.more_horiz_rounded,
      'color': const Color(0xFF9A928B)
    },
  ];

  final List<Map<String, dynamic>> _expenseCategories = [
    {
      'label': 'อาหาร',
      'icon': Icons.restaurant_rounded,
      'color': const Color(0xFFC97864)
    },
    {
      'label': 'ค่าน้ำมัน',
      'icon': Icons.local_gas_station_rounded,
      'color': const Color(0xFF8DAA6E)
    },
    {
      'label': 'ชำระบัตรเครดิต',
      'icon': Icons.credit_card_rounded,
      'color': const Color(0xFFC45B5B)
    },
    {
      'label': 'บันเทิง',
      'icon': Icons.movie_rounded,
      'color': const Color(0xFF5A8DA8)
    },
    {
      'label': 'ช้อปปิ้ง',
      'icon': Icons.shopping_bag_rounded,
      'color': const Color(0xFF7A6EA0)
    },
    {
      'label': 'สาธารณูปโภค',
      'icon': Icons.bolt_rounded,
      'color': const Color(0xFFD4A843)
    },
    {
      'label': 'อื่นๆ',
      'icon': Icons.more_horiz_rounded,
      'color': const Color(0xFF9A928B)
    },
  ];

  List<Map<String, dynamic>> get _categories =>
      widget.isIncome ? _incomeCategories : _expenseCategories;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _categories.first['label'] as String;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountText = _amountController.text.trim();
    final title = _titleController.text.trim();

    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกจำนวนเงิน')),
      );
      return;
    }

    final amount = double.tryParse(amountText.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('จำนวนเงินไม่ถูกต้อง')),
      );
      return;
    }

    final cat = _categories.firstWhere((c) => c['label'] == _selectedCategory);
    final now = DateTime.now();
    final months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];
    final dateStr = '${now.day} ${months[now.month - 1]} ${now.year + 543}';
    final icon = cat['icon'] as IconData;

    final item = TransactionItem(
      title: title.isEmpty ? _selectedCategory : title,
      date: dateStr,
      amount: amount,
      isIncome: widget.isIncome,
      iconCodePoint: icon.codePoint,
      transactionDate: now,
    );

    try {
      await widget.onAdd(item);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกรายการไม่สำเร็จ: $error')),
      );
      return;
    }

    // ── Show success screen ──
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionSuccessPage(
          isIncome: widget.isIncome,
          category: title.isEmpty ? _selectedCategory : title,
          amount: amount,
          date: dateStr,
        ),
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isIncome ? green : red;
    final label = widget.isIncome ? 'รายรับ' : 'รายจ่าย';

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: brown,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'เพิ่ม$label',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── จำนวนเงิน ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'จำนวนเงิน',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '฿',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: '0.00',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── หมวดหมู่ ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'หมวดหมู่',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _categories.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 2.2,
                    ),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat['label'];
                      final catColor = cat['color'] as Color;
                      return GestureDetector(
                        onTap: () => setState(
                            () => _selectedCategory = cat['label'] as String),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? catColor.withValues(alpha: 0.15)
                                : const Color(0xFFF7F5F1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? catColor : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                cat['icon'] as IconData,
                                size: 16,
                                color: isSelected
                                    ? catColor
                                    : const Color(0xFF9A928B),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    cat['label'] as String,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? catColor
                                          : const Color(0xFF77716C),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── หมายเหตุ ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'หมายเหตุ (ไม่บังคับ)',
                  hintStyle:
                      TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: Icon(
                    Icons.edit_note_rounded,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ── ปุ่มบันทึก ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'บันทึก$label',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
