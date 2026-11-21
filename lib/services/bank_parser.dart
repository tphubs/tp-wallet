import '../models/transaction.dart';
import '../utils/text.dart';

/// Kết quả đọc được từ thông báo ngân hàng / ảnh chụp / văn bản dán vào.
class ParsedTx {
  final int amount;
  final TxType type;
  final String description;
  final DateTime? date;
  final String? bank;
  final int? balance;

  /// true nếu chiều thu/chi suy ra từ dấu +/- rõ ràng.
  final bool confidentType;

  const ParsedTx({
    required this.amount,
    required this.type,
    required this.description,
    this.date,
    this.bank,
    this.balance,
    this.confidentType = false,
  });

  @override
  String toString() =>
      'ParsedTx($type $amount "$description" bank=$bank date=$date bal=$balance)';
}

class _Candidate {
  final int start;
  final int end;
  final int value;
  final String? sign;
  final bool hasCurrency;
  bool isBalance = false;
  bool isFee = false;
  bool isLabeled = false;

  _Candidate(this.start, this.end, this.value, this.sign, this.hasCurrency);

  int get score =>
      (sign != null ? 4 : 0) + (isLabeled ? 2 : 0) + (hasCurrency ? 1 : 0);
}

/// Bộ đọc nội dung giao dịch ngân hàng Việt Nam.
///
/// Không phụ thuộc nền tảng: dùng chung cho thông báo Android, chữ đọc từ
/// ảnh (OCR) và văn bản người dùng dán vào.
class BankParser {
  /// Tên gói ứng dụng ngân hàng / ví phổ biến -> tên hiển thị.
  static const Map<String, String> bankPackages = {
    'com.VCB': 'Vietcombank',
    'vn.com.techcombank.bb.app': 'Techcombank',
    'com.mbmobile': 'MB Bank',
    'com.vnpay.bidv': 'BIDV',
    'com.vietinbank.ipay': 'VietinBank',
    'com.vnpay.Agribank3g': 'Agribank',
    'mobile.acb.com.vn': 'ACB',
    'com.tpb.mb.gprsandroid': 'TPBank',
    'com.vnpay.vpbankonline': 'VPBank',
    'com.vpbank.neo': 'VPBank NEO',
    'com.sacombank.ewallet': 'Sacombank',
    'com.vib.myvib2': 'VIB',
    'com.vnpay.hdbank': 'HDBank',
    'vn.shb.mbanking': 'SHB',
    'vn.com.ocb.awe': 'OCB',
    'vn.com.msb.smartBanking': 'MSB',
    'xyz.be.cake': 'Cake',
    'io.lifestyle.plus': 'Timo',
    'com.mservice.momotransfer': 'MoMo',
    'vn.com.vng.zalopay': 'ZaloPay',
    'vn.shopeepay.app': 'ShopeePay',
  };

  static const Map<String, String> _bankKeywords = {
    'vietcombank': 'Vietcombank',
    'vcb': 'Vietcombank',
    'techcombank': 'Techcombank',
    'tcb': 'Techcombank',
    'mbbank': 'MB Bank',
    'mb bank': 'MB Bank',
    'bidv': 'BIDV',
    'vietinbank': 'VietinBank',
    'agribank': 'Agribank',
    'acb': 'ACB',
    'tpbank': 'TPBank',
    'vpbank': 'VPBank',
    'sacombank': 'Sacombank',
    'vib': 'VIB',
    'hdbank': 'HDBank',
    'shb': 'SHB',
    'ocb': 'OCB',
    'msb': 'MSB',
    'momo': 'MoMo',
    'zalopay': 'ZaloPay',
    'shopeepay': 'ShopeePay',
    'cake': 'Cake',
    'timo': 'Timo',
  };

  static final _number = r'(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+)';
  static final _amountRe = RegExp(
    r'(?<![\w.,])([+-]\s?)?' +
        _number +
        r'(?:\s?(vnd|d\b|₫|dong\b|k\b|tr\b|trieu\b))?',
  );

