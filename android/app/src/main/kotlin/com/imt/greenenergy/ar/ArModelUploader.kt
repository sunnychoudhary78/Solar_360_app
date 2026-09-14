package com.imt.greenenergy.ar

import android.util.Log
import java.io.BufferedReader
import java.io.DataOutputStream
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

data class PublicUrlProbe(
    val url: String,
    val method: String = "HEAD",
    val status: Int? = null,
    val contentType: String? = null,
    val contentLength: String? = null,
    val location: String? = null,
    val exception: String? = null,
) {
    val https: Boolean get() = url.startsWith("https://", ignoreCase = true)

    val html: Boolean
        get() = contentType.orEmpty().lowercase().contains("text/html")

    val okToOpen: Boolean
        get() = https && exception == null && status != null && status in 200..299 && !html

    val summary: String
        get() = buildString {
            append("$method status=${status ?: "—"}")
            append(" type=${contentType ?: "—"}")
            append(" length=${contentLength ?: "—"}")
            if (!location.isNullOrBlank()) append(" location=$location")
            if (exception != null) append(" error=$exception")
        }

    val blockReason: String?
        get() = when {
            !https -> "Public URL is not HTTPS. Scene Viewer cannot load: $url"
            exception != null -> "Could not reach public URL: $exception"
            status == null -> "No HTTP status from public URL."
            status !in 200..299 ->
                "Public URL returned $status" +
                    (if (!location.isNullOrBlank()) " → $location" else "") +
                    ". Google cannot load this object."
            html ->
                "Public URL returned HTML ($contentType), not a GLB. Check nginx / login wall."
            else -> null
        }
}

object ArModelUploader {
    const val TAG = "SolarAR"

    fun upload(apiBaseUrl: String, token: String, bytes: ByteArray, filename: String): String {
        val base = apiBaseUrl.trim().trimEnd('/')
        if (base.isEmpty()) {
            throw IllegalStateException("API base URL is missing. Sign in again and retry.")
        }
        if (token.isBlank()) {
            throw IllegalStateException("You are not signed in. Sign in again and retry.")
        }
        if (bytes.isEmpty()) {
            throw IllegalStateException("The rooftop model could not be generated.")
        }

        val boundary = "----SolarAr${System.currentTimeMillis()}"
        val url = URL("$base/ar-models")
        Log.i(TAG, "POST $url glbBytes=${bytes.size}")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            connectTimeout = 30_000
            readTimeout = 60_000
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
        }

        try {
            DataOutputStream(conn.outputStream).use { out ->
                out.writeBytes("--$boundary\r\n")
                out.writeBytes(
                    "Content-Disposition: form-data; name=\"file\"; filename=\"$filename\"\r\n",
                )
                out.writeBytes("Content-Type: model/gltf-binary\r\n\r\n")
                out.write(bytes)
                out.writeBytes("\r\n--$boundary--\r\n")
                out.flush()
            }

            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val body = stream?.bufferedReader()?.use(BufferedReader::readText).orEmpty()
            Log.i(TAG, "POST status=$code body=$body")
            if (code !in 200..299) {
                throw IllegalStateException(parseMessage(body) ?: "Upload failed ($code)")
            }
            val json = JSONObject(body)
            val fileUrl = json.optString("file_url")
            Log.i(
                TAG,
                "file_url=$fileUrl content_type=${json.optString("content_type")} " +
                    "bytes=${json.opt("bytes")}",
            )
            if (fileUrl.isNullOrBlank()) {
                throw IllegalStateException("Server did not return a model URL.")
            }
            return fileUrl
        } finally {
            conn.disconnect()
        }
    }

    fun probePublicUrl(fileUrl: String): PublicUrlProbe {
        val url = fileUrl.trim()
        if (url.isEmpty()) {
            return PublicUrlProbe(url = url, exception = "empty file_url")
        }
        var probe = request(url, method = "HEAD", range = null)
        if (probe.status == 405 || probe.status == 501) {
            Log.i(TAG, "HEAD not allowed (${probe.status}); retrying GET Range bytes=0-0")
            probe = request(url, method = "GET", range = "bytes=0-0")
        }
        Log.i(TAG, "probe $url → ${probe.summary} https=${probe.https} html=${probe.html} ok=${probe.okToOpen}")
        return probe
    }

    private fun request(fileUrl: String, method: String, range: String?): PublicUrlProbe {
        var conn: HttpURLConnection? = null
        return try {
            conn = (URL(fileUrl).openConnection() as HttpURLConnection).apply {
                requestMethod = method
                instanceFollowRedirects = false
                connectTimeout = 15_000
                readTimeout = 15_000
                if (range != null) {
                    setRequestProperty("Range", range)
                }
            }
            val code = conn.responseCode
            val type = conn.getHeaderField("Content-Type")
            val length = conn.getHeaderField("Content-Length")
            val location = conn.getHeaderField("Location")
            Log.i(
                TAG,
                "$method $fileUrl status=$code type=$type length=$length location=$location",
            )
            PublicUrlProbe(
                url = fileUrl,
                method = method,
                status = code,
                contentType = type,
                contentLength = length,
                location = location,
            )
        } catch (e: Exception) {
            Log.e(TAG, "$method $fileUrl failed: ${e.message}", e)
            PublicUrlProbe(
                url = fileUrl,
                method = method,
                exception = e.message ?: e.javaClass.simpleName,
            )
        } finally {
            conn?.disconnect()
        }
    }

    private fun parseMessage(body: String): String? {
        if (body.isBlank()) return null
        return try {
            val json = JSONObject(body)
            json.optString("message").ifBlank { json.optString("error") }.ifBlank { null }
        } catch (_: Exception) {
            body.take(180)
        }
    }
}
