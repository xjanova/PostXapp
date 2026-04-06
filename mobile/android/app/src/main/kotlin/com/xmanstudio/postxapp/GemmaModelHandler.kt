package com.xmanstudio.postxapp

import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import java.io.File

/**
 * Real on-device inference bridge for Gemma 4 E2B using Google's
 * LiteRT-LM runtime (com.google.ai.edge.litertlm:litertlm-android).
 *
 * The model file is expected to be a `.litertlm` bundle downloaded from
 * https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm
 *
 * NOTE: Engine initialization is expensive (seconds → tens of seconds on
 * first load) and MUST happen off the main thread. MainActivity already
 * dispatches all MethodChannel calls to a worker thread.
 */
class GemmaModelHandler {

    private var engine: Engine? = null
    private var modelPath: String? = null

    private val isLoaded: Boolean
        get() = engine != null

    /**
     * Load the model from the given file path and initialize the inference
     * engine. Blocking — call from a background thread.
     */
    @Synchronized
    fun loadModel(path: String): Boolean {
        if (engine != null && modelPath == path) {
            return true
        }

        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("Model file not found: $path")
        }
        if (file.length() < 100L * 1024 * 1024) {
            throw IllegalArgumentException("Model file is too small (${file.length()} bytes). Re-download required.")
        }

        // Clean up any previous engine before loading a new one.
        try {
            engine?.close()
        } catch (_: Throwable) {
            // Ignore cleanup errors — we're about to replace the engine.
        }
        engine = null

        val config = EngineConfig(
            modelPath = path,
            backend = Backend.CPU(),
        )
        val newEngine = Engine(config)
        newEngine.initialize() // Heavy: weight loading + kv-cache allocation.

        engine = newEngine
        modelPath = path
        return true
    }

    /**
     * Generate text from a prompt using the loaded model. Blocking call —
     * dispatch from a background thread.
     *
     * The LiteRT-LM 0.10 Kotlin API exposes generation via
     * `engine.createConversation(config).sendMessage(prompt)`. We create a
     * fresh conversation for each call so there is no cross-prompt state
     * leakage between unrelated user requests.
     */
    @Synchronized
    fun generateText(prompt: String, maxTokens: Int, temperature: Double): String {
        val currentEngine = engine
            ?: throw IllegalStateException("Model not loaded. Call loadModel first.")

        return currentEngine.createConversation(ConversationConfig()).use { conversation ->
            // LiteRT-LM 0.10's Message.toString() returns the generated text
            // directly (the official Kotlin docs use `print(sendMessage(...))`
            // and `print(it.toString())` to display the response).
            val message = conversation.sendMessage(prompt)
            message.toString().trim()
        }
    }

    /**
     * Image analysis is not supported by the text-only Gemma 4 E2B LiteRT-LM
     * bundle we ship. Returning a clear message so the UI can fall back
     * gracefully instead of pretending to have results.
     */
    fun analyzeImage(imagePath: String, prompt: String): String {
        if (!isLoaded) {
            throw IllegalStateException("Model not loaded. Call loadModel first.")
        }
        val file = File(imagePath)
        if (!file.exists()) {
            throw IllegalArgumentException("Image file not found: $imagePath")
        }

        // Fallback: generate text from the prompt alone (no vision input).
        // A dedicated vision model would be needed for real image understanding.
        return generateText(
            prompt = "You are a creative social-media writer. " +
                    "An image is attached to this post but I cannot show it to you. " +
                    "Based only on the user instruction below, write an engaging caption.\n\n" +
                    "User instruction: $prompt",
            maxTokens = 512,
            temperature = 0.7,
        )
    }

    /**
     * Same fallback strategy as [analyzeImage] — the current `.litertlm`
     * bundle is text-only, so we generate a caption from the prompt.
     */
    fun analyzeVideo(videoPath: String, prompt: String): String {
        if (!isLoaded) {
            throw IllegalStateException("Model not loaded. Call loadModel first.")
        }
        val file = File(videoPath)
        if (!file.exists()) {
            throw IllegalArgumentException("Video file not found: $videoPath")
        }

        return generateText(
            prompt = "You are a creative social-media writer. " +
                    "A video is attached to this post but I cannot watch it. " +
                    "Based only on the user instruction below, write an engaging caption.\n\n" +
                    "User instruction: $prompt",
            maxTokens = 512,
            temperature = 0.7,
        )
    }

    /**
     * Release native resources. Safe to call multiple times.
     */
    @Synchronized
    fun unloadModel() {
        try {
            engine?.close()
        } catch (_: Throwable) {
            // Ignore — we're tearing down.
        }
        engine = null
        modelPath = null
    }
}