  static final _balanceLabel = RegExp(
    r'(so du|sodu|\bsd|balance|\bsdc)(\s*(hien tai|kha dung|cuoi( ky)?|moi|tk|tai khoan))?\s*(\(vnd\))?\s*[:=]?\s*$',
  );
  static final _feeLabel = RegExp(
    r'(\bphi|\bfee|\bvat)(\s*(giao dich|dich vu|gd))?\s*[:=]?\s*$',
  );
  static final _amountLabel = RegExp(
    r'(so tien(\s*(gd|giao dich|chuyen|thanh toan))?|\bps|\bgd|giao dich|amount|\bst|nhan duoc|nhan|thanh toan|chuyen|tru|cong|tang|giam)\s*[:=]?\s*$',
  );

  static final _otpRe = RegExp(
    r'\botp\b|ma xac thuc|ma xac nhan|ma giao dich la|mat khau',
  );

  static final _incomeKw = RegExp(
    r'nhan duoc|ban da nhan|ban vua nhan|da nhan|nhan tien|ghi co|\bcredit|duoc cong|tien vao|hoan tien|refund|\btang\b',
  );
  static final _expenseKw = RegExp(
    r'thanh toan|chuyen tien thanh cong|chuyen khoan thanh cong|giao dich thanh cong|da chuyen|ghi no|\bdebit|rut tien|bi tru|\btru\b|tien ra|\bgiam\b|chuyen den|chuyen toi|nguoi nhan',
  );

  static final _descLabel = RegExp(
    r'(?:^|[\s|.;,(])(?:nd|n\.d|noi dung(?: giao dich| gd| chuyen khoan| ck)?|mo ta|loi nhan|dien giai|\bref|\bgd|chi tiet)\s*[:\-]?\s*',
  );
  static final _counterpartyLabel = RegExp(
    r'(?:^|\n)\s*(?:ten nguoi nhan|nguoi nhan|ten nguoi chuyen|nguoi chuyen|tai khoan nhan|den|toi|tu)\s*[:\-]?\s*',
  );

  static final _dateRe = RegExp(
    r'(\d{1,2})[/-](\d{1,2})[/-](\d{4}|\d{2})(?:[\s;,]+(?:luc\s*)?(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
  );
  static final _timeThenDateRe = RegExp(
    r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(?:ngay\s*)?(\d{1,2})[/-](\d{1,2})[/-](\d{4}|\d{2})',
  );

  /// Có giống một thông báo biến động số dư / giao dịch không?
  static bool looksLikeTransaction(String text) {
    final n = normalizeVi(text);
    if (_otpRe.hasMatch(n)) return false;
    final hasSigned =
        RegExp(r'(?<![\w.,])[+-]\s?\d').hasMatch(n) &&
        RegExp(r'\d{1,3}([.,]\d{3})+|\d{4,}').hasMatch(n);
    final hasBalance = RegExp(r'so du|\bsd\b|\bsd:').hasMatch(n);
    final strong = RegExp(
      r'nhan duoc|thanh toan thanh cong|chuyen tien thanh cong|chuyen khoan thanh cong|giao dich thanh cong|ghi no|ghi co|bien dong so du',
    ).hasMatch(n);
    return hasSigned || hasBalance || strong;
  }

