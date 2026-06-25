import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.nio.file.Files
import java.nio.file.StandardCopyOption

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.anveil.bmsmonitor"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.anveil.bmsmonitor"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

tasks.register("renameReleaseApk") {
    doLast {
        val apkDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
        val sourceApk = apkDir.resolve("app-release.apk")
        val targetApk = apkDir.resolve("BmsMonitor-release.apk")
        if (sourceApk.exists()) {
            Files.copy(
                sourceApk.toPath(),
                targetApk.toPath(),
                StandardCopyOption.REPLACE_EXISTING,
            )
            println("Created ${targetApk.absolutePath}")
        } else {
            println("Skip renameReleaseApk: source not found -> ${sourceApk.absolutePath}")
        }
    }
}

tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy("renameReleaseApk")
}
