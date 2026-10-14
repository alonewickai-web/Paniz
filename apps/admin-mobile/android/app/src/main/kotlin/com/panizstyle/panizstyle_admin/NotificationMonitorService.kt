package com.panizstyle.panizstyle_admin

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.util.Base64
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okio.ByteString
import org.json.JSONObject
import java.io.IOException
import java.net.URLEncoder
import java.security.KeyStore
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.core.app.NotificationManagerCompat

internal data class MonitorCredentials(
    val accessToken: String,
    val apiBaseUrl: String,
    val deviceId: String,
    val soundEnabled: Boolean,
    val vibrationEnabled: Boolean,
)

internal object MonitorCredentialStore {
    private const val PREFS = "paniz_notification_monitor"
    private const val KEY_ALIAS = "paniz.notification.monitor.token"

    fun save(context: Context, token: String, apiBaseUrl: String, deviceId: String, sound: Boolean, vibration: Boolean) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val encrypted = cipher.doFinal(token.toByteArray(Charsets.UTF_8))
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("token", Base64.encodeToString(encrypted, Base64.NO_WRAP))
            .putString("iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .putString("api", apiBaseUrl)
            .putString("device", deviceId)
            .putBoolean("sound", sound)
            .putBoolean("vibration", vibration)
            .putBoolean("enabled", true)
            .apply()
    }

    fun read(context: Context): MonitorCredentials? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val encoded = prefs.getString("token", null) ?: return null
        val iv = prefs.getString("iv", null) ?: return null
        return try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, Base64.decode(iv, Base64.NO_WRAP)))
            val token = String(cipher.doFinal(Base64.decode(encoded, Base64.NO_WRAP)), Charsets.UTF_8)
            MonitorCredentials(
                token,
                prefs.getString("api", "") ?: "",
                prefs.getString("device", "") ?: "",
                prefs.getBoolean("sound", false),
                prefs.getBoolean("vibration", true),
            ).takeIf { it.accessToken.isNotBlank() && it.apiBaseUrl.isNotBlank() && it.deviceId.isNotBlank() }
        } catch (_: Exception) {
            clear(context)
            null
        }
    }

    fun isEnabled(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("enabled", false)

    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    private fun secretKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = store.getKey(KEY_ALIAS, null) as? SecretKey
        if (existing != null) return existing
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        return generator.generateKey()
    }
}

class NotificationMonitorService : Service() {
    companion object {
        const val ACTION_START = "com.panizstyle.admin.notifications.START"
        const val ACTION_STOP = "com.panizstyle.admin.notifications.STOP"
        private const val FOREGROUND_ID = 781
        private const val MONITOR_CHANNEL = "paniz_notification_monitor"

        fun start(context: Context, apiBaseUrl: String, token: String, deviceId: String, sound: Boolean, vibration: Boolean) {
            val intent = Intent(context, NotificationMonitorService::class.java).apply {
                action = ACTION_START
                putExtra("apiBaseUrl", apiBaseUrl)
                putExtra("accessToken", token)
                putExtra("deviceId", deviceId)
                putExtra("soundEnabled", sound)
                putExtra("vibrationEnabled", vibration)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent) else context.startService(intent)
        }

        fun stop(context: Context) {
            MonitorCredentialStore.clear(context)
            context.stopService(Intent(context, NotificationMonitorService::class.java))
        }
    }

    private val http = OkHttpClient.Builder()
        .pingInterval(25, TimeUnit.SECONDS)
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()
    private var worker: ScheduledExecutorService? = null
    private var socket: okhttp3.WebSocket? = null
    @Volatile private var running = false
    @Volatile private var authenticating = false
    @Volatile private var syncQueued = false
    @Volatile private var syncAgain = false
    @Volatile private var credentialGeneration = 0L
    private var retryDelaySeconds = 2L

