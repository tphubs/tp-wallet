package com.tphubs.tp_wallet

import android.app.Notification
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

/**
 * Lắng nghe thông báo từ app ngân hàng / ví điện tử.
 *
 * Chỉ giữ lại thông báo trông giống biến động số dư, xếp vào hàng đợi trong
 * SharedPreferences. Phần Flutter lấy hàng đợi ra để đọc và thêm giao dịch.
 * Mọi thứ nằm trên máy, không gửi đi đâu.
 */
class BankNotificationService : NotificationListenerService() {

    companion object {
        const val PREFS = "tp_wallet_native"
        const val KEY_QUEUE = "notification_queue"
        private const val MAX_QUEUE = 500

        /** Được MainActivity gán khi app đang mở để báo có thông báo mới. */
        @Volatile
        var listener: (() -> Unit)? = null

        private val recent = ArrayDeque<Int>()

        /** Gói của các app ngân hàng / ví phổ biến ở Việt Nam. */
        val BANK_PACKAGES = setOf(
            "com.VCB", "vn.com.techcombank.bb.app", "com.mbmobile", "com.vnpay.bidv",
            "com.vietinbank.ipay", "com.vnpay.Agribank3g", "mobile.acb.com.vn",
            "com.tpb.mb.gprsandroid", "com.vnpay.vpbankonline", "com.vpbank.neo",
            "com.sacombank.ewallet", "com.vib.myvib2", "com.vnpay.hdbank",
            "vn.shb.mbanking", "vn.com.ocb.awe", "vn.com.msb.smartBanking",
            "xyz.be.cake", "io.lifestyle.plus", "com.mservice.momotransfer",
            "vn.com.vng.zalopay", "vn.shopeepay.app"
        )

        /** Ứng dụng chat: không bao giờ đọc. */
        private val IGNORED_PACKAGES = setOf(
            "com.zing.zalo", "com.facebook.orca", "com.facebook.katana",
            "org.telegram.messenger", "com.whatsapp", "com.viber.voip",
            "com.instagram.android", "com.discord", "com.skype.raider"
        )

        // Có số tiền: "+500,000", "-45.000", "500.000 VND", "50.000đ"
        private val AMOUNT = Regex(
            "([+-]\\s?\\d{1,3}([.,]\\d{3})+)|(\\d{1,3}([.,]\\d{3})+\\s?(VND|VNĐ|đ|₫|vnd))",
            RegexOption.IGNORE_CASE
        )
        private val BANK_WORDS = Regex(
            "số dư|so du|\\bSD\\b|biến động|bien dong|giao dịch|giao dich|\\bGD\\b|" +
                "nhận được|nhan duoc|thanh toán|thanh toan|chuyển tiền|chuyen tien|" +
                "tài khoản|tai khoan|\\bTK\\b|\\bPS\\b",
            RegexOption.IGNORE_CASE
        )
        private val OTP = Regex("\\bOTP\\b|mã xác thực|ma xac thuc|mật khẩu|mat khau", RegexOption.IGNORE_CASE)

        fun looksLikeBankMessage(pkg: String, text: String): Boolean {
            if (OTP.containsMatchIn(text)) return false
            if (!AMOUNT.containsMatchIn(text)) return false
            if (pkg in BANK_PACKAGES) return true
            return BANK_WORDS.containsMatchIn(text)
        }

        fun drain(context: Context): List<Map<String, Any>> {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            synchronized(this) {
                val raw = prefs.getString(KEY_QUEUE, "[]") ?: "[]"
                prefs.edit().putString(KEY_QUEUE, "[]").apply()
                val arr = JSONArray(raw)
                return (0 until arr.length()).map { i ->
                    val o = arr.getJSONObject(i)
                    mapOf(
                        "package" to o.optString("package"),
                        "title" to o.optString("title"),
                        "text" to o.optString("text"),
                        "postedAt" to o.optLong("postedAt")
                    )
                }
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val n = sbn ?: return
        val pkg = n.packageName ?: return
        if (pkg == packageName || pkg in IGNORED_PACKAGES) return
        if (n.isOngoing) return

        val extras = n.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val big = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.joinToString("\n") { it.toString() }
        val text = big ?: lines ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val full = "$title\n$text"
        if (!looksLikeBankMessage(pkg, full)) return

        // Bỏ thông báo trùng (app ngân hàng hay cập nhật lại cùng một thông báo).
        val h = (pkg + text).hashCode()
        synchronized(recent) {
            if (recent.contains(h)) return
            recent.addLast(h)
            if (recent.size > 50) recent.removeFirst()
        }

        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        synchronized(Companion) {
            val arr = JSONArray(prefs.getString(KEY_QUEUE, "[]") ?: "[]")
            arr.put(JSONObject().apply {
                put("package", pkg)
                put("title", title)
                put("text", text)
                put("postedAt", n.postTime)
            })
            val trimmed = if (arr.length() > MAX_QUEUE) {
                JSONArray().also { out ->
                    for (i in arr.length() - MAX_QUEUE until arr.length()) out.put(arr.get(i))
                }
            } else arr
            prefs.edit().putString(KEY_QUEUE, trimmed.toString()).apply()
        }

        listener?.let { l -> Handler(Looper.getMainLooper()).post { l() } }
    }
}
