import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum ReportPdfType { payments, pieChart }

class MonthlyReportPdfService {
  static const _monthNames = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];
  static const _palette = [
    0xFF4A7C59, 0xFF8C5338, 0xFFD89B52, 0xFF7D7571,
    0xFF8B3A3A, 0xFF5A8DA8, 0xFF7A6EA0, 0xFFB85C5C,
  ];

  Future<bool> createAndPrint({
    required String userName,
    required int year,
    required int month,
    required Map<String, dynamic> incomeData,
    required Map<String, dynamic> expenseData,
    required ReportPdfType reportType,
  }) async {
    final regularFont = pw.Font.ttf(
      (await rootBundle.load('assets/fonts/NotoSansThai-Regular.ttf')),
    );
    final boldFont = pw.Font.ttf(
      (await rootBundle.load('assets/fonts/NotoSansThai-Bold.ttf')),
    );
    final income = _summary(incomeData);
    final expense = _summary(expenseData);
    final incomeTotal = income['total'] as double;
    final expenseTotal = expense['total'] as double;
    final payments = [
      ..._payments(incomeData, 'รายรับ'),
      ..._payments(expenseData, 'รายจ่าย'),
    ]..sort((a, b) => b.date.compareTo(a.date));
    final pdf = pw.Document();
    final numberFormat = NumberFormat('#,##0.00');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 34, 32, 34),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'หน้า ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Text(
            reportType == ReportPdfType.payments
                ? 'รายการชำระเงิน'
                : 'สรุปรายรับ-รายจ่าย',
            style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('${_monthNames[month - 1]} ${year + 543} • $userName'),
          pw.SizedBox(height: 18),
          if (reportType == ReportPdfType.pieChart) ...[
            pw.Row(
              children: [
                _totalCard('รายรับ', incomeTotal, 0xFFEAF2EB, numberFormat),
                pw.SizedBox(width: 10),
                _totalCard('รายจ่าย', expenseTotal, 0xFFF8ECEC, numberFormat),
                pw.SizedBox(width: 10),
                _totalCard('สุทธิ', incomeTotal - expenseTotal, 0xFFF4F0E9, numberFormat),
              ],
            ),
            pw.SizedBox(height: 22),
            pw.Text(
              'สัดส่วนตามหมวดหมู่',
              style: const pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _pieSection('รายรับ', income, numberFormat)),
                pw.SizedBox(width: 16),
                pw.Expanded(child: _pieSection('รายจ่าย', expense, numberFormat)),
              ],
            ),
          ],
          if (reportType == ReportPdfType.payments) ...[
            pw.Text(
              'รายการชำระเงิน (${payments.length} รายการ)',
              style: const pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (payments.isEmpty)
              pw.Text('ไม่มีรายการในเดือนนี้')
            else
              pw.TableHelper.fromTextArray(
              headers: const ['วันที่', 'ประเภท', 'หมวดหมู่', 'รายละเอียด', 'จำนวนเงิน'],
              data: payments
                  .map((payment) => [
                        _formatDate(payment.date),
                        payment.type,
                        payment.category,
                        payment.description,
                        '${payment.type == 'รายรับ' ? '+' : '-'}${numberFormat.format(payment.amount)}',
                      ])
                  .toList(),
              headerStyle: const pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColor(0.35, 0.23, 0.16)),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColor(0.97, 0.96, 0.94)),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerRight,
              },
              columnWidths: {
                0: const pw.FlexColumnWidth(1.15),
                1: const pw.FlexColumnWidth(0.8),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(2.2),
                4: const pw.FlexColumnWidth(1.2),
              },
              ),
          ],
        ],
      ),
    );

    final reportName = reportType == ReportPdfType.payments ? 'payments' : 'pie_chart';
    final filename = 'financial_report_${reportName}_${year}_$month.pdf';
    return Printing.layoutPdf(
      name: filename,
      format: PdfPageFormat.a4,
      onLayout: (_) => pdf.save(),
    );
  }

  Map<String, dynamic> _summary(Map<String, dynamic> data) {
    final rawCategories = data['categories'] as Map? ?? {};
    return {
      'total': (data['total'] as num?)?.toDouble() ?? 0,
      'categories': <String, double>{
        for (final entry in rawCategories.entries)
          entry.key.toString(): (entry.value as num).toDouble(),
      },
    };
  }

  List<_PaymentRow> _payments(Map<String, dynamic> data, String type) {
    final rows = data['transactions'] as List? ?? [];
    return rows.whereType<Map>().map((row) {
      return _PaymentRow(
        date: row['transaction_date']?.toString() ?? '',
        type: type,
        category: row['category']?.toString() ?? 'อื่นๆ',
        description: (row['description']?.toString().trim().isNotEmpty ?? false)
            ? row['description'].toString().trim()
            : row['category']?.toString() ?? 'รายการ',
        amount: (row['amount'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  pw.Widget _totalCard(
    String label,
    double value,
    int background,
    NumberFormat numberFormat,
  ) {
    final rgb = background & 0xFFFFFF;
    final color = PdfColor(
      ((rgb >> 16) & 0xFF) / 255,
      ((rgb >> 8) & 0xFF) / 255,
      (rgb & 0xFF) / 255,
    );
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 4),
            pw.Text(
              '฿${numberFormat.format(value)}',
              style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _pieSection(
    String title,
    Map<String, dynamic> summary,
    NumberFormat numberFormat,
  ) {
    final categories = summary['categories'] as Map<String, double>;
    final entries = categories.entries.where((entry) => entry.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = summary['total'] as double;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        if (entries.isEmpty || total <= 0)
          pw.Container(
            height: 112,
            alignment: pw.Alignment.center,
            child: pw.Text('ไม่มีข้อมูล', style: const pw.TextStyle(fontSize: 9)),
          )
        else
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SvgImage(svg: _pieSvg(entries, total), width: 96, height: 96),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < entries.length; i++)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 3),
                        child: pw.Row(
                          children: [
                            pw.Container(
                              width: 6,
                              height: 6,
                              color: _pdfColor(_palette[i % _palette.length]),
                            ),
                            pw.SizedBox(width: 4),
                            pw.Expanded(
                              child: pw.Text(
                                entries[i].key,
                                maxLines: 1,
                                overflow: pw.TextOverflow.clip,
                                style: const pw.TextStyle(fontSize: 7),
                              ),
                            ),
                            pw.Text(
                              '${(entries[i].value / total * 100).toStringAsFixed(0)}%',
                              style: const pw.TextStyle(fontSize: 7),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        pw.SizedBox(height: 4),
        pw.Text('รวม ฿${numberFormat.format(total)}', style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  String _pieSvg(List<MapEntry<String, double>> entries, double total) {
    if (entries.length == 1) {
      return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200"><circle cx="100" cy="100" r="92" fill="${_hexColor(_palette[0])}"/></svg>';
    }
    var angle = -math.pi / 2;
    final paths = <String>[];
    for (var i = 0; i < entries.length; i++) {
      final sweep = entries[i].value / total * math.pi * 2;
      final end = angle + sweep;
      final x1 = 100 + 92 * math.cos(angle);
      final y1 = 100 + 92 * math.sin(angle);
      final x2 = 100 + 92 * math.cos(end);
      final y2 = 100 + 92 * math.sin(end);
      final largeArc = sweep > math.pi ? 1 : 0;
      paths.add(
        '<path d="M 100 100 L ${x1.toStringAsFixed(2)} ${y1.toStringAsFixed(2)} '
        'A 92 92 0 $largeArc 1 ${x2.toStringAsFixed(2)} ${y2.toStringAsFixed(2)} Z" '
        'fill="${_hexColor(_palette[i % _palette.length])}" stroke="#FFFFFF" stroke-width="1"/>',
      );
      angle = end;
    }
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">${paths.join()}</svg>';
  }

  PdfColor _pdfColor(int color) => PdfColor(
        ((color >> 16) & 0xFF) / 255,
        ((color >> 8) & 0xFF) / 255,
        (color & 0xFF) / 255,
      );

  String _hexColor(int color) => '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year + 543}';
  }
}

class _PaymentRow {
  const _PaymentRow({
    required this.date,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
  });

  final String date;
  final String type;
  final String category;
  final String description;
  final double amount;
}