  /// Đọc văn bản. Trả về null nếu không tìm thấy số tiền hợp lệ.
  ///
  /// [packageName]: tên gói app gửi thông báo (Android), để nhận diện ngân hàng.
  /// [defaultType]: chiều mặc định nếu không suy ra được (ảnh chuyển khoản
  /// thường là chi).
  static ParsedTx? parse(
    String text, {
    String? packageName,
    TxType defaultType = TxType.expense,
  }) {
    if (text.trim().isEmpty) return null;
    final norm = normalizeVi(text);
    // normalizeVi có thể làm chuỗi ngắn lại nếu có dấu tổ hợp rời; khi đó
    // dùng bản đã chuẩn hóa để cắt mô tả.
    final original = norm.length == text.length ? text : norm;

    if (_otpRe.hasMatch(norm)) return null;

    final dateSpans = <(int, int)>[];
    for (final m in _dateRe.allMatches(norm)) {
      dateSpans.add((m.start, m.end));
    }
    for (final m in _timeThenDateRe.allMatches(norm)) {
      dateSpans.add((m.start, m.end));
    }
    // Giờ phút đứng riêng, ví dụ "10:20".
    for (final m in RegExp(r'\d{1,2}:\d{2}(:\d{2})?').allMatches(norm)) {
      dateSpans.add((m.start, m.end));
    }
    bool inDate(int s, int e) => dateSpans.any((d) => s < d.$2 && e > d.$1);

    final cands = <_Candidate>[];
    for (final m in _amountRe.allMatches(norm)) {
      final digits = m.group(2)!;
      final unit = m.group(3);
      final sign = m.group(1)?.trim();
      final numStart = m.start + (m.group(1)?.length ?? 0);
      if (inDate(
        numStart,
        m.start + (m.group(1)?.length ?? 0) + digits.length,
      )) {
        continue;
      }
      final grouped = RegExp(r'[.,]').hasMatch(digits);
      var value = _toInt(digits);
      if (value == null) continue;
      if (unit == 'k') value *= 1000;
      if (unit == 'tr' || unit == 'trieu') value *= 1000000;
      final hasCurrency = unit != null;
      // Số không có dấu phân cách và không có đơn vị: dễ là số tài khoản,
      // mã giao dịch, số điện thoại -> bỏ qua trừ khi có dấu +/- và độ dài hợp lý.
      if (!grouped && !hasCurrency) {
        if (sign == null || digits.length > 10) continue;
      }
      if (!grouped && digits.length > 12) continue;
      if (value < 1000 && unit != 'k' && unit != 'tr' && unit != 'trieu') {
        continue;
      }
      final c = _Candidate(m.start, m.end, value, sign, hasCurrency);
      final prevEnd = cands.isEmpty ? 0 : cands.last.end;
      var winStart = m.start - 40;
      if (winStart < prevEnd) winStart = prevEnd;
      if (winStart < 0) winStart = 0;
      final before = norm.substring(winStart, m.start);
      final lineBefore = before.split('\n').last;
      // Nhãn có thể nằm ở dòng trước (ảnh chụp: "Số tiền\n500.000 VND").
      final labelText = lineBefore.trim().isEmpty && before.contains('\n')
          ? before.trimRight()
          : lineBefore;
      c.isBalance = _balanceLabel.hasMatch(labelText);
      c.isFee = _feeLabel.hasMatch(labelText);
      c.isLabeled = _amountLabel.hasMatch(labelText);
      cands.add(c);
    }

    final usable = cands.where((c) => !c.isBalance && !c.isFee).toList();
    if (usable.isEmpty) return null;
    _Candidate best = usable.first;
    for (final c in usable) {
      if (c.score > best.score) best = c;
    }

    int? balance;
    final bal = cands.where((c) => c.isBalance).toList();
    if (bal.isNotEmpty) balance = bal.first.value;

    TxType type;
    bool confident = false;
    if (best.sign == '+') {
      type = TxType.income;
      confident = true;
    } else if (best.sign == '-') {
      type = TxType.expense;
      confident = true;
    } else {
      final inc = _incomeKw.hasMatch(norm);
      final exp = _expenseKw.hasMatch(norm);
      if (inc && !exp) {
        type = TxType.income;
      } else if (exp && !inc) {
        type = TxType.expense;
      } else if (inc && exp) {
        // Cả hai: lấy từ khóa xuất hiện trước.
        final i = _incomeKw.firstMatch(norm)!.start;
        final e = _expenseKw.firstMatch(norm)!.start;
        type = i < e ? TxType.income : TxType.expense;
      } else {
        type = defaultType;
      }
    }

    return ParsedTx(
      amount: best.value,
      type: type,
      description: _description(original, norm),
      date: _date(norm),
      bank: _bank(packageName, norm),
      balance: balance,
      confidentType: confident,
    );
  }

  static int? _toInt(String digits) {
    var d = digits;
    // Bỏ phần thập phân kiểu "500,000.00".
    final dec = RegExp(r'[.,]\d{1,2}$');
    if (RegExp(r'[.,]\d{3}').hasMatch(d) && dec.hasMatch(d)) {
      d = d.replaceFirst(dec, '');
    }
    return int.tryParse(d.replaceAll(RegExp(r'[.,]'), ''));
  }

