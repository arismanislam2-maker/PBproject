import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import 'ai_config.dart';

class FinancialSnapshot {
  FinancialSnapshot({
    required this.now,
    required this.monthLabel,
    required this.previousMonthLabel,
    required this.totalBalance,
    required this.accounts,
    required this.currentIncome,
    required this.currentExpense,
    required this.previousIncome,
    required this.previousExpense,
    required this.categories,
    required this.recent,
    required this.goals,
  });

  final DateTime now;
  final String monthLabel;
  final String previousMonthLabel;
  final double totalBalance;
  final List<Map<String, dynamic>> accounts;
  final double currentIncome;
  final double currentExpense;
  final double previousIncome;
  final double previousExpense;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> recent;
  final List<Map<String, dynamic>> goals;
}

class OpenRouterService {
  OpenRouterService({HttpClient? client}) : _client = client ?? HttpClient();

  static const _apiKey = openRouterApiKey;
  /// รายการโมเดลฟรีที่รองรับ (id, label, subtitle)
  static const freeModels = [
    (
      id: 'google/gemini-2.0-flash-exp:free',
      label: 'Gemini 2.0 Flash',
      subtitle: 'Google · รวดเร็ว, บริบทยาว',
      icon: '✨',
    ),
    (
      id: 'meta-llama/llama-3.3-70b-instruct:free',
      label: 'Llama 3.3 70B',
      subtitle: 'Meta · ฉลาด, เข้าใจภาษาไทยดี',
      icon: '🦙',
    ),
    (
      id: 'qwen/qwen-2.5-72b-instruct:free',
      label: 'Qwen 2.5 72B',
      subtitle: 'Alibaba · เข้าใจบริบทเชิงลึก',
      icon: '🔮',
    ),
    (
      id: 'deepseek/deepseek-r1:free',
      label: 'DeepSeek R1',
      subtitle: 'DeepSeek · คิดแบบ Chain-of-Thought',
      icon: '🧠',
    ),
    (
      id: 'mistralai/mistral-7b-instruct:free',
      label: 'Mistral 7B',
      subtitle: 'Mistral · เบา, ตอบเร็ว',
      icon: '💨',
    ),
  ];

  static const defaultModel = 'deepseek/deepseek-r1:free';

  static const _candidateModels = [
    'deepseek/deepseek-r1:free',
    'google/gemini-2.0-flash-exp:free',
    'meta-llama/llama-3.3-70b-instruct:free',
    'qwen/qwen-2.5-72b-instruct:free',
    'openrouter/free',
  ];
  final HttpClient _client;

  String _buildSystemPrompt(String financialContext) => '''
You are MyFinance Assistant (ผู้ช่วยการเงิน MyFinance), a friendly, polite, and helpful personal finance assistant in the MyFinance expense tracking app.

Primary instructions:
1. Always stay in the context of personal finance, money management, budgeting, saving goals, expenses, income, and everyday math calculations.
2. Reply in Thai naturally, warmly, and concisely (2-4 clear sentences or structured bullet points).
3. When the user asks about their financial situation, use the actual database records provided below.
4. For calculations, explain the result politely in a financial context.
5. Never invent fictional accounts or fake transactions not present in the database.
6. If the user uses slang, frustrated language, or casual words, remain polite, understanding, and guide them back to managing their finances in MyFinance.

User Financial Data (amounts in THB):
$financialContext
''';

