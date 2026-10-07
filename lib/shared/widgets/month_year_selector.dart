import 'package:flutter/material.dart';

/// Shared month/year control for reports and saving goal activity.
class MonthYearSelector extends StatelessWidget {
  const MonthYearSelector({
    super.key,
    required this.year,
    required this.month,
    required this.firstYear,
    required this.firstMonth,
    required this.onChanged,
  });

  final int year;
  final int month;
  final int firstYear;
  final int firstMonth;
  final ValueChanged<DateTime> onChanged;

  static const _brown = Color(0xFF5A3A28);
  static const _cream = Color(0xFFF8F4EE);
  static const _monthNames = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  DateTime get _selected => DateTime(year, month);

  DateTime get _first => DateTime(firstYear, firstMonth);

  DateTime get _current {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  Future<void> _openPicker(BuildContext context) async {
    var selectedYear = year;
    var selectedMonth = month;
    final now = DateTime.now();
    final yearCount = now.year - firstYear + 1;
    if (yearCount <= 0) return;
    final years = List.generate(yearCount, (index) => firstYear + index);

    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
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
                            (itemYear) => DropdownMenuItem<int>(
                              value: itemYear,
                              child: Text('${itemYear + 543}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => selectedYear = value);
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
                  'เลือกเดือนที่ต้องการดูรายการ',
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
                    final selected = selectedMonth == index + 1;
                    return Material(
                      color: selected ? _brown : _cream,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => setSheetState(
                          () => selectedMonth = index + 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Center(
                          child: Text(
                            _monthNames[index],
                            style: TextStyle(
                              color: selected ? Colors.white : _brown,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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
        ),
      ),
    );

    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: _selected.isAfter(_first)
                    ? () => onChanged(DateTime(year, month - 1))
                    : null,
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
                    onTap: () => _openPicker(context),
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
                                  '${_monthNames[month - 1]} ${year + 543}',
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
                onPressed: _selected.isBefore(_current)
                    ? () => onChanged(DateTime(year, month + 1))
                    : null,
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
}
