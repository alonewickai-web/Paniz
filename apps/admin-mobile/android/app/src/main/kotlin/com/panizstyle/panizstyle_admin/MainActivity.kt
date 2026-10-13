package com.panizstyle.panizstyle_admin

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.UUID

class MainActivity : FlutterActivity() {
    private var pickerResult: MethodChannel.Result? = null
    private val apkPickerRequest = 8401

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
    }

    @Deprecated("Android compatibility callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
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
