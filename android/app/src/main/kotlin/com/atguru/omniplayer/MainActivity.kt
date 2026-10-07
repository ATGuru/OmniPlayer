package com.atguru.omniplayer

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {
    private val scope = MainScope()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AudioChannel.CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "decodeToWav") {
                    result.notImplemented(); return@setMethodCallHandler
                }
                val inputPath  = call.argument<String>("inputPath")
                val outputPath = call.argument<String>("outputPath")
                if (inputPath == null || outputPath == null) {
                    result.error("ARGS", "inputPath and outputPath required", null)
                    return@setMethodCallHandler
                }
                scope.launch(Dispatchers.IO) {
                    try {
                        AudioChannel.decodeToWav(inputPath, outputPath)
                        withContext(Dispatchers.Main) { result.success(outputPath) }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("DECODE", e.message ?: "decode failed", null)
                        }
                    }
                }
            }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
