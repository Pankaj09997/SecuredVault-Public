package com.example.securevault

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val channelName = "securevault/public_storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveFile" -> {
                    try {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName")
                        val folderName = call.argument<String>("folderName")
                        val mimeType = call.argument<String>("mimeType")
                            ?: "application/octet-stream"

                        if (bytes == null || fileName.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing file bytes or file name", null)
                            return@setMethodCallHandler
                        }

                        result.success(saveToDownloads(bytes, fileName, folderName, mimeType))
                    } catch (error: Exception) {
                        result.error("SAVE_FAILED", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveToDownloads(
        bytes: ByteArray,
        fileName: String,
        folderName: String?,
        mimeType: String
    ): String {
        val safeFolder = folderName
            ?.trim()
            ?.replace(Regex("[\\\\/:*?\"<>|]"), "_")
            ?.takeIf { it.isNotEmpty() }

        val relativePath = if (safeFolder == null) {
            Environment.DIRECTORY_DOWNLOADS
        } else {
            "${Environment.DIRECTORY_DOWNLOADS}/$safeFolder"
        }
        val displayName = uniqueDisplayName(relativePath, fileName)

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, displayName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val uri = contentResolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                values
            ) ?: throw IllegalStateException("Unable to create download file")

            contentResolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
            } ?: throw IllegalStateException("Unable to open download stream")

            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)

            File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                if (safeFolder == null) displayName else "$safeFolder/$displayName"
            ).absolutePath
        } else {
            val directory = if (safeFolder == null) {
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            } else {
                File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                    safeFolder
                )
            }
            if (!directory.exists()) {
                directory.mkdirs()
            }
            val file = File(directory, displayName)
            file.writeBytes(bytes)
            file.absolutePath
        }
    }

    private fun uniqueDisplayName(relativePath: String, fileName: String): String {
        val directory = File(
            Environment.getExternalStorageDirectory(),
            relativePath
        )
        val dotIndex = fileName.lastIndexOf('.')
        val baseName = if (dotIndex > 0) fileName.substring(0, dotIndex) else fileName
        val extension = if (dotIndex > 0) fileName.substring(dotIndex) else ""

        var candidate = fileName
        var suffix = 1
        while (File(directory, candidate).exists()) {
            candidate = "$baseName ($suffix)$extension"
            suffix++
        }
        return candidate
    }
}