  Stream<String> answerStream({
    required int userId,
    required List<Map<String, String>> conversation,
    String? selectedModel,
  }) async* {
    final latestQuestion = _latestQuestion(conversation);
    final snapshot = await _loadFinancialSnapshot(userId);

    // 1. ตรวจสอบการคำนวณตัวเลข
    final calculation = _tryCalculate(latestQuestion);
    if (calculation != null) {
      yield calculation;
      return;
    }

    // 2. ตอบด้วยระบบอัจฉริยะในเครื่องที่ตรงกับบริบทของแอป MyFinance
    final localAnswer = _generateLocalResponse(latestQuestion, snapshot);
    if (localAnswer != null) {
      final lines = localAnswer.split('\n');
      for (var i = 0; i < lines.length; i++) {
        yield lines[i] + (i < lines.length - 1 ? '\n' : '');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return;
    }

    // 3. หากมีคำถามอื่นๆ ที่ไม่ตรงเงื่อนไขข้างต้น ให้ลองส่งหาโมเดลออนไลน์
    if (_apiKey.isNotEmpty) {
      try {
        final context = _snapshotToContextString(snapshot);
        var streamedAny = false;
        await for (final chunk in _streamFromOpenRouter(context, conversation, selectedModel: selectedModel)) {
          streamedAny = true;
          yield chunk;
        }
        if (streamedAny) return;
      } catch (_) {
        // หาก API ไม่พร้อมใช้งานหรือติดข้อจำกัด ให้ใช้คำตอบสรุปอัตโนมัติ
      }
    }

    // 4. Fallback: สรุปภาพรวมทางการเงินของแอปอย่างสุภาพ
    final fallback = _buildFallbackFinancialSummary(latestQuestion, snapshot);
    final lines = fallback.split('\n');
    for (var i = 0; i < lines.length; i++) {
      yield lines[i] + (i < lines.length - 1 ? '\n' : '');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Stream<String> _streamFromOpenRouter(
    String context,
    List<Map<String, String>> conversation, {
    String? selectedModel,
  }) async* {
    // ถ้าผู้ใช้เลือกโมเดล ให้ลองโมเดลนั้นก่อน แล้ว fallback ตามปกติ
    final modelsToTry = selectedModel != null
        ? [selectedModel, ..._candidateModels.where((m) => m != selectedModel)]
        : _candidateModels;
    for (final model in modelsToTry) {
      try {
        final request = await _client
            .postUrl(Uri.parse('https://openrouter.ai/api/v1/chat/completions'))
            .timeout(const Duration(seconds: 10));
        request.headers
          ..set(HttpHeaders.authorizationHeader, 'Bearer $_apiKey')
          ..contentType = ContentType.json
          ..set(HttpHeaders.acceptHeader, 'text/event-stream')
          ..set('HTTP-Referer', 'https://myfinance.local')
          ..set('X-Title', 'MyFinance');
        request.write(jsonEncode({
          'model': model,
          'temperature': 0.2,
          'max_tokens': 400,
          'stream': true,
          'messages': [
            {'role': 'system', 'content': _buildSystemPrompt(context)},
            ...conversation.skip(conversation.length > 20 ? conversation.length - 20 : 0),
          ],
        }));
        final response = await request.close().timeout(const Duration(seconds: 20));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }

        var received = false;
        await for (final line in response
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .timeout(const Duration(seconds: 25))) {
          if (!line.startsWith('data:')) continue;
          final data = line.substring(5).trim();
          if (data.isEmpty || data == '[DONE]') continue;
          try {
            final event = jsonDecode(data) as Map<String, dynamic>;
            final choices = event['choices'] as List<dynamic>?;
            if (choices == null || choices.isEmpty) continue;
            final choice = choices.first;
            if (choice is! Map) continue;
            final delta = choice['delta'];
            final content = delta is Map ? delta['content'] : null;
            final text = _contentText(content);
            if (text.isNotEmpty) {
              received = true;
              yield text;
            }
          } catch (_) {}
        }
        if (received) return;
      } catch (_) {
        continue;
      }
    }
    throw const HttpException('All AI models unavailable');
  }

  String _contentText(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      return content
          .whereType<Map>()
          .map((part) => part['text'])
          .whereType<String>()
          .join();
    }
    return '';
  }

  String _latestQuestion(List<Map<String, String>> conversation) {
    for (final message in conversation.reversed) {
      if (message['role'] == 'user') return message['content']?.trim() ?? '';
    }
    return '';
  }

  String? _tryCalculate(String question) {
    var expression = question.trim();
    expression = expression.replaceFirst(
      RegExp(r'^(?:please\s+)?(?:calculate|what\s+is)\s+', caseSensitive: false),
      '',
    );
    expression = expression.replaceFirst(
      RegExp(r'^(?:ช่วยคำนวณ|คำนวณ|ช่วยคิด|คิดเลข)\s*'),
      '',
    );
    expression = expression.replaceFirst(
      RegExp(r'\s*(?:เท่าไหร่|เท่าไร|ได้เท่าไหร่|ได้เท่าไร|บาท|฿)\s*[?？.]*$', caseSensitive: false),
      '',
    );
    expression = expression.replaceFirst(RegExp(r'\s*[?？=]+\s*$'), '');
    expression = expression
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAllMapped(
          RegExp(r'(\d),(?=\d{3}(?:\D|$))'),
          (_) => '',
        );

    if (expression.isEmpty ||
        !RegExp(r'[+\-*/]').hasMatch(expression) ||
        !RegExp(r'^[\d\s().+\-*/]*$').hasMatch(expression)) {
      return null;
    }

    try {
      final result = _ArithmeticParser(expression).parse();
      if (!result.isFinite) return null;
      final formatted = NumberFormat('#,##0.##').format(result);
      final displayExpression = expression.replaceAll('*', '×').replaceAll('/', '÷');
      return '🔢 **ผลการคำนวณ:** $displayExpression = **$formatted บาท**\n\n'
          'ต้องการให้นำยอดนี้ไปช่วยวางแผนงบประมาณ หรือบันทึกเป็นรายรับ-รายจ่ายบอกผมได้เลยนะครับ 😊';
    } on FormatException {
      return null;
    } on UnsupportedError {
      return null;
    }
  }

  String? _generateLocalResponse(String question, FinancialSnapshot snapshot) {
    final q = question.trim().toLowerCase();
    final money = NumberFormat('#,##0.00');
    final net = snapshot.currentIncome - snapshot.currentExpense;

    // 1. ทักทาย / แนะนำตัว / ถามชื่อ
    if (RegExp(
      r'(?:สวัสดี|หวัดดี|ดีครับ|ดีค่ะ|ดีจ้า|hi\b|hello|hey\b|'
      r'ทำอะไรได้|ช่วยอะไรได้|คุณคือ|คุณคือใคร|ใครคุณ|คุณชื่อ|ชื่ออะไร|'
      r'ชื่อว่า|แนะนำตัว|เป็นใคร|คือใคร|คุณเป็น|ai ชื่อ|bot ชื่อ)',
      caseSensitive: false,
    ).hasMatch(q) ||
        q == '?' || q == 'ทำไรได้' || q == 'ช่วยอะไร') {
      return 'สวัสดีครับ! 😊 ผมชื่อ **MyFinance Assistant** ผู้ช่วยการเงินส่วนตัวในแอป MyFinance ของคุณครับ\n\n'
          'ผมพร้อมช่วยดูแลการเงินของคุณจากข้อมูลจริงในแอป ดังนี้ครับ:\n'
          '• 💰 **ยอดเงินคงเหลือ:** ดูเงินคงเหลือแยกตามบัญชี\n'
          '• 📊 **สรุปรายรับ-รายจ่าย:** ดูยอดรวมและเงินสุทธิประจำเดือน\n'
          '• 💸 **วิเคราะห์การใช้จ่าย:** ดูหมวดหมู่ที่ใช้เงินมากที่สุด\n'
          '• 🎯 **เป้าหมายการออม:** ติดตามความคืบหน้าเงินออม\n'
          '• 💡 **วางแผนงบประมาณ:** จัดสรรเงินด้วยสูตร 50/30/20\n\n'
          'ลองพิมพ์ถาม เช่น *"ยอดเงินเหลือเท่าไหร่"* หรือ *"สรุปรายจ่ายเดือนนี้"* ได้เลยครับ!';
    }

    // 2. คำสบถ / คำตัดพ้อ / คำสั้นๆ ทั่วไป (เช่น kuy, เหี้ย, ได้ยัง)
    if (RegExp(r'\b(?:kuy|ควย|เหี้ย|สัส|สัด|ไอสัส|เย็ด|มึง|กู)\b').hasMatch(q) ||
        q == 'kuy' || q == 'ได้ยัง' || q == 'ยัง' || q == 'ได้มั้ย' || q == 'ทำไม') {
      return 'ผมพร้อมช่วยเหลือคุณแล้วครับ! 😊\n\n'
          'สามารถสอบถามข้อมูลการเงินในแอป MyFinance ได้เลยนะครับ เช่น:\n'
          '• *"ยอดเงินคงเหลือเท่าไหร่"*\n'
          '• *"เดือนนี้ใช้เงินไปเท่าไหร่"*\n'
          '• *"สรุปภาพรวมการเงิน"*\n'
          '• *"เช็คเป้าหมายการออมเงิน"*';
    }

    // 3. ยอดเงินคงเหลือ / บัญชี
    if (q.contains('ยอดเงิน') ||
        q.contains('เงินเหลือ') ||
        q.contains('คงเหลือ') ||
        q.contains('มีเงิน') ||
        q.contains('เงินในบัญชี') ||
        q.contains('กระเป๋า') ||
        q.contains('balance') ||
        (q.contains('บัญชี') && !q.contains('ลบ') && !q.contains('แก้'))) {
      final buffer = StringBuffer();
      buffer.writeln('💰 **ยอดเงินคงเหลือรวมทั้งหมด:** ${money.format(snapshot.totalBalance)} บาท\n');
      if (snapshot.accounts.isNotEmpty) {
        buffer.writeln('📌 **รายละเอียดตามบัญชี:**');
        for (final acc in snapshot.accounts) {
          final name = acc['account_name'] ?? 'บัญชี';
          final type = acc['account_type'] ?? '';
          final bal = (acc['initial_balance'] as num?)?.toDouble() ?? 0;
          buffer.writeln('• $name ($type): ${money.format(bal)} บาท');
        }
      } else {
        buffer.writeln('📌 ยังไม่มีบัญชีที่เปิดใช้งานในระบบ');
      }
      buffer.writeln('\n💡 *สามารถเพิ่มบัญชีหรือบันทึกรายการเพื่ออัปเดตยอดเงินได้ตลอดเวลาครับ*');
      return buffer.toString();
    }

    // 4. รายรับ / รายได้
    if (q.contains('รายรับ') ||
        q.contains('รายได้') ||
        q.contains('เงินเข้า') ||
        q.contains('ได้เงิน') ||
        q.contains('income')) {
      final buffer = StringBuffer();
      buffer.writeln('💵 **สรุปรายรับเดือนนี้ (${snapshot.monthLabel}):** ${money.format(snapshot.currentIncome)} บาท\n');
      if (snapshot.previousIncome > 0) {
        final diff = snapshot.currentIncome - snapshot.previousIncome;
        final sign = diff >= 0 ? '+' : '';
        buffer.writeln('• เทียบเดือนที่แล้ว: ${money.format(snapshot.previousIncome)} บาท ($sign${money.format(diff)} บาท)');
      }
      buffer.writeln('• ยอดสุทธิคงเหลือเดือนนี้: ${money.format(net)} บาท');
      buffer.writeln('\n💡 *เคล็ดลับ: พยายามรักษาการออมอย่างน้อย 20% ของรายรับเพื่อสร้างความมั่นคงทางการเงินครับ*');
      return buffer.toString();
    }

    // 5. รายจ่าย / ใช้เงิน / ค่าใช้จ่าย
    if (q.contains('รายจ่าย') ||
        q.contains('ใช้เงิน') ||
        q.contains('จ่ายไป') ||
        q.contains('ค่าใช้จ่าย') ||
        q.contains('expense') ||
        q.contains('หมดไป') ||
        q.contains('จ่ายอะไร') ||
        q.contains('เสียเงิน')) {
      final buffer = StringBuffer();
      buffer.writeln('💸 **สรุปรายจ่ายเดือนนี้ (${snapshot.monthLabel}):** ${money.format(snapshot.currentExpense)} บาท\n');
      buffer.writeln('• รายรับเดือนนี้: ${money.format(snapshot.currentIncome)} บาท');
      buffer.writeln('• ยอดสุทธิคงเหลือเดือนนี้: ${money.format(net)} บาท\n');
      final expenseCats = snapshot.categories.where((c) => c['transaction_type'] == 'EXPENSE').toList();
      if (expenseCats.isNotEmpty) {
        final top = expenseCats.first;
        buffer.writeln('🔥 **หมวดหมู่ที่จ่ายมากที่สุด:** ${top['category']} (${money.format(top['total'])} บาท)');
      }
      return buffer.toString();
    }

    // 6. หมวดหมู่ค่าใช้จ่าย
    if (q.contains('หมวดหมู่') ||
        q.contains('อะไรเยอะสุด') ||
        q.contains('จ่ายอะไรมากสุด') ||
        q.contains('สัดส่วน') ||
        q.contains('category')) {
      final expenseCats = snapshot.categories.where((c) => c['transaction_type'] == 'EXPENSE').toList();
      if (expenseCats.isEmpty) {
        return '📊 ยังไม่มีข้อมูลการใช้จ่ายตามหมวดหมู่ในเดือนนี้ครับ สามารถบันทึกรายการรายจ่ายเพื่อเริ่มติดตามได้เลยครับ';
      }
      final buffer = StringBuffer();
      buffer.writeln('📊 **สัดส่วนรายจ่ายตามหมวดหมู่เดือนนี้ (${snapshot.monthLabel}):**\n');
      final total = snapshot.currentExpense > 0 ? snapshot.currentExpense : 1.0;
      for (var i = 0; i < expenseCats.length && i < 5; i++) {
        final cat = expenseCats[i];
        final catTotal = (cat['total'] as num?)?.toDouble() ?? 0;
        final count = cat['transaction_count'] ?? 1;
        final pct = (catTotal / total * 100).toStringAsFixed(1);
        buffer.writeln('${i + 1}. **${cat['category']}**: ${money.format(catTotal)} บาท ($pct%) - $count รายการ');
      }
      return buffer.toString();
    }

    // 7. เป้าหมายการออมเงิน
    if (q.contains('เป้าหมาย') ||
        q.contains('ออมเงิน') ||
        q.contains('เก็บเงิน') ||
        q.contains('goal') ||
        q.contains('saving') ||
        q.contains('เงินเก็บ')) {
      if (snapshot.goals.isEmpty) {
        return '🎯 **เป้าหมายการออมเงิน:**\nขณะนี้คุณยังไม่มีเป้าหมายการออมที่กำลังดำเนินการอยู่ครับ สามารถไปที่เมนู **"เป้าหมาย"** เพื่อสร้างเป้าหมายใหม่ได้เลยครับ ✨';
      }
      final buffer = StringBuffer();
      buffer.writeln('🎯 **สถานะเป้าหมายการออมเงินของคุณ:**\n');
      for (final g in snapshot.goals) {
        final target = (g['target_amount'] as num?)?.toDouble() ?? 0;
        final current = (g['current_amount'] as num?)?.toDouble() ?? 0;
        final remaining = (target - current).clamp(0, double.infinity);
        final pct = target > 0 ? (current / target * 100).toStringAsFixed(1) : '0';
        final deadline = g['deadline_date'] != null ? ' (กำหนด: ${g['deadline_date']})' : '';
        buffer.writeln('• **${g['target_name']}**$deadline');
        buffer.writeln('  เก็บได้แล้ว: ${money.format(current)} / ${money.format(target)} บาท (**$pct%**)');
        if (remaining > 0) {
          buffer.writeln('  👉 ขาดอีก: ${money.format(remaining)} บาท\n');
        } else {
          buffer.writeln('  🎉 บรรลุเป้าหมายเรียบร้อยแล้ว!\n');
        }
      }
      return buffer.toString();
    }

    // 8. รายการล่าสุด / ประวัติ
    if (q.contains('รายการล่าสุด') ||
        q.contains('ประวัติ') ||
        q.contains('ล่าสุด') ||
        q.contains('วันนี้') ||
        q.contains('เมื่อวาน') ||
        q.contains('ธุรกรรม') ||
        q.contains('transaction') ||
        q.contains('ซื้ออะไร')) {
      if (snapshot.recent.isEmpty) {
        return '📝 ยังไม่มีรายการธุรกรรมในระบบครับ กดปุ่ม **"+"** ที่หน้าหลักเพื่อเริ่มบันทึกรายการแรกได้เลยครับ';
      }
      final buffer = StringBuffer();
      buffer.writeln('📝 **รายการล่าสุดของคุณ:**\n');
      for (final tx in snapshot.recent.take(5)) {
        final isIncome = tx['transaction_type'] == 'INCOME';
        final sign = isIncome ? '+' : '-';
        final amt = (tx['amount'] as num?)?.toDouble() ?? 0;
        final date = tx['transaction_date']?.toString().split('T').first ?? '';
        final cat = tx['category'] ?? 'ทั่วไป';
        final note = tx['description']?.toString().trim();
        final noteStr = (note != null && note.isNotEmpty) ? ' ($note)' : '';
        buffer.writeln('• $date | $cat | **$sign${money.format(amt)} บาท**$noteStr');
      }
      return buffer.toString();
    }

    // 9. สรุปภาพรวม
    if (q.contains('สรุป') ||
        q.contains('ภาพรวม') ||
        q.contains('รายงาน') ||
        q.contains('สถานะ') ||
        q.contains('overview') ||
        q.contains('summary')) {
      final buffer = StringBuffer();
      buffer.writeln('📋 **สรุปภาพรวมการเงินประจำเดือน ${snapshot.monthLabel}:**\n');
      buffer.writeln('• 💰 **ยอดเงินคงเหลือรวม:** ${money.format(snapshot.totalBalance)} บาท');
      buffer.writeln('• 💵 **รายรับเดือนนี้:** ${money.format(snapshot.currentIncome)} บาท');
      buffer.writeln('• 💸 **รายจ่ายเดือนนี้:** ${money.format(snapshot.currentExpense)} บาท');
      buffer.writeln('• ⚖️ **ยอดสุทธิคงเหลือ:** ${money.format(net)} บาท\n');
      final expenseCats = snapshot.categories.where((c) => c['transaction_type'] == 'EXPENSE').toList();
      if (expenseCats.isNotEmpty) {
        final top = expenseCats.first;
        buffer.writeln('📊 **หมวดหมู่จ่ายสูงสุด:** ${top['category']} (${money.format(top['total'])} บาท)');
      }
      if (snapshot.goals.isNotEmpty) {
        buffer.writeln('🎯 **เป้าหมายที่กำลังดำเนินการ:** ${snapshot.goals.length} รายการ');
      }
      buffer.writeln('\n💡 *สามารถพิมพ์ถามเจาะลึกเฉพาะเรื่องได้เลยครับ*');
      return buffer.toString();
    }

    // 10. วางแผนงบประมาณ 50/30/20
    if (q.contains('50/30/20') ||
        q.contains('50 30 20') ||
        q.contains('แบ่งเงิน') ||
        q.contains('จัดสรร') ||
        q.contains('วางแผน') ||
        q.contains('งบประมาณ') ||
        q.contains('budget')) {
      double amount = 0;
      final numMatch = RegExp(r'(\d[\d,]*)(?:\s*(?:บาท|฿))?').firstMatch(question.replaceAll(',', ''));
      if (numMatch != null) {
        amount = double.tryParse(numMatch.group(1) ?? '') ?? 0;
      }
      if (amount <= 0 && snapshot.currentIncome > 0) {
        amount = snapshot.currentIncome;
      }
      if (amount <= 0) {
        amount = 10000;
      }
      final needs = amount * 0.50;
      final wants = amount * 0.30;
      final savings = amount * 0.20;
      return '💡 **การจัดสรรงบประมาณตามสูตร 50/30/20 (จากยอด ${money.format(amount)} บาท):**\n\n'
          '1. 🛒 **ค่าใช้จ่ายจำเป็น (Needs 50%):** **${money.format(needs)} บาท**\n'
          '   (เช่น ค่าที่พัก, ค่าอาหารประจำวัน, ค่าน้ำไฟ, ค่าเดินทาง, หนี้สินขั้นต่ำ)\n\n'
          '2. ☕ **ความต้องการส่วนตัว (Wants 30%):** **${money.format(wants)} บาท**\n'
          '   (เช่น ท่องเที่ยว, ช้อปปิ้ง, กาแฟ, กิจกรรมสันทนาการ)\n\n'
          '3. 🏦 **เงินออมและลงทุน (Savings 20%):** **${money.format(savings)} บาท**\n'
          '   (เช่น เงินสำรองฉุกเฉิน, ออมเพื่อเป้าหมายในแอป MyFinance)\n\n'
          '✨ *สามารถปรับสัดส่วนตามภาระค่าใช้จ่ายจริงของคุณได้เลยนะครับ*';
    }

    // 11. คำถามที่ไม่เกี่ยวกับการเงิน — ให้ตอบตรงๆ ว่าตอบไม่ได้
    final financeKeywords = [
      'เงิน', 'บาท', 'บัญชี', 'รายรับ', 'รายจ่าย', 'รายการ', 'ออม',
      'ลงทุน', 'หนี้', 'ค่าใช้จ่าย', 'สุทธิ', 'คงเหลือ', 'ธุรกรรม',
      'income', 'expense', 'balance', 'budget', 'saving', 'goal',
      'แอป', 'myfinance', 'เป้าหมาย', 'หมวดหมู่',
    ];
    final isFinanceRelated = financeKeywords.any((kw) => q.contains(kw));
    if (!isFinanceRelated && q.length > 3) {
      return 'ขออภัยครับ 🙏 ผมเป็นผู้ช่วยการเงินของแอป MyFinance ที่เชี่ยวชาญเรื่องการจัดการเงินและบัญชีเท่านั้นครับ\n\n'
          'สามารถถามผมเกี่ยวกับ:\n'
          '• 💰 ยอดเงินคงเหลือในบัญชีต่างๆ\n'
          '• 📊 สรุปรายรับ-รายจ่ายประจำเดือน\n'
          '• 🎯 ความคืบหน้าเป้าหมายการออมเงิน\n'
          '• 💡 คำแนะนำการวางแผนงบประมาณ\n\n'
          'ลองถามเรื่องการเงินของคุณได้เลยครับ 😊';
    }

    return null;
  }

  String _buildFallbackFinancialSummary(String question, FinancialSnapshot snapshot) {
    final money = NumberFormat('#,##0.00');
    final net = snapshot.currentIncome - snapshot.currentExpense;
    final q = question.trim().toLowerCase();

    // ตรวจสอบว่าเป็นคำถามการเงินหรือไม่
    final financeKeywords = [
      'เงิน', 'บาท', 'บัญชี', 'รายรับ', 'รายจ่าย', 'รายการ', 'ออม',
      'ลงทุน', 'หนี้', 'ค่าใช้จ่าย', 'สุทธิ', 'คงเหลือ', 'ธุรกรรม',
      'income', 'expense', 'balance', 'budget', 'saving', 'goal',
      'แอป', 'myfinance', 'เป้าหมาย', 'หมวดหมู่', 'สรุป', 'ภาพรวม',
    ];
    final isFinanceRelated = financeKeywords.any((kw) => q.contains(kw));

    if (!isFinanceRelated && q.length > 3) {
      // คำถามไม่เกี่ยวกับการเงิน — ตอบตรงๆ
      return 'ขออภัยครับ 🙏 ผมเป็น MyFinance Assistant ที่เชี่ยวชาญเฉพาะเรื่องการจัดการเงินและบัญชีในแอป MyFinance ครับ ยังไม่สามารถตอบคำถามนอกเหนือจากนี้ได้\n\n'
          'หากต้องการทราบข้อมูลการเงินของคุณ เช่น *"ยอดเงินเหลือเท่าไหร่"* หรือ *"เดือนนี้ใช้เงินไปเท่าไหร่"* ถามผมได้เลยครับ 😊';
    }

    // คำถามเกี่ยวกับการเงิน แต่ API ไม่พร้อม — สรุปข้อมูลที่มี
    return 'ขณะนี้ AI ภายนอกไม่พร้อมใช้งาน แต่ผมได้สรุปข้อมูลการเงินของคุณจากในระบบให้ดังนี้ครับ:\n\n'
        '💰 **ยอดเงินคงเหลือรวม:** ${money.format(snapshot.totalBalance)} บาท\n'
        '💵 **รายรับเดือนนี้ (${snapshot.monthLabel}):** ${money.format(snapshot.currentIncome)} บาท\n'
        '💸 **รายจ่ายเดือนนี้ (${snapshot.monthLabel}):** ${money.format(snapshot.currentExpense)} บาท\n'
        '⚖️ **สุทธิคงเหลือ:** ${money.format(net)} บาท\n\n'
        'คุณสามารถถามข้อมูลเฉพาะ เช่น *"ดูบัญชีทั้งหมด"*, *"หมวดหมู่ที่จ่ายเยอะสุด"*, หรือ *"เป้าหมายการออม"* ได้ตลอดเวลาครับ 😊';
  }

  Future<FinancialSnapshot> _loadFinancialSnapshot(int userId) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final currentStart = DateTime(now.year, now.month);
    final nextStart = DateTime(now.year, now.month + 1);
    final previousStart = DateTime(now.year, now.month - 1);

    final accounts = await db.query(
      'accounts',
      columns: ['account_name', 'account_type', 'initial_balance'],
      where: 'user_id = ? AND is_active = 1',
      whereArgs: [userId],
      orderBy: 'sort_order, id',
    );

    final currentTotalsRows = await db.rawQuery('''
      SELECT transaction_type, SUM(amount) AS total
      FROM transactions
      WHERE user_id = ? AND transaction_date >= ? AND transaction_date < ?
        AND transaction_type IN ('INCOME', 'EXPENSE')
      GROUP BY transaction_type
    ''', [userId, currentStart.toIso8601String(), nextStart.toIso8601String()]);
    final currentTotals = <String, double>{};
    for (final row in currentTotalsRows) {
      currentTotals[row['transaction_type'] as String] =
          (row['total'] as num?)?.toDouble() ?? 0;
    }

    final previousTotalsRows = await db.rawQuery('''
      SELECT transaction_type, SUM(amount) AS total
      FROM transactions
      WHERE user_id = ? AND transaction_date >= ? AND transaction_date < ?
        AND transaction_type IN ('INCOME', 'EXPENSE')
      GROUP BY transaction_type
    ''', [userId, previousStart.toIso8601String(), currentStart.toIso8601String()]);
    final previousTotals = <String, double>{};
    for (final row in previousTotalsRows) {
      previousTotals[row['transaction_type'] as String] =
          (row['total'] as num?)?.toDouble() ?? 0;
    }

    final categoryRows = await db.rawQuery('''
      SELECT t.transaction_type, COALESCE(c.name, 'Other') AS category,
             SUM(t.amount) AS total, COUNT(*) AS transaction_count
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.user_id = ? AND t.transaction_date >= ? AND t.transaction_date < ?
        AND t.transaction_type IN ('INCOME', 'EXPENSE')
      GROUP BY t.transaction_type, COALESCE(c.name, 'Other')
      ORDER BY t.transaction_type, total DESC
    ''', [userId, currentStart.toIso8601String(), nextStart.toIso8601String()]);

    final recent = await db.rawQuery('''
      SELECT t.transaction_type, t.amount, t.description, t.transaction_date,
             c.name AS category, COALESCE(f.account_name, a.account_name) AS account
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN accounts f ON f.id = t.from_account_id
      LEFT JOIN accounts a ON a.id = t.to_account_id
      WHERE t.user_id = ? ORDER BY t.transaction_date DESC LIMIT 30
    ''', [userId]);

    final goals = await db.query(
      'saving_goals',
      columns: ['target_name', 'target_amount', 'current_amount', 'deadline_date'],
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'IN_PROGRESS'],
    );

