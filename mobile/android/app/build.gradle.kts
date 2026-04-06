plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.xmanstudio.postxapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.xmanstudio.postxapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // LiteRT-LM requires API 24+ for on-device Gemma 4 inference.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Stable release signing — generated once via the
    // init-release-keystore workflow and committed to the repo so every
    // CI build uses the same key. Without this, GitHub Actions runners
    // generate a fresh ephemeral debug.keystore on every build, causing
    // "package conflict" install failures whenever a user tries to
    // update over a previously installed APK.
    signingConfigs {
        create("release") {
            val keystoreFile = file("release.keystore")
            if (keystoreFile.exists()) {
                storeFile = keystoreFile
                storePassword = "postxapp"
                keyAlias = "postxapp"
                keyPassword = "postxapp"
            }
        }
    }

    buildTypes {
        release {
            // Use the committed release keystore when present so every
            // build is signed with the same key. Falls back to the
            // ephemeral debug key only during first-time bootstrap.
            val releaseKeystore = file("release.keystore")
            signingConfig = if (releaseKeystore.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

}

dependencies {
    // On-device LLM inference for Gemma 4 E2B (.litertlm format).
    // https://ai.google.dev/edge/litert-lm/android
    implementation("com.google.ai.edge.litertlm:litertlm-android:0.10.0")
}

flutter {
    source = "../.."
}
