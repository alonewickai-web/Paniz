package com.panizstyle.panizstyle_admin

import android.content.Intent
import android.Manifest
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.provider.OpenableColumns
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.UUID

class MainActivity : FlutterFragmentActivity() {
    companion object {
        const val EXTRA_NOTIFICATION_ID = "paniz.notification.id"
    }

    private var pickerResult: MethodChannel.Result? = null
    private var biometricResult: MethodChannel.Result? = null
    private var notificationPermissionResult: MethodChannel.Result? = null
    private var notificationChannel: MethodChannel? = null
    private var pendingNotificationId: String? = null
    private val apkPickerRequest = 8401
    private val notificationPermissionRequest = 8402
    private val reportExportRequest = 8403
    private val contactImportRequest = 8404
    private var reportExportResult: MethodChannel.Result? = null
    private var reportExportBytes: ByteArray? = null
    private var contactImportResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingNotificationId = intent?.getStringExtra(EXTRA_NOTIFICATION_ID)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val id = intent.getStringExtra(EXTRA_NOTIFICATION_ID)?.trim().orEmpty()
        if (id.isNotEmpty()) {
            pendingNotificationId = id
            notificationChannel?.invokeMethod("notificationOpened", id)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "paniz/admin-updates")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "appInfo" -> result.success(appInfo())
                        "downloadPath" -> result.success(File(cacheDir, "paniz-latest.apk").absolutePath)
                        "selectApk" -> {
                            if (pickerResult != null) result.error("PICKER_BUSY", "انتخاب فایل هنوز باز است.", null)
                            else {
                                pickerResult = result
                                startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = "*/*"
                                    putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/vnd.android.package-archive", "application/octet-stream", "application/zip"))
                                }, apkPickerRequest)
                            }
                        }
                        "verifyApk" -> {
                            val file = safeCacheFile(call.argument<String>("path"))
                            val expectedHash = call.argument<String>("sha256") ?: ""
                            val expectedVersion = call.argument<Number>("versionCode")?.toLong() ?: 0L
                            Thread {
                                try {
                                    val hash = MessageDigest.getInstance("SHA-256")
                                    file.inputStream().use { stream ->
                                        val buffer = ByteArray(65536)
                                        while (true) { val count = stream.read(buffer); if (count < 0) break; hash.update(buffer, 0, count) }
                                    }
                                    val digest = hash.digest().joinToString("") { "%02x".format(it) }
                                    if (digest != expectedHash.lowercase()) throw IllegalArgumentException("فایل دانلودشده کامل نیست. دوباره دانلود کنید.")
                                    val info = inspectApk(file)
                                    if (versionCode(info) != expectedVersion) throw IllegalArgumentException("شمارهٔ نسخهٔ فایل با اطلاعات سرور برابر نیست.")
                                    if (versionCode(info) <= versionCode(installedPackage())) throw IllegalArgumentException("این نسخه از برنامهٔ نصب‌شده جدیدتر نیست.")
                                    runOnUiThread { result.success(true) }
                                } catch (error: Exception) { runOnUiThread { result.error("APK_VERIFY_FAILED", error.message, null) } }
                            }.start()
                        }
                        "installPermission" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
                                startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                                result.success(false)
                            } else result.success(true)
                        }
                        "installApk" -> {
                            val file = safeCacheFile(call.argument<String>("path"))
                            val expectedHash = call.argument<String>("sha256") ?: ""
                            val expectedVersion = call.argument<Number>("versionCode")?.toLong() ?: 0L
                            val hash = MessageDigest.getInstance("SHA-256")
                            file.inputStream().use { stream ->
                                val buffer = ByteArray(65536)
                                while (true) { val count = stream.read(buffer); if (count < 0) break; hash.update(buffer, 0, count) }
                            }
                            val digest = hash.digest().joinToString("") { "%02x".format(it) }
                            if (expectedHash.isEmpty() || digest != expectedHash.lowercase()) throw IllegalArgumentException("فایل بروزرسانی پس از بررسی تغییر کرده است. دوباره دانلود کنید.")
                            val info = inspectApk(file)
                            if (versionCode(info) != expectedVersion || versionCode(info) <= versionCode(installedPackage())) throw IllegalArgumentException("این نسخه با اطلاعات بروزرسانی برابر نیست یا جدیدتر از نسخهٔ فعلی نیست.")
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
                                result.error("INSTALL_PERMISSION_REQUIRED", "اجازهٔ نصب بروزرسانی را برای برنامه فعال کنید.", null)
                            } else {
                                val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
                                startActivity(Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, "application/vnd.android.package-archive")
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                })
                                result.success(true)
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) { result.error("UPDATE_ERROR", error.message, null) }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "paniz/admin-reports")
            .setMethodCallHandler { call, result ->
                if (call.method == "selectContactFile") {
                    if (contactImportResult != null) { result.error("IMPORT_BUSY", "پنجرهٔ انتخاب فایل هنوز باز است.", null); return@setMethodCallHandler }
                    try {
                        contactImportResult = result
                        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("text/csv", "text/plain", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "application/octet-stream"))
                        }, contactImportRequest)
                    } catch (error: Exception) {
                        contactImportResult = null
                        result.error("IMPORT_FAILED", "انتخاب فایل باز نشد.", null)
                    }
                    return@setMethodCallHandler
                }
                if (call.method != "saveReport") { result.notImplemented(); return@setMethodCallHandler }
                if (reportExportResult != null) { result.error("EXPORT_BUSY", "پنجرهٔ ذخیرهٔ گزارش هنوز باز است.", null); return@setMethodCallHandler }
                val bytes = call.argument<ByteArray>("bytes")
                val filename = call.argument<String>("filename") ?: "paniz-report.csv"
                val mimeType = call.argument<String>("mimeType") ?: "text/csv"
                if (bytes == null || bytes.size > 20 * 1024 * 1024 || !Regex("^[A-Za-z0-9._-]+\\.(csv|xlsx)$").matches(filename)) {
                    result.error("INVALID_REPORT", "فایل گزارش معتبر نیست.", null)
                    return@setMethodCallHandler
                }
                try {
                    reportExportResult = result
                    reportExportBytes = bytes
                    startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = mimeType
                        putExtra(Intent.EXTRA_TITLE, filename)
                    }, reportExportRequest)
                } catch (error: Exception) {
                    reportExportResult = null
                    reportExportBytes = null
                    result.error("EXPORT_FAILED", "ذخیرهٔ گزارش باز نشد.", null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "paniz/admin-biometric")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(
                        BiometricManager.from(this).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS,
                    )
                    "authenticate" -> authenticateBiometric(result)
                    else -> result.notImplemented()
                }
            }

        notificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "paniz/admin-notifications")
        notificationChannel?.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "takePendingNotification" -> {
                            result.success(pendingNotificationId)
                            pendingNotificationId = null
                        }
                        "requestPermission" -> requestNotificationPermission(result)
                        "hasPermission" -> result.success(canShowNotifications())
                        "hasBatteryOptimizationExemption" ->
                            result.success(hasBatteryOptimizationExemption())
                        "requestBatteryOptimizationExemption" -> {
                            if (hasBatteryOptimizationExemption()) {
                                result.success(true)
                            } else {
                                val intent = Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName"),
                                )
                                if (intent.resolveActivity(packageManager) == null) {
                                    result.error(
                                        "BATTERY_SETTINGS_UNAVAILABLE",
                                        "درخواست تنظیم محدودیت باتری در این نسخهٔ اندروید در دسترس نیست.",
                                        null,
                                    )
                                } else {
                                    startActivity(intent)
                                    result.success(true)
                                }
                            }
                        }
                        "startMonitoring" -> {
                            val apiBaseUrl = call.argument<String>("apiBaseUrl")?.trim().orEmpty()
                            val accessToken = call.argument<String>("accessToken")?.trim().orEmpty()
                            val deviceId = call.argument<String>("deviceId")?.trim().orEmpty()
                            val parsedApi = Uri.parse(apiBaseUrl)
                            if (parsedApi.scheme != "https" || parsedApi.host.isNullOrBlank()) throw IllegalArgumentException("نشانی امن سرور اعلان معتبر نیست.")
                            if (accessToken.length < 32 || !deviceId.matches(Regex("^[0-9a-fA-F-]{36}$"))) throw IllegalArgumentException("نشست یا شناسهٔ دستگاه معتبر نیست.")
                            NotificationMonitorService.start(
                                this,
                                apiBaseUrl,
                                accessToken,
                                deviceId,
                                call.argument<Boolean>("soundEnabled") ?: false,
                                call.argument<Boolean>("vibrationEnabled") ?: true,
                            )
                            result.success(true)
                        }
                        "stopMonitoring" -> {
                            NotificationMonitorService.stop(this)
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("NOTIFICATION_MONITOR_ERROR", error.message ?: "سرویس اعلان اجرا نشد.", null)
                }
            }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(canShowNotifications())
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            result.success(canShowNotifications())
            return
        }
        if (notificationPermissionResult != null) {
            result.error("NOTIFICATION_PERMISSION_BUSY", "درخواست اجازهٔ اعلان دیگری در حال انجام است.", null)
            return
        }
        notificationPermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationPermissionRequest)
    }

    @Deprecated("Android compatibility callback")
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != notificationPermissionRequest) return
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED && canShowNotifications()
        notificationPermissionResult?.success(granted)
        notificationPermissionResult = null
    }

    private fun canShowNotifications(): Boolean {
        val notificationsEnabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
        val runtimePermissionGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        return notificationsEnabled && runtimePermissionGranted
    }

    private fun hasBatteryOptimizationExemption(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun authenticateBiometric(result: MethodChannel.Result) {
        if (biometricResult != null) {
            result.error("BIOMETRIC_BUSY", "درخواست تأیید دیگری در حال انجام است.", null)
            return
        }
        if (BiometricManager.from(this).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) != BiometricManager.BIOMETRIC_SUCCESS) {
            result.success(false)
            return
        }
        biometricResult = result
        val prompt = BiometricPrompt(this, ContextCompat.getMainExecutor(this), object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                biometricResult?.success(true)
                biometricResult = null
            }

            override fun onAuthenticationFailed() {
                // Keep the system prompt open so the user can retry.
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                biometricResult?.success(false)
                biometricResult = null
            }
        })
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("ورود به PANIZ Admin")
            .setSubtitle("برای ادامه، اثر انگشتت را تأیید کن")
            .setNegativeButtonText("لغو")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .build()
        prompt.authenticate(promptInfo)
    }

    @Deprecated("Android compatibility callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == contactImportRequest) {
            val result = contactImportResult ?: return
            contactImportResult = null
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null) { result.success(null); return }
            Thread {
                try {
                    val name = contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                        val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (cursor.moveToFirst() && index >= 0) cursor.getString(index) else "contacts.csv"
                    } ?: "contacts.csv"
                    val bytes = contentResolver.openInputStream(uri)?.use { input ->
                        val output = java.io.ByteArrayOutputStream()
                        val buffer = ByteArray(16 * 1024)
                        var size = 0
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            size += count
                            if (size > 10 * 1024 * 1024) throw IllegalArgumentException("حجم فایل نباید بیشتر از ۱۰ مگابایت باشد.")
                            output.write(buffer, 0, count)
                        }
                        output.toByteArray()
                    } ?: throw IllegalArgumentException("فایل انتخاب‌شده قابل خواندن نیست.")
                    runOnUiThread { result.success(mapOf("name" to name, "bytes" to bytes)) }
                } catch (error: Exception) {
                    runOnUiThread { result.error("IMPORT_FAILED", error.message ?: "خواندن فایل انجام نشد.", null) }
                }
            }.start()
            return
        }
        if (requestCode == reportExportRequest) {
            val result = reportExportResult ?: return
            val bytes = reportExportBytes
            reportExportResult = null
            reportExportBytes = null
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null || bytes == null) { result.success(false); return }
            Thread {
                try {
                    contentResolver.openOutputStream(uri, "w")?.use { it.write(bytes) }
                        ?: throw IllegalArgumentException("فایل قابل نوشتن نیست.")
                    runOnUiThread { result.success(true) }
                } catch (error: Exception) {
                    runOnUiThread { result.error("EXPORT_FAILED", "ذخیرهٔ گزارش انجام نشد.", null) }
                }
            }.start()
            return
        }
        if (requestCode != apkPickerRequest) return
        val result = pickerResult ?: return
        pickerResult = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) { result.success(null); return }
        Thread {
            val file = File(cacheDir, "publication-${UUID.randomUUID()}.apk")
            try {
                contentResolver.openInputStream(uri)?.use { input ->
                    file.outputStream().use { output ->
                        val buffer = ByteArray(65536)
                        var size = 0L
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            size += count
                            if (size > 200L * 1024 * 1024) throw IllegalArgumentException("حجم APK نباید بیشتر از ۲۰۰ مگابایت باشد.")
                            output.write(buffer, 0, count)
                        }
                    }
                } ?: throw IllegalArgumentException("فایل انتخاب‌شده قابل خواندن نیست.")
                val info = inspectApk(file)
                val response = mapOf("path" to file.absolutePath, "versionName" to (info.versionName ?: ""), "versionCode" to versionCode(info), "size" to file.length())
                runOnUiThread { result.success(response) }
            } catch (error: Exception) {
                file.delete()
                runOnUiThread { result.error("APK_SELECTION_FAILED", error.message, null) }
            }
        }.start()
    }

    @Suppress("DEPRECATION")
    private fun flags(): Int = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES

    @Suppress("DEPRECATION")
    private fun installedPackage(): PackageInfo = packageManager.getPackageInfo(packageName, flags())

    @Suppress("DEPRECATION")
    private fun versionCode(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode else info.versionCode.toLong()

    @Suppress("DEPRECATION")
    private fun signers(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.signingInfo?.apkContentsSigners else info.signatures
        return signatures?.map { MessageDigest.getInstance("SHA-256").digest(it.toByteArray()).joinToString("") { byte -> "%02x".format(byte) } }?.toSet() ?: emptySet()
    }

    @Suppress("DEPRECATION")
    private fun inspectApk(file: File): PackageInfo {
        val info = packageManager.getPackageArchiveInfo(file.absolutePath, flags()) ?: throw IllegalArgumentException("این فایل APK معتبر نیست.")
        if (info.packageName != packageName) throw IllegalArgumentException("این فایل مربوط به برنامهٔ PANIZ نیست.")
        val expected = signers(installedPackage())
        if (expected.isEmpty() || signers(info) != expected) throw IllegalArgumentException("امضای این نسخه با برنامهٔ نصب‌شده یکسان نیست.")
        return info
    }

    private fun safeCacheFile(path: String?): File {
        val file = File(path ?: "").canonicalFile
        if (!file.isFile || file.parentFile != cacheDir.canonicalFile) throw IllegalArgumentException("فایل بروزرسانی پیدا نشد.")
        return file
    }

    private fun appInfo(): Map<String, Any> {
        val info = installedPackage()
        return mapOf("versionName" to (info.versionName ?: ""), "versionCode" to versionCode(info),
            "canInstall" to (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()))
    }
}
