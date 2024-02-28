package com.example.local_rembg

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import androidx.appcompat.app.AppCompatActivity
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.Segmentation
import com.google.mlkit.vision.segmentation.Segmenter
import com.google.mlkit.vision.segmentation.selfie.SelfieSegmenterOptions
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

class LocalRembgPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: AppCompatActivity? = null
    private lateinit var segmenter: Segmenter
    private lateinit var buffer: ByteBuffer
    private var width = 0
    private var height = 0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "methodChannel.localRembg")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val segmentOptions = SelfieSegmenterOptions.Builder()
                .setDetectorMode(SelfieSegmenterOptions.SINGLE_IMAGE_MODE)
                .build()
        segmenter = Segmentation.getClient(segmentOptions)

        when (call.method) {
            "removeBackground" -> {
                val imagePath = call.arguments as? String
                if (imagePath != null) {
                    removeBackground(imagePath, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Image path is null", null)
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun removeBackground(imagePath: String, result: MethodChannel.Result) {
        try {
            val bitmap = BitmapFactory.decodeFile(imagePath) ?: return

            val copyBitmap = bitmap.copy(Bitmap.Config.ARGB_8888, true)
            val inputImage = InputImage.fromBitmap(copyBitmap, 0)

            segmenter.process(inputImage)
                    .addOnSuccessListener { segmentationMask ->
                        buffer = segmentationMask.buffer
                        width = segmentationMask.width
                        height = segmentationMask.height

                        processSegmentationMask(result, copyBitmap)
                    }
                    .addOnFailureListener { exception ->
                        val response = mapOf(
                                "status" to 0,
                                "message" to exception.message
                        )
                        result.success(response)
                    }
        } catch (e: Exception) {
            val response = mapOf(
                    "status" to 0,
                    "message" to e.message
            )
            result.success(response)
        }
    }

    private fun processSegmentationMask(result: MethodChannel.Result, bitmap: Bitmap) {
        CoroutineScope(Dispatchers.IO).launch {
            val bgConf = FloatArray(width * height)
            buffer.rewind()
            buffer.asFloatBuffer().get(bgConf)
            val newBmp = bitmap.copy(bitmap.config, true)

            var minX = newBmp.width
            var minY = newBmp.height
            var maxX = 0
            var maxY = 0

            val pixels = IntArray(newBmp.width * newBmp.height)
            newBmp.getPixels(pixels, 0, newBmp.width, 0, 0, newBmp.width, newBmp.height)

            for (y in 0 until height) {
                for (x in 0 until width) {
                    val index = y * width + x
                    val conf = (1.0f - bgConf[index]) * 255
                    if (conf >= 100) {
                        newBmp.setPixel(x, y, Color.TRANSPARENT)
                    } else {
                        if (pixels[x + y * bitmap.width] != Color.TRANSPARENT) {
                            minX = minOf(minX, x)
                            minY = minOf(minY, y)
                            maxX = maxOf(maxX, x)
                            maxY = maxOf(maxY, y)
                        }
                    }
                }
            }

            val resultBmp = Bitmap.createBitmap(newBmp, minX, minY, maxX - minX + 1, maxY - minY + 1)

            val targetWidth = 1080
            val targetHeight = (resultBmp.height.toFloat() / resultBmp.width.toFloat() * targetWidth).toInt()
            val resizedBmp = Bitmap.createScaledBitmap(resultBmp, targetWidth, targetHeight, true)

            val processedBmp = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(processedBmp)
            canvas.drawColor(Color.WHITE)

            val left = (targetWidth - resizedBmp.width) / 2f
            val top = (targetHeight - resizedBmp.height) / 2f
            canvas.drawBitmap(resizedBmp, left, top, null)

            val outputStream = ByteArrayOutputStream()
            processedBmp.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            val processedImageBytes = outputStream.toByteArray()

            val response = mapOf(
                    "status" to 1,
                    "imageBytes" to processedImageBytes.toList(),
                    "message" to "Success"
            )
            result.success(response)
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity as AppCompatActivity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity as AppCompatActivity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }
}
