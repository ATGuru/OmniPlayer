import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload key lives in android/key.properties (gitignored). A release build
// fails when the file is missing. Play rejects a bundle signed with the debug key.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// New phone apps must target API 36 as of August 31, 2026.
// Stay on Flutter's default when that default is already higher.
val playTargetSdk = 36

android {
    namespace = "com.atguru.omniplayer"
    compileSdk = maxOf(flutter.compileSdkVersion, playTargetSdk)
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
        applicationId = "com.atguru.omniplayer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = maxOf(playTargetSdk, flutter.targetSdkVersion)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    if (hasReleaseKey) return@whenReady
    if (allTasks.any { it.name.contains("Release") }) {
        throw org.gradle.api.GradleException(
            "android/key.properties is missing. The release build will not sign with the debug key. " +
                "Copy android/key.properties.example and point it at the upload keystore."
        )
    }
}

flutter {
    source = "../.."
}


