import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/widgets/transaction_slip_page.dart';
import '../../../transaction/data/repositories/transaction_repository.dart';
import '../../data/monthly_report_pdf_service.dart';
import '../widgets/donut_chart.dart';

class TransactionReportPage extends StatefulWidget {
  final bool isIncome;
  const TransactionReportPage({super.key, required this.isIncome});

  @override
  State<TransactionReportPage> createState() => _TransactionReportPageState();
}

class _TransactionReportPageState extends State<TransactionReportPage> {
  static const _monthNames = ['มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'];
  static const _colors = [Color(0xFF4A7C59), Color(0xFF8C5338), Color(0xFFD89B52), Color(0xFF7D7571), Color(0xFF8B3A3A), Color(0xFF5A8DA8)];
  static const _brown = Color(0xFF5A3A28);
  static const _cream = Color(0xFFF8F4EE);
  final _repository = TransactionRepository();
  final _pdfService = MonthlyReportPdfService();
  late int _month;
  late int _year;
  int? _firstYear;
  int? _firstMonth;
  int? _reportUserId;
  int _dataRevision = -1;
  String? _selectedCategory;
  bool _userInitialized = false;
  Future<Map<String, dynamic>>? _report;
  bool _isLoading = true;
  bool _isExportingPdf = false;