    final totalBalance = accounts.fold<double>(
      0,
      (sum, account) => sum + ((account['initial_balance'] as num?)?.toDouble() ?? 0),
    );

    final monthLabel = DateFormat('MMMM yyyy').format(currentStart);
    final previousMonthLabel = DateFormat('MMMM yyyy').format(previousStart);

    return FinancialSnapshot(
      now: now,
      monthLabel: monthLabel,
      previousMonthLabel: previousMonthLabel,
      totalBalance: totalBalance,
      accounts: accounts,
      currentIncome: currentTotals['INCOME'] ?? 0,
      currentExpense: currentTotals['EXPENSE'] ?? 0,
      previousIncome: previousTotals['INCOME'] ?? 0,
      previousExpense: previousTotals['EXPENSE'] ?? 0,
      categories: categoryRows,
      recent: recent,
      goals: goals,
    );
  }

  String _snapshotToContextString(FinancialSnapshot snapshot) {
    final money = NumberFormat('#,##0.00');
    return '''
Current date: ${DateFormat('yyyy-MM-dd').format(snapshot.now)}
Current reporting month: ${snapshot.monthLabel}
Current month income: ${money.format(snapshot.currentIncome)} THB
Current month expenses: ${money.format(snapshot.currentExpense)} THB
Current month net: ${money.format(snapshot.currentIncome - snapshot.currentExpense)} THB
Previous month (${snapshot.previousMonthLabel}) income: ${money.format(snapshot.previousIncome)} THB
Previous month (${snapshot.previousMonthLabel}) expenses: ${money.format(snapshot.previousExpense)} THB
Current total account balance: ${money.format(snapshot.totalBalance)} THB
Active accounts: ${snapshot.accounts.map((a) => '${a['account_name']} (${a['account_type']}): ${money.format((a['initial_balance'] as num?)?.toDouble() ?? 0)} THB').join('; ')}
Current-month category totals: ${snapshot.categories.map((row) => '${row['transaction_type']} / ${row['category']}: ${money.format((row['total'] as num?)?.toDouble() ?? 0)} THB (${row['transaction_count']} transactions)').join('; ')}
Active saving goals: ${snapshot.goals.map((goal) => '${goal['target_name']}: ${money.format((goal['current_amount'] as num?)?.toDouble() ?? 0)} / ${money.format((goal['target_amount'] as num?)?.toDouble() ?? 0)} THB; deadline ${goal['deadline_date'] ?? 'not set'}').join('; ')}
Latest 30 transactions (newest first): ${snapshot.recent.map((transaction) => '${transaction['transaction_date']} ${transaction['transaction_type']} ${money.format((transaction['amount'] as num?)?.toDouble() ?? 0)} THB; category ${transaction['category'] ?? 'Other'}; account ${transaction['account'] ?? 'unknown'}; note ${transaction['description'] ?? 'none'}').join('\n')}
''';
  }
}