    override fun onCreate() {
        super.onCreate()
        createMonitorChannel()
        startInForeground("در حال آماده‌سازی اتصال امن")
        worker = Executors.newSingleThreadScheduledExecutor()
        running = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (!canShowNotifications()) {
            MonitorCredentialStore.clear(this)
            stopSelf()
            return START_NOT_STICKY
        }
        val token = intent?.getStringExtra("accessToken")
        val api = intent?.getStringExtra("apiBaseUrl")
        val device = intent?.getStringExtra("deviceId")
        val suppliedCredentials = !token.isNullOrBlank() && !api.isNullOrBlank() && !device.isNullOrBlank()
        if (suppliedCredentials) {
            val previous = MonitorCredentialStore.read(this)
            val changed = previous == null || previous.accessToken != token || previous.apiBaseUrl != api || previous.deviceId != device
            if (changed) {
                credentialGeneration++
                val oldSocket = socket
                socket = null
                authenticating = false
                retryDelaySeconds = 2
                oldSocket?.cancel()
            }
            MonitorCredentialStore.save(
                this, token!!, api!!, device!!,
                intent?.getBooleanExtra("soundEnabled", false) ?: false,
                intent?.getBooleanExtra("vibrationEnabled", true) ?: true,
            )
            if (socket == null) {
                if (!changed) authenticating = false
            }
        }
        if (worker == null) worker = Executors.newSingleThreadScheduledExecutor()
        running = true
        if (socket == null) worker?.execute { connect() }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun connect() {
        if (!running || authenticating) return
        val credentials = MonitorCredentialStore.read(this)
        if (credentials == null) {
            updateMonitorStatus("برای اتصال دوباره، برنامه را باز کنید")
            return
        }
        authenticating = true
        val attemptGeneration = credentialGeneration
        try {
            val ticketResponse = execute(
                Request.Builder()
                    .url(apiUrl(credentials, "admin/notifications/socket-ticket"))
                    .header("Authorization", "Bearer ${credentials.accessToken}")
                    .post(JSONObject().put("deviceId", credentials.deviceId).toString().toRequestBody(JSON))
                    .build(),
            )
            val ticket = ticketResponse.optJSONObject("data")?.optString("ticket").orEmpty()
            if (ticket.isBlank()) throw IOException("ticket unavailable")
            if (attemptGeneration != credentialGeneration) {
                authenticating = false
                connect()
                return
            }
            val socketUrl = webSocketUrl(credentials)
            val request = Request.Builder().url(socketUrl).header("Authorization", "Bearer $ticket").build()
            socket = http.newWebSocket(request, object : okhttp3.WebSocketListener() {
                override fun onOpen(webSocket: okhttp3.WebSocket, response: Response) {
                    if (socket !== webSocket) {
                        webSocket.cancel()
                        return
                    }
                    retryDelaySeconds = 2
                    authenticating = false
                    updateMonitorStatus("اتصال اعلان‌ها برقرار است")
                    scheduleSync()
                }

                override fun onMessage(webSocket: okhttp3.WebSocket, text: String) {
                    try {
                        if (JSONObject(text).optString("type") == "notification_available") scheduleSync()
                    } catch (_: Exception) { }
                }

                override fun onMessage(webSocket: okhttp3.WebSocket, bytes: ByteString) = Unit

                override fun onClosing(webSocket: okhttp3.WebSocket, code: Int, reason: String) {
                    webSocket.close(code, reason)
                }

                override fun onClosed(webSocket: okhttp3.WebSocket, code: Int, reason: String) {
                    if (socket !== webSocket) return
                    socket = null
                    authenticating = false
                    if (code == 1008) {
                        MonitorCredentialStore.clear(this@NotificationMonitorService)
                        stopSelf()
                        return
                    }
                    scheduleReconnect("اتصال اعلان‌ها در حال بازیابی است")
                }

                override fun onFailure(webSocket: okhttp3.WebSocket, error: Throwable, response: Response?) {
                    if (socket !== webSocket) return
                    socket = null
                    authenticating = false
                    if (response?.code == 401) {
                        authenticating = true
                        updateMonitorStatus("نشست منقضی شد؛ برنامه را باز کنید")
                    } else {
                        scheduleReconnect("اتصال اعلان‌ها قطع شد؛ تلاش دوباره انجام می‌شود")
                    }
                }
            })
        } catch (error: ApiUnauthorizedException) {
            if (attemptGeneration != credentialGeneration) {
                authenticating = false
                connect()
                return
            }
            authenticating = true
            updateMonitorStatus("نشست منقضی شد؛ برنامه را باز کنید")
        } catch (_: Exception) {
            if (attemptGeneration != credentialGeneration) {
                authenticating = false
                connect()
                return
            }
            authenticating = false
            scheduleReconnect("اتصال اعلان‌ها برقرار نشد؛ تلاش دوباره انجام می‌شود")
        }
    }

    private fun scheduleSync() {
        val executor = worker ?: return
        synchronized(this) {
            if (!running) return
            if (syncQueued) {
                syncAgain = true
                return
            }
            syncQueued = true
        }
        executor.execute {
            var repeat: Boolean
            do {
                synchronized(this) { syncAgain = false }
                try { syncMissedNotifications() } catch (_: Exception) { }
                repeat = synchronized(this) {
                    if (syncAgain && running) true else {
                        syncQueued = false
                        false
                    }
                }
            } while (repeat)
        }
    }

    private fun syncMissedNotifications() {
        val credentials = MonitorCredentialStore.read(this) ?: return
        var pages = 0
        while (running && pages < 10) {
            pages++
            val result = try {
                execute(
                    Request.Builder()
                        .url(apiUrl(credentials, "admin/notifications/sync?deviceId=${URLEncoder.encode(credentials.deviceId, "UTF-8")}&limit=100"))
                        .header("Authorization", "Bearer ${credentials.accessToken}")
                        .get()
                        .build(),
                )
            } catch (_: ApiUnauthorizedException) {
                authenticating = true
                updateMonitorStatus("نشست منقضی شد؛ برنامه را باز کنید")
                return
            } catch (_: Exception) { return }
            val rows = result.optJSONArray("data") ?: return
            if (rows.length() == 0) return
            var acknowledged = 0
            for (index in 0 until rows.length()) {
                if (!running) return
                if (!canShowNotifications()) {
                    MonitorCredentialStore.clear(this)
                    stopSelf()
                    return
                }
                val item = rows.optJSONObject(index) ?: continue
                val id = item.optString("id")
                val type = item.optString("type")
                if (id.isBlank()) continue
                postSafeNotification(id, type, credentials)
                try {
                    execute(
                        Request.Builder()
                            .url(apiUrl(credentials, "admin/notifications/${URLEncoder.encode(id, "UTF-8")}/ack"))
                            .header("Authorization", "Bearer ${credentials.accessToken}")
                            .patch(JSONObject().put("deviceId", credentials.deviceId).toString().toRequestBody(JSON))
                            .build(),
                    )
                    acknowledged++
                } catch (_: ApiUnauthorizedException) {
                    authenticating = true
                    updateMonitorStatus("نشست منقضی شد؛ برنامه را باز کنید")
                    return
                } catch (_: Exception) { return }
            }
            if (acknowledged == 0 || rows.length() < 100) return
        }
    }

    private fun postSafeNotification(id: String, type: String, credentials: MonitorCredentials) {
        val (title, body) = when (type) {
            "new_order" -> "سفارش جدید پانیذ" to "یک سفارش تازه برای بررسی ثبت شد."
            "customer_message" -> "پیام تازه در پشتیبانی" to "برای مشاهدهٔ پیام، برنامه را باز کنید."
            "rubika_message" -> "پیام تازه در روبیکا" to "برای مشاهدهٔ پیام، برنامه را باز کنید."
            "admin_message" -> "پیام تازهٔ مدیران" to "برای مشاهدهٔ پیام، برنامه را باز کنید."
            "app_update" -> "نسخهٔ تازهٔ برنامه" to "نسخهٔ جدیدی برای مدیریت فروشگاه آماده است."
            "payment_success", "payment_failed" -> "به‌روزرسانی پرداخت" to "وضعیت پرداخت یک سفارش تغییر کرده است."
            "low_stock" -> "هشدار موجودی" to "موجودی یکی از کالاها نیاز به بررسی دارد."
            "security_alert" -> "هشدار امنیتی" to "یک رویداد امنیتی نیاز به بررسی دارد."
            "server_alert" -> "وضعیت سرویس" to "وضعیت یکی از سرویس‌ها تغییر کرده است."
            else -> "اعلان تازهٔ پانیذ" to "برای مشاهدهٔ جزئیات، برنامه را باز کنید."
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = alertChannel(credentials.soundEnabled, credentials.vibrationEnabled)
        val tap = PendingIntent.getActivity(
            this, id.hashCode(), Intent(this, MainActivity::class.java)
                .putExtra(MainActivity.EXTRA_NOTIFICATION_ID, id)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = notificationBuilder(channelId)
            .setSmallIcon(R.drawable.ic_stat_paniz)
            .setLargeIcon(BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher))
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(tap)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .build()
        manager.notify("paniz-notification-$id", 0, notification)
    }

    private fun execute(request: Request): JSONObject {
        http.newCall(request).execute().use { response ->
            if (response.code == 401) throw ApiUnauthorizedException()
            if (!response.isSuccessful) throw IOException("API ${response.code}")
            val raw = response.body?.string().orEmpty()
            return if (raw.isBlank()) JSONObject() else JSONObject(raw)
        }
    }

    private fun canShowNotifications(): Boolean {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val runtimePermissionGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED
        return NotificationManagerCompat.from(this).areNotificationsEnabled() && runtimePermissionGranted
    }

    private fun apiUrl(credentials: MonitorCredentials, route: String): String = credentials.apiBaseUrl.trimEnd('/') + "/" + route

    private fun webSocketUrl(credentials: MonitorCredentials): String {
        val base = credentials.apiBaseUrl.trimEnd('/') + "/admin/notifications/socket"
        return when {
            base.startsWith("https://") -> "wss://${base.removePrefix("https://")}"
            base.startsWith("http://") -> "ws://${base.removePrefix("http://")}"
            else -> throw IOException("Secure API address required")
        }
    }

    private fun scheduleReconnect(status: String) {
        updateMonitorStatus(status)
        val seconds = retryDelaySeconds
        retryDelaySeconds = (retryDelaySeconds * 2).coerceAtMost(60)
        worker?.schedule({ connect() }, seconds, TimeUnit.SECONDS)
    }

    private fun startInForeground(status: String) {
        val notification = notificationBuilder(MONITOR_CHANNEL)
            .setSmallIcon(android.R.drawable.stat_notify_sync_noanim)
            .setContentTitle("مانیتورینگ اعلان‌های پانیذ")
            .setContentText(status)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setContentIntent(appPendingIntent())
            .build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(FOREGROUND_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(FOREGROUND_ID, notification)
    }

    private fun updateMonitorStatus(status: String) {
        if (!running && worker != null) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = notificationBuilder(MONITOR_CHANNEL)
            .setSmallIcon(android.R.drawable.stat_notify_sync_noanim)
            .setContentTitle("مانیتورینگ اعلان‌های پانیذ")
            .setContentText(status)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setContentIntent(appPendingIntent())
            .build()
        manager.notify(FOREGROUND_ID, notification)
    }

    private fun appPendingIntent(): PendingIntent = PendingIntent.getActivity(
        this, FOREGROUND_ID, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun notificationBuilder(channelId: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, channelId) else Notification.Builder(this)

    private fun createMonitorChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(NotificationChannel(MONITOR_CHANNEL, "اتصال اعلان‌های پانیذ", NotificationManager.IMPORTANCE_LOW).apply {
            description = "وضعیت اتصال سرویس اعلان اختصاصی"
            setShowBadge(false)
        })
    }

    private fun alertChannel(sound: Boolean, vibration: Boolean): String {
        val id = "paniz_admin_alerts_${if (sound) "sound" else "quiet"}_${if (vibration) "vibration" else "still"}"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(id, "اعلان‌های مدیریتی پانیذ", if (sound || vibration) NotificationManager.IMPORTANCE_DEFAULT else NotificationManager.IMPORTANCE_LOW).apply {
                description = "اعلان سفارش‌ها و پیام‌های مدیریتی"
                enableVibration(vibration)
                if (!sound) setSound(null, null) else setSound(Uri.parse("content://settings/system/notification_sound"), AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build())
            }
            manager.createNotificationChannel(channel)
        }
        return id
    }

    override fun onDestroy() {
        running = false
        socket?.cancel()
        socket = null
        worker?.shutdownNow()
        worker = null
        if (!MonitorCredentialStore.isEnabled(this)) MonitorCredentialStore.clear(this)
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}

private class ApiUnauthorizedException : IOException()

private val JSON = "application/json; charset=utf-8".toMediaType()
