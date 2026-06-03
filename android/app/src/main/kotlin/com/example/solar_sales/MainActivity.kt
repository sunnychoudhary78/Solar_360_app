package com.example.solar_sales

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "solar_sales/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveToDownloads") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                val bytes = call.argument<ByteArray>("bytes")
                val fileName = call.argument<String>("fileName")
                val mimeType = call.argument<String>("mimeType")
                    ?: "application/octet-stream"
                val openAfterSave = call.argument<Boolean>("openAfterSave")
                    ?: false

                if (bytes == null || bytes.isEmpty()) {
                    result.error("EMPTY_FILE", "Downloaded file is empty", null)
                    return@setMethodCallHandler
                }

                if (fileName.isNullOrBlank()) {
                    result.error("INVALID_NAME", "File name is required", null)
                    return@setMethodCallHandler
                }

                val saved = saveToDownloads(bytes, fileName, mimeType)

                if (openAfterSave) {
                    openFile(saved.uri, mimeType)
                }

                result.success(saved.displayPath)
            } catch (error: Exception) {
                result.error("DOWNLOAD_FAILED", error.message, null)
            }
        }
    }

    private fun saveToDownloads(
        bytes: ByteArray,
        fileName: String,
        mimeType: String
    ): SavedDownload {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveWithMediaStore(bytes, fileName, mimeType)
        } else {
            saveLegacy(bytes, fileName, mimeType)
        }
    }

    private fun saveWithMediaStore(
        bytes: ByteArray,
        fileName: String,
        mimeType: String
    ): SavedDownload {
        val resolver = applicationContext.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }

        val uri = resolver.insert(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            values
        ) ?: throw IllegalStateException("Could not create download file")

        try {
            resolver.openOutputStream(uri)?.use { output ->
                output.write(bytes)
            } ?: throw IllegalStateException("Could not write download file")

            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }

        return SavedDownload(uri, "Downloads/$fileName")
    }

    private fun saveLegacy(
        bytes: ByteArray,
        fileName: String,
        mimeType: String
    ): SavedDownload {
        val downloads = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS
        )
        if (!downloads.exists()) downloads.mkdirs()

        val file = File(downloads, fileName)
        file.writeBytes(bytes)

        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file
        )

        return SavedDownload(uri, file.absolutePath)
    }

    private fun openFile(uri: Uri, mimeType: String) {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        startActivity(Intent.createChooser(intent, "Open file"))
    }

    data class SavedDownload(
        val uri: Uri,
        val displayPath: String
    )
}
