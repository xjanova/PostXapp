package com.xmanstudio.postxapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.postxapp/gemma"
    private var gemmaHandler: GemmaModelHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        gemmaHandler = GemmaModelHandler()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val modelPath = call.argument<String>("modelPath")
                    if (modelPath == null) {
                        result.error("INVALID_ARGUMENT", "modelPath is required", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val success = gemmaHandler?.loadModel(modelPath) ?: false
                            activity.runOnUiThread { result.success(success) }
                        } catch (e: Exception) {
                            activity.runOnUiThread {
                                result.error("LOAD_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }

                "generateText" -> {
                    val prompt = call.argument<String>("prompt") ?: ""
                    val maxTokens = call.argument<Int>("maxTokens") ?: 1024
                    val temperature = call.argument<Double>("temperature") ?: 0.7

                    Thread {
                        try {
                            val text = gemmaHandler?.generateText(prompt, maxTokens, temperature)
                                ?: ""
                            activity.runOnUiThread { result.success(text) }
                        } catch (e: Exception) {
                            activity.runOnUiThread {
                                result.error("GENERATE_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }

                "analyzeImage" -> {
                    val imagePath = call.argument<String>("imagePath") ?: ""
                    val prompt = call.argument<String>("prompt") ?: "Describe this image."

                    Thread {
                        try {
                            val text = gemmaHandler?.analyzeImage(imagePath, prompt) ?: ""
                            activity.runOnUiThread { result.success(text) }
                        } catch (e: Exception) {
                            activity.runOnUiThread {
                                result.error("IMAGE_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }

                "analyzeVideo" -> {
                    val videoPath = call.argument<String>("videoPath") ?: ""
                    val prompt = call.argument<String>("prompt") ?: "Describe this video."

                    Thread {
                        try {
                            val text = gemmaHandler?.analyzeVideo(videoPath, prompt) ?: ""
                            activity.runOnUiThread { result.success(text) }
                        } catch (e: Exception) {
                            activity.runOnUiThread {
                                result.error("VIDEO_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }

                "unloadModel" -> {
                    gemmaHandler?.unloadModel()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        gemmaHandler?.unloadModel()
        super.onDestroy()
    }
}
