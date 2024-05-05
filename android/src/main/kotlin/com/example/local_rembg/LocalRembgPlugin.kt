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
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer

class LocalRembgPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: AppCompatActivity? = null
    private lateinit var segmenter: Segmenter
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
                val arguments = call.arguments as? Map<String, Any>
                val imagePath = arguments?.get("imagePath") as? String
                val shouldCropImage = arguments?.get("cropImage") as? Boolean

                if (imagePath != null) {
                    removeBackgroundFromFile(imagePath, shouldCropImage!!, result)
                } else {
                    sendErrorResult(result, 0, "Invalid arguments or unable to load image")
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun removeBackgroundFromFile(
        imagePath: String,
        shouldCropImage: Boolean,
        result: MethodChannel.Result
    ) {
        if (imagePath.isEmpty()) {
            sendErrorResult(result, 0, "Image path cannot be empty")
            return
        }

        val file = File(imagePath)
        if (!file.exists()) {
            sendErrorResult(result, 0, "Image file not found")
            return
        }

        try {
            val options = BitmapFactory.Options().apply {
                inPreferredConfig = Bitmap.Config.ARGB_8888
                inSampleSize = 2
            }

            val bitmap = BitmapFactory.decodeFile(imagePath, options) ?: return

            val inputImage = InputImage.fromBitmap(bitmap, 0)

            segmenter.process(inputImage)
                .addOnSuccessListener { segmentationMask ->
                    width = segmentationMask.width
                    height = segmentationMask.height

                    processSegmentationMask(
                        result,
                        bitmap,
                        segmentationMask.buffer,
                        shouldCropImage
                    )
                }
                .addOnFailureListener { exception ->
                    sendErrorResult(result, 0, exception.message)
                }
                .addOnFailureListener { exception ->
                    sendErrorResult(result, 0, exception.message)
                }
        } catch (e: Exception) {
            sendErrorResult(result, 0, e.message)
        }
    }

    private fun processSegmentationMask(
        result: MethodChannel.Result,
        bitmap: Bitmap,
        buffer: ByteBuffer,
        shouldCropImage: Boolean
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            val bgConf = FloatArray(width * height)
            buffer.rewind()
            buffer.asFloatBuffer().get(bgConf)
            var newBmp = bitmap.copy(bitmap.config, true)
            var resultBmp: Bitmap?

            if (shouldCropImage) {
                resultBmp = cropImage(newBmp, bgConf)
            } else {
                makeBackgroundTransparent(newBmp, bgConf)
                resultBmp = newBmp
            }

            val targetWidth = 1080
            val targetHeight =
                (resultBmp!!.height.toFloat() / resultBmp.width.toFloat() * targetWidth).toInt()
            val resizedBmp = Bitmap.createScaledBitmap(resultBmp, targetWidth, targetHeight, true)

            val processedBmp =
                Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(processedBmp)
            canvas.drawColor(Color.TRANSPARENT)

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

    private fun cropImage(bitmap: Bitmap, bgConf: FloatArray): Bitmap {
        var minX = bitmap.width
        var minY = bitmap.height
        var maxX = 0
        var maxY = 0
        val pixels = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)

        for (y in 0 until height) {
            for (x in 0 until width) {
                val index = y * width + x
                val conf = (1.0f - bgConf[index]) * 255
                if (conf >= 100) {
                    bitmap.setPixel(x, y, Color.TRANSPARENT)
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
        return Bitmap.createBitmap(bitmap, minX, minY, maxX - minX + 1, maxY - minY + 1)
    }

    private fun makeBackgroundTransparent(bitmap: Bitmap, bgConf: FloatArray) {
        for (y in 0 until bitmap.height) {
            for (x in 0 until bitmap.width) {
                val index = y * bitmap.width + x
                val conf = (1.0f - bgConf[index]) * 255
                if (conf >= 100) {
                    bitmap.setPixel(x, y, Color.TRANSPARENT)
                }
            }
        }
    }

    private fun sendErrorResult(result: MethodChannel.Result, status: Int, errorMessage: String?) {
        val errorResult = mapOf(
            "status" to status,
            "message" to errorMessage
        )
        result.success(errorResult)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
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