  DateTime get _selectedMonth => DateTime(_year, _month);
  DateTime get _firstSelectableMonth =>
      DateTime(_firstYear ?? _year, _firstMonth ?? 1);
  DateTime get _currentMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  bool get _canGoToPreviousMonth =>
      _selectedMonth.isAfter(_firstSelectableMonth);
  bool get _canGoToNextMonth => _selectedMonth.isBefore(_currentMonth);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<UserProvider>().user;
    if (!_userInitialized || user?.id != _reportUserId ||
        context.read<UserProvider>().dataRevision != _dataRevision) {
      _userInitialized = true;
      _reportUserId = user?.id;
      _dataRevision = context.read<UserProvider>().dataRevision;
      final now = DateTime.now();
      _firstYear = user?.createdAt.year ?? now.year;
      _firstMonth = user?.createdAt.month ?? now.month;
      if (_year < _firstYear!) _year = _firstYear!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _selectMonthAndYear() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    var selectedYear = _year;
    var selectedMonth = _month;
    final now = DateTime.now();
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final firstYear = user.createdAt.year;
          final years = List.generate(
            now.year - firstYear + 1,
            (index) => firstYear + index,
          );

          return Container(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              16 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'เลือกเดือนและปี',
                          style: TextStyle(
                            color: Color(0xFF38312C),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DropdownButton<int>(
                        value: selectedYear,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(12),
                        items: years
                            .map(
                              (year) => DropdownMenuItem<int>(
                                value: year,
                                child: Text('${year + 543}'),
                              ),
                            )
                            .toList(),
                        onChanged: (year) {
                          if (year == null) return;
                          setSheetState(() {
                            selectedYear = year;
                          });
                        },
                      ),
                      const Text(
                        ' พ.ศ.',
                        style: TextStyle(color: Color(0xFF77716C)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'เลือกเดือนที่ต้องการดูรายงาน',
                    style: TextStyle(color: Color(0xFF8A817A), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _monthNames.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisExtent: 46,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      final month = index + 1;
                      final isSelected = selectedMonth == month;
                      return Material(
                        color: isSelected
                            ? _brown
                            : const Color(0xFFF8F4EE),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => setSheetState(
                            () => selectedMonth = month,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                            child: Text(
                              _monthNames[index],
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : _brown,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text(
                          'ยกเลิก',
                          style: TextStyle(color: Color(0xFF77716C)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          DateTime(selectedYear, selectedMonth),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brown,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('ตกลง'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _month = selected.month;
      _year = selected.year;
      _selectedCategory = null;
    });
    _load();
  }

  void _moveMonth(int offset) {
    final next = DateTime(_year, _month + offset);
    if (next.isBefore(_firstSelectableMonth) || next.isAfter(_currentMonth)) {
      return;
    }
    setState(() {
      _year = next.year;
      _month = next.month;
      _selectedCategory = null;
    });
    _load();
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECE7E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ช่วงเวลารายงาน',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A817A),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                tooltip: 'เดือนก่อนหน้า',
                onPressed:
                    _canGoToPreviousMonth ? () => _moveMonth(-1) : null,
                style: IconButton.styleFrom(
                  backgroundColor: _cream,
                  foregroundColor: _brown,
                  disabledForegroundColor: const Color(0xFFC9C2BB),
                ),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Material(
                  color: _cream,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: _selectMonthAndYear,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            color: _brown,
                            size: 21,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_monthNames[_month - 1]} ${_year + 543}',
                                  style: const TextStyle(
                                    color: Color(0xFF38312C),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'แตะเพื่อเลือกเดือนและปี',
                                  style: TextStyle(
                                    color: Color(0xFF8A817A),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'เดือนถัดไป',
                onPressed: _canGoToNextMonth ? () => _moveMonth(1) : null,
                style: IconButton.styleFrom(
                  backgroundColor: _cream,
                  foregroundColor: _brown,
                  disabledForegroundColor: const Color(0xFFC9C2BB),
                ),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _load() {
    final userId = context.read<UserProvider>().user?.id;
    if (userId == null) {
      setState(() {
        _report = null;
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _report = _repository.getReportData(
        userId: userId,
        year: _year,
        month: _month,
        transactionType: widget.isIncome ? 'INCOME' : 'EXPENSE',
      ).whenComplete(() {
        if (mounted) setState(() => _isLoading = false);
      });
    });
  }

  String _money(num value) => NumberFormat('#,##0.00').format(value);

  Future<void> _choosePdfType() async {
    final type = await showModalBottomSheet<ReportPdfType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'เลือกรูปแบบ PDF',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('รายการ payment'),
                subtitle: const Text('วันที่ หมวดหมู่ และจำนวนเงิน'),
                onTap: () => Navigator.pop(sheetContext, ReportPdfType.payments),
              ),
              ListTile(
                leading: const Icon(Icons.pie_chart_outline_rounded),
                title: const Text('กราฟ pie chart'),
                subtitle: const Text('สัดส่วนรายรับและรายจ่ายแยกตามหมวดหมู่'),
                onTap: () => Navigator.pop(sheetContext, ReportPdfType.pieChart),
              ),
            ],
          ),
        ),
      ),
    );
    if (type != null && mounted) await _exportPdf(type);
  }

  Future<void> _exportPdf(ReportPdfType reportType) async {
    final user = context.read<UserProvider>().user;
    final userId = user?.id;
    if (user == null || userId == null || _isExportingPdf) return;
    final year = _year;
    final month = _month;
    setState(() => _isExportingPdf = true);
    try {
      final reports = await Future.wait([
        _repository.getReportData(
          userId: userId,
          year: year,
          month: month,
          transactionType: 'INCOME',
        ),
        _repository.getReportData(
          userId: userId,
          year: year,
          month: month,
          transactionType: 'EXPENSE',
        ),
      ]);
      final opened = await _pdfService.createAndPrint(
        userName: user.displayName,
        year: year,
        month: month,
        incomeData: reports[0],
        expenseData: reports[1],
        reportType: reportType,
      );
      if (!mounted) return;
      if (opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('สร้างรายงาน PDF เรียบร้อยแล้ว')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สร้าง PDF ไม่สำเร็จ: $error')),
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  String _compactMoney(num value) {
    final amount = value.toDouble();
    if (amount.abs() < 1000) {
      return NumberFormat('#,##0.##').format(amount);
    }
    final scaled = amount / 1000;
    final formatted = scaled == scaled.roundToDouble()
        ? scaled.toStringAsFixed(0)
        : scaled.toStringAsFixed(scaled.abs() >= 100 ? 0 : 1);
    return '${formatted}K';
  }

  @override
  Widget build(BuildContext context) {
    final income = widget.isIncome;
    final title = income ? 'สรุปรายรับ' : 'สรุปรายจ่าย';
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EF),
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: const Color(0xFFF7F4EF),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'ส่งออกรายงาน PDF',
            onPressed: _isLoading || _isExportingPdf ? null : _choosePdfType,
            icon: _isExportingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _report,
          builder: (context, snapshot) {
            if (_isLoading || snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text('โหลดข้อมูลสรุปไม่สำเร็จ\n${snapshot.error}', textAlign: TextAlign.center));
            if (_report == null || snapshot.data == null) return const Center(child: Text('ยังไม่มีข้อมูลสรุป'));
            final data = snapshot.data!;
            final total = data['total'] as double;
            final categoryTotals = data['categories'] as Map<String, double>;
            final rows = data['transactions'] as List<Map<String, Object?>>;
            final filteredRows = _selectedCategory == null
                ? rows
                : rows
                    .where((row) => row['category'] == _selectedCategory)
                    .toList();
            final segments = categoryTotals.entries.toList().asMap().entries.map((entry) => ChartSegment(
              label: entry.value.key,
              amount: entry.value.value,
              percentage: total == 0 ? 0 : entry.value.value / total * 100,
              color: _colors[entry.key % _colors.length],
            )).toList();
            return RefreshIndicator(
              onRefresh: () async => _load(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(height: 16),
                  Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFECE7E1))), child: Column(children: [
                    DonutChart(segments: segments, centerTitle: income ? 'รวมรายรับ' : 'รวมรายจ่าย', centerAmount: '฿ ${_money(total)}', size: 190, strokeWidth: 26),
                    const SizedBox(height: 20),
                    if (segments.isEmpty)
                      const Text('ยังไม่มีข้อมูลสรุป')
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: segments.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 42,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemBuilder: (context, index) {
                          final segment = segments[index];
                          final isSelected = _selectedCategory == segment.label;
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() {
                              _selectedCategory = isSelected ? null : segment.label;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? segment.color.withValues(alpha: 0.08)
                                    : const Color(0xFFFAF8F5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? segment.color.withValues(alpha: 0.65)
                                      : const Color(0xFFE9E2DA),
                                ),
                              ),
                              child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: segment.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    segment.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF6E6259),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                SizedBox(
                                  width: 40,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '฿${_compactMoney(segment.amount)}',
                                      style: const TextStyle(
                                        color: Color(0xFF38312C),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  width: 30,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: segment.color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  alignment: Alignment.center,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${segment.percentage.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        color: segment.color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
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
                  ])),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${income ? 'รายการรายรับ' : 'รายการรายจ่าย'} (${filteredRows.length} รายการ)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_selectedCategory != null)
                        TextButton(
                          onPressed: () => setState(() => _selectedCategory = null),
                          child: const Text('ทั้งหมด'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (filteredRows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          _selectedCategory == null
                              ? 'ไม่มีรายการในเดือนนี้'
                              : 'ไม่มีรายการในหมวดหมู่ $_selectedCategory',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ...filteredRows.map((row) {
                    final date = DateTime.tryParse(row['transaction_date'] as String? ?? '');
                    final dateText = date == null ? '' : DateFormat('dd/MM/yyyy').format(date);
                    return Card(color: Colors.white, child: ListTile(
                      leading: CircleAvatar(backgroundColor: income ? const Color(0xFFEAF2EB) : const Color(0xFFF8ECEC), child: Icon(income ? Icons.south_west : Icons.north_east, color: income ? _colors[0] : _colors[4])),
                      title: Text((row['description'] as String?)?.trim().isNotEmpty == true ? row['description'] as String : (row['category'] as String? ?? 'อื่นๆ')),
                      subtitle: Text('${row['category']} • $dateText'),
                      trailing: Text('${income ? '+' : '-'}฿${_money(row['amount'] as num)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionSlipPage(
                        title: (row['description'] as String?)?.trim().isNotEmpty == true ? row['description'] as String : (row['category'] as String? ?? 'อื่นๆ'),
                        category: row['category'] as String?,
                        amount: (row['amount'] as num).toDouble(),
                        date: dateText,
                        isIncome: income,
                      ))),
                    ));
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
