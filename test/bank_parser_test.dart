import 'package:flutter_test/flutter_test.dart';
import 'package:tp_wallet/models/transaction.dart';
import 'package:tp_wallet/services/bank_parser.dart';
import 'package:tp_wallet/services/categorizer.dart';
import 'package:tp_wallet/utils/text.dart';

void main() {
  group('normalizeVi', () {
    test('bỏ dấu', () {
      expect(normalizeVi('Số dư TÀI KHOẢN Đã nhận'), 'so du tai khoan da nhan');
      expect(
        normalizeVi('Phở bò Hà Nội, cà phê sữa đá'),
        'pho bo ha noi, ca phe sua da',
      );
    });
  });

  group('BankParser - thông báo ngân hàng', () {
    test('Vietcombank SMS tiền vào', () {
      final p = BankParser.parse(
        'SD TK 0011004123456 +500,000VND luc 21-11-2026 10:20:11. SD 1,234,567VND. Ref MBVCB.123456.NGUYEN VAN A chuyen tien',
      )!;
      expect(p.amount, 500000);
      expect(p.type, TxType.income);
      expect(p.balance, 1234567);
      expect(p.date, DateTime(2026, 11, 21, 10, 20, 11));
      expect(p.description, contains('NGUYEN VAN A chuyen tien'));
    });

    test('Vietcombank app tiền ra', () {
      final p = BankParser.parse(
        'Số dư TK VCB 0011004123456 -45,000 VND lúc 21-11-2026 08:15:30. Số dư 1,189,567 VND. Ref 2611210815 HIGHLANDS COFFEE',
        packageName: 'com.VCB',
      )!;
      expect(p.amount, 45000);
      expect(p.type, TxType.expense);
      expect(p.balance, 1189567);
      expect(p.bank, 'Vietcombank');
      expect(p.description, contains('HIGHLANDS COFFEE'));
    });

    test('MB Bank', () {
      final p = BankParser.parse(
        'TK 0123456789|GD: +1,500,000VND 21/11/26 10:20 |SD: 3,500,000VND|ND: CTY ABC TRA LUONG T11',
      )!;
      expect(p.amount, 1500000);
      expect(p.type, TxType.income);
      expect(p.balance, 3500000);
      expect(p.description, 'CTY ABC TRA LUONG T11');
      expect(p.date, DateTime(2026, 11, 21, 10, 20));
    });

    test('Techcombank nhiều dòng', () {
      final p = BankParser.parse(
        'Tài khoản 19031234567890\nSố tiền: -120.000 VND\nSố dư: 2.880.000 VND\nNội dung: Thanh toan GRAB*A-5XYZ',
      )!;
      expect(p.amount, 120000);
      expect(p.type, TxType.expense);
      expect(p.balance, 2880000);
      expect(p.description, 'Thanh toan GRAB*A-5XYZ');
    });

    test('BIDV', () {
      final p = BankParser.parse(
        'TK1234567890 tai BIDV +200,000VND vao 09:05 21/11/2026. So du:1,700,000VND. ND: TRAN THI B chuyen tien an trua',
      )!;
      expect(p.amount, 200000);
      expect(p.type, TxType.income);
      expect(p.balance, 1700000);
      expect(p.bank, 'BIDV');
      expect(p.date, DateTime(2026, 11, 21, 9, 5));
    });

    test('VietinBank', () {
      final p = BankParser.parse(
        'Thời gian: 21/11/2026 12:30\nTài khoản: 108812345678\nGiao dịch: -65,000VND\nSố dư hiện tại: 935,000VND\nNội dung: PHUC LONG COFFEE QR',
      )!;
      expect(p.amount, 65000);
      expect(p.type, TxType.expense);
      expect(p.balance, 935000);
      expect(p.description, 'PHUC LONG COFFEE QR');
      expect(p.date, DateTime(2026, 11, 21, 12, 30));
    });

    test('TPBank PS/SD', () {
      final p = BankParser.parse(
        '(TPBank): 21/11/26;10:20\nTK: xxxx1234\nPS:-45.000VND\nSD: 1.000.000VND\nND: Thanh toan QR KATINAT',
      )!;
      expect(p.amount, 45000);
      expect(p.type, TxType.expense);
      expect(p.balance, 1000000);
      expect(p.description, 'Thanh toan QR KATINAT');
    });

    test('ACB dấu cách sau dấu +', () {
      final p = BankParser.parse(
        'ACB: TK 12345678(VND) + 3,000,000 luc 10:20 21/11/2026. So du 5,000,000. GD: CONG TY XYZ THUONG',
      )!;
      expect(p.amount, 3000000);
      expect(p.type, TxType.income);
      expect(p.balance, 5000000);
    });

    test('MoMo nhận tiền không dấu +/-', () {
      final p = BankParser.parse(
        'Bạn vừa nhận được 50.000đ từ NGUYEN VAN A',
        packageName: 'com.mservice.momotransfer',
      )!;
      expect(p.amount, 50000);
      expect(p.type, TxType.income);
      expect(p.bank, 'MoMo');
      expect(p.description, 'NGUYEN VAN A');
    });

    test('Ví thanh toán', () {
      final p = BankParser.parse(
        'Thanh toán thành công 45.000đ cho Highlands Coffee',
      )!;
      expect(p.amount, 45000);
      expect(p.type, TxType.expense);
      expect(p.description, 'Highlands Coffee');
    });

    test('Bỏ qua OTP', () {
      expect(
        BankParser.parse(
          'Ma OTP cua quy khach la 123456. Giao dich 500,000VND',
        ),
        isNull,
      );
      expect(BankParser.looksLikeTransaction('Ma OTP 123456'), isFalse);
    });

    test('Không có số tiền', () {
      expect(BankParser.parse('Chào mừng bạn đến với ứng dụng'), isNull);
    });

    test('Số thập phân kiểu 500,000.00', () {
      final p = BankParser.parse(
        'TK 123 -500,000.00 VND. SD 1,000,000.00 VND',
      )!;
      expect(p.amount, 500000);
      expect(p.balance, 1000000);
    });
  });

  group('BankParser - ảnh chụp chuyển khoản (chữ OCR)', () {
    test('Màn hình chuyển tiền thành công', () {
      const ocr = '''
10:24
Chuyển tiền thành công
500.000 VND
Thứ Sáu, 21/11/2026 10:23
Tên người nhận
LE VAN C
Tài khoản nhận
0987654321
Ngân hàng
Techcombank
Nội dung
Tra tien di choi Da Lat
Phí giao dịch
Miễn phí
''';
      final p = BankParser.parse(ocr)!;
      expect(p.amount, 500000);
      expect(p.type, TxType.expense);
      expect(p.description, 'Tra tien di choi Da Lat');
      expect(p.date, DateTime(2026, 11, 21, 10, 23));
    });

    test('Ảnh có phí và số dư', () {
      const ocr =
          'Giao dịch thành công\n-1.250.000 đ\nPhí: 2.200 đ\nSố dư khả dụng: 8.000.000 đ\nNội dung: Mua giay Shopee';
      final p = BankParser.parse(ocr)!;
      expect(p.amount, 1250000);
      expect(p.type, TxType.expense);
      expect(p.balance, 8000000);
    });

    test('Gõ nhanh khoản thu: lương, tiền đi làm', () {
      expect(BankParser.parse('Lương tháng 11 15tr')!.type, TxType.income);
      expect(BankParser.parse('lương 15.000.000')!.amount, 15000000);
      expect(BankParser.parse('tiền đi làm 500k')!.type, TxType.income);
      expect(BankParser.parse('thưởng tết 2tr')!.type, TxType.income);
      expect(BankParser.parse('grab đi làm 45k')!.type, TxType.expense);
      expect(Categorizer.hasIncomeHint('Lương tháng 11'), isTrue);
      expect(Categorizer.hasIncomeHint('Highlands'), isFalse);
      expect(
        Categorizer().categorize(
          type: TxType.income,
          description: 'tiền đi làm',
        ),
        'luong',
      );
    });

    test('Văn bản tự gõ "35k cafe"', () {
      final p = BankParser.parse('35k cafe sáng')!;
      expect(p.amount, 35000);
      expect(p.type, TxType.expense);
    });
  });

  group('Categorizer', () {
    final c = Categorizer();
    test('cafe', () {
      expect(
        c.categorize(type: TxType.expense, description: 'HIGHLANDS COFFEE'),
        'cafe',
      );
      expect(
        c.categorize(
          type: TxType.expense,
          description: 'Thanh toan QR KATINAT',
        ),
        'cafe',
      );
    });
    test('ăn uống', () {
      expect(
        c.categorize(type: TxType.expense, description: 'ShopeeFood don 123'),
        'an_uong',
      );
      expect(
        c.categorize(type: TxType.expense, description: 'Phở Thìn'),
        'an_uong',
      );
    });
    test('đi chơi', () {
      expect(
        c.categorize(
          type: TxType.expense,
          description: 'Tra tien di choi Da Lat',
        ),
        'di_choi',
      );
      expect(
        c.categorize(type: TxType.expense, description: 'CGV Vincom'),
        'di_choi',
      );
    });
    test('đi lại', () {
      expect(
        c.categorize(
          type: TxType.expense,
          description: 'Thanh toan GRAB*A-5XYZ',
        ),
        'di_lai',
      );
    });
    test('lương', () {
      expect(
        c.categorize(type: TxType.income, description: 'CTY ABC TRA LUONG T11'),
        'luong',
      );
    });
    test('chuyển tiền chung chung', () {
      expect(
        c.categorize(
          type: TxType.income,
          description: 'NGUYEN VAN A chuyen tien',
        ),
        'duoc_chuyen',
      );
      expect(
        c.categorize(type: TxType.expense, description: 'chuyen khoan cho Lan'),
        'chuyen_tien',
      );
    });
    test('cụ thể thắng chuyển tiền', () {
      expect(
        c.categorize(
          type: TxType.expense,
          description: 'chuyen tien cafe highlands',
        ),
        'cafe',
      );
    });
    test('không nhầm "com" trong tên ngân hàng', () {
      expect(
        c.categorize(type: TxType.expense, description: 'Vietcombank abc'),
        'khac_chi',
      );
    });
    test('quy tắc đã học', () {
      final key = Categorizer.learnKey('NGUYEN VAN A chuyen tien 123');
      expect(key, 'nguyen van a chuyen');
      final learned = Categorizer({key: 'nha_cua'});
      expect(
        learned.categorize(
          type: TxType.expense,
          description: 'NGUYEN VAN A chuyen tien 456',
        ),
        'nha_cua',
      );
    });
  });
}