class _ArithmeticParser {
  _ArithmeticParser(String expression) {
    final normalized = expression.replaceAll(RegExp(r'\s+'), '');
    _tokens = RegExp(r'(?:\d+(?:\.\d*)?|\.\d+)|[()+\-*/]')
        .allMatches(normalized)
        .map((match) => match.group(0)!)
        .toList();
    if (_tokens.join() != normalized) {
      throw const FormatException('Invalid arithmetic expression');
    }
  }

  late final List<String> _tokens;
  int _position = 0;

  double parse() {
    final result = _parseExpression();
    if (_position != _tokens.length) {
      throw const FormatException('Unexpected arithmetic token');
    }
    return result;
  }

  double _parseExpression() {
    var value = _parseTerm();
    while (_peek('+') || _peek('-')) {
      final operator = _tokens[_position++];
      final right = _parseTerm();
      value = operator == '+' ? value + right : value - right;
    }
    return value;
  }

  double _parseTerm() {
    var value = _parseFactor();
    while (_peek('*') || _peek('/')) {
      final operator = _tokens[_position++];
      final right = _parseFactor();
      if (operator == '/' && right == 0) {
        throw const FormatException('Cannot divide by zero');
      }
      value = operator == '*' ? value * right : value / right;
    }
    return value;
  }

  double _parseFactor() {
    var sign = 1.0;
    if (_peek('+') || _peek('-')) {
      if (_tokens[_position++] == '-') sign = -1;
    }
    if (_peek('(')) {
      _position++;
      final value = _parseExpression();
      if (!_peek(')')) throw const FormatException('Missing closing parenthesis');
      _position++;
      return sign * value;
    }
    if (_position >= _tokens.length) {
      throw const FormatException('Missing number');
    }
    final token = _tokens[_position++];
    if (token == '(' || token == ')' || token.length == 1 && RegExp(r'[+*/]').hasMatch(token)) {
      throw const FormatException('Expected a number');
    }
    return sign * double.parse(token);
  }

  bool _peek(String token) =>
      _position < _tokens.length && _tokens[_position] == token;
}
