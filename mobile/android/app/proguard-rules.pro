# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_inappwebview
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-keepattributes *Annotation*

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }

# Play Core (referenced by Flutter deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# LiteRT / TFLite (for Gemma model inference)
-dontwarn com.google.ai.edge.**
-keep class com.google.ai.edge.** { *; }

# speech_to_text
-keep class com.csdcorp.speech_to_text.** { *; }

# connectivity_plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