  static String _description(String original, String norm) {
    String clean(String s) {
      var r = s;
      // Cắt ở dấu phân cách hay phần số dư phía sau.
      final stop = RegExp(
        r'\||\n|\.\s+(so du|sd)\b|;\s*(so du|sd)\b',
        caseSensitive: false,
      );
      final sm = stop.firstMatch(normalizeVi(r));
      if (sm != null) r = r.substring(0, sm.start);
      r = r.trim();
      r = r.replaceAll(RegExp(r'^[:\-.\s]+|[.\s]+$'), '');
      if (r.length > 120) r = r.substring(0, 120);
      return r;
    }

    // Ưu tiên nhãn "ND:", "Nội dung", ...; lấy nhãn cuối cùng có nội dung.
    final matches = _descLabel.allMatches(norm).toList();
    for (final m in matches.reversed) {
      var rest = original.substring(m.end);
      if (rest.trim().isEmpty) continue;
      // Ảnh chụp: nhãn ở một dòng, giá trị ở dòng sau.
      if (rest.startsWith('\n')) rest = rest.substring(1);
      final d = clean(rest);
      if (d.isNotEmpty &&
          !RegExp(
            r'^[+\-]?\s?[\d.,]+\s*(vnd|đ|₫)?$',
            caseSensitive: false,
          ).hasMatch(d)) {
        return d;
      }
    }

    final cp = _counterpartyLabel.firstMatch(norm);
    if (cp != null) {
      var rest = original.substring(cp.end);
      if (rest.startsWith('\n')) rest = rest.substring(1);
      final d = clean(rest);
      if (d.isNotEmpty) return d;
    }

    // Kiểu ví điện tử: "... 45.000đ cho Highlands Coffee" / "từ NGUYEN VAN A".
    final w = RegExp(
      r'\s(?:cho|tai|tu|den|toi)\s+(.+)$',
      multiLine: true,
    ).firstMatch(norm);
    if (w != null) {
      final d = clean(
        original.substring(w.start + w.group(0)!.indexOf(w.group(1)!)),
      );
      if (d.isNotEmpty) return d;
    }
    return '';
  }

  static DateTime? _date(String norm) {
    DateTime? build(
      String d,
      String mo,
      String y,
      String? h,
      String? mi,
      String? s,
    ) {
      var year = int.parse(y);
      if (year < 100) year += 2000;
      final month = int.parse(mo);
      final day = int.parse(d);
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      if (year < 2000 || year > 2100) return null;
      return DateTime(
        year,
        month,
        day,
        int.tryParse(h ?? '') ?? 0,
        int.tryParse(mi ?? '') ?? 0,
        int.tryParse(s ?? '') ?? 0,
      );
    }

    final a = _dateRe.firstMatch(norm);
    final b = _timeThenDateRe.firstMatch(norm);
    if (b != null && (a == null || b.start <= a.start)) {
      return build(
        b.group(4)!,
        b.group(5)!,
        b.group(6)!,
        b.group(1),
        b.group(2),
        b.group(3),
      );
    }
    if (a != null) {
      DateTime? r = build(
        a.group(1)!,
        a.group(2)!,
        a.group(3)!,
        a.group(4),
        a.group(5),
        a.group(6),
      );
      // Giờ đứng trước ngày nhưng cách xa: "luc 10:20 21/11/2026" đã xử lý ở trên.
      if (r != null && a.group(4) == null) {
        final t = RegExp(r'(\d{1,2}):(\d{2})(?::(\d{2}))?').firstMatch(norm);
        if (t != null) {
          r = DateTime(
            r.year,
            r.month,
            r.day,
            int.parse(t.group(1)!),
            int.parse(t.group(2)!),
            int.tryParse(t.group(3) ?? '') ?? 0,
          );
        }
      }
      return r;
    }
    return null;
  }

  static String? _bank(String? packageName, String norm) {
    if (packageName != null && bankPackages.containsKey(packageName)) {
      return bankPackages[packageName];
    }
    for (final e in _bankKeywords.entries) {
      if (RegExp('(^|[^a-z0-9])${RegExp.escape(e.key)}([^a-z0-9]|\$)')
          .hasMatch(norm)) {
        return e.value;
      }
    }
    return null;
  }
}
