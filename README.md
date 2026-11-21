# TP Wallet

App quản lý thu chi cá nhân cho Android và iPhone (Flutter). Tiếng Việt, tiền VND.

## Tính năng (bản 1.0)

- **Tự đọc thông báo ngân hàng (Android):** bật "Truy cập thông báo" cho TP Wallet, mỗi
  thông báo biến động số dư từ app ngân hàng / ví (Vietcombank, Techcombank, MB, BIDV,
  VietinBank, ACB, TPBank, MoMo, ...) sẽ tự thành một giao dịch thu hoặc chi.
- **Đọc ảnh chụp chuyển khoản (Android + iPhone):** Thêm > Từ ảnh chụp chuyển khoản. Chữ
  trong ảnh được đọc ngay trên máy (Google ML Kit), không gửi ảnh đi đâu.
- **Dán tin nhắn / gõ nhanh:** dán SMS ngân hàng, hoặc gõ "35k cafe".
- **Tự phân loại:** Cafe, Ăn uống, Đi chơi, Đi lại, Mua sắm, Hóa đơn, Nhà cửa, Sức khỏe,
  Học tập, Chuyển tiền, Lương, Thưởng, Hoàn tiền... Khi bạn sửa hạng mục của một giao dịch
  tự thêm, app nhớ và lần sau tự xếp đúng.
- Giao dịch tự thêm được đánh dấu "cần xem lại" để bạn xác nhận.
- Tổng thu / chi / còn lại theo tháng, báo cáo theo hạng mục (biểu đồ tròn).
- Dữ liệu lưu trên máy (SQLite). Sao lưu đám mây: sẽ thêm (Firebase).

## Bản web (dùng trên iPhone không cần App Store)

Cùng một mã nguồn, build ra web và tự đưa lên GitHub Pages
(`.github/workflows/deploy-web.yml`). Mở link bằng Safari > nút Chia sẻ >
"Thêm vào MH chính" để có biểu tượng như app thật.

- Dữ liệu lưu trong bộ nhớ của trình duyệt trên máy đó.
- Đọc ảnh chuyển khoản bằng Tesseract.js ngay trong trình duyệt (lần đầu tải dữ liệu
  tiếng Việt vài MB).
- Mở link kèm `?text=<tin nhắn ngân hàng>` sẽ tự thêm giao dịch (dùng cho Phím tắt).

## Giới hạn trên iPhone

iOS không cho app đọc thông báo của app khác, nên trên iPhone dùng ảnh chụp chuyển khoản
hoặc dán tin nhắn. (Bước sau: phím tắt Shortcuts tự gửi SMS ngân hàng vào app.)

## Cấu trúc mã

- `lib/services/bank_parser.dart`: đọc số tiền, thu/chi, nội dung, ngày, số dư từ văn bản.
- `lib/services/categorizer.dart`: tự gán hạng mục + học từ lần sửa.
- `lib/models/category.dart`: danh sách hạng mục và từ khóa.
- `android/.../BankNotificationService.kt`: dịch vụ Android nghe thông báo ngân hàng.
- `test/`: kiểm thử (chạy `flutter test`).

## Chạy thử

```bash
flutter pub get
flutter test
flutter run            # cắm điện thoại Android hoặc mở máy ảo
flutter build apk      # tạo file cài đặt Android
```

Khi đẩy lên GitHub, workflow `.github/workflows/build-apk.yml` tự build file APK
(tab Actions > lần chạy mới nhất > Artifacts > tp-wallet-apk).

### Lưu ý khi cài APK ngoài (không qua Google Play)

Android 13+ có thể chặn "Truy cập thông báo" với app cài ngoài. Vào Cài đặt > Ứng dụng >
TP Wallet > nút ⋮ góc trên > "Cho phép cài đặt bị hạn chế", rồi bật lại.

### iPhone

Cần máy Mac có Xcode. Build: `flutter build ios`. Để chia sẻ cho người khác cần tài khoản
Apple Developer (99 USD/năm) để đưa lên TestFlight / App Store.
