import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.var6betting.sportsapp"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion = flutter.ndkVersion  // Commented out to avoid NDK issues

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // Generate a monotonically increasing versionCode based on epoch seconds
    fun generatedVersionCode(): Int {
        val seconds = (System.currentTimeMillis() / 1000L)
        // Guard against 32-bit Int overflow (Android's max versionCode)
        return if (seconds > Int.MAX_VALUE) Int.MAX_VALUE else seconds.toInt()
    }

    defaultConfig {
        // Application ID for Play Store package name
        applicationId = "com.var6betting.sportsapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Always use a unique, time-based versionCode to avoid Play Console collisions
        versionCode = generatedVersionCode()
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
