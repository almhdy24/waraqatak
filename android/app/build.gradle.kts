import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val hasReleaseKeystore =
    (keystorePropertiesFile.exists() && keystoreProperties.getProperty("storeFile") != null) ||
    (System.getenv("KEYSTORE_PASSWORD") != null && file("upload-keystore.jks").exists())

android {
    namespace = "com.elmahdi.waraqatak"
    compileSdk = 36
    ndkVersion = "29.0.14206865"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.elmahdi.waraqatak"
        // Flutter 3.41 supports API 24+ and rewrites lower values at build
        // time, so the effective minimum is Android 7.0 (API 24).
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists() && keystoreProperties.getProperty("storeFile") != null) {
                keyAlias = keystoreProperties.getProperty("keyAlias") ?: ""
                keyPassword = keystoreProperties.getProperty("keyPassword") ?: ""
                storeFile = keystoreProperties.getProperty("storeFile")?.let { path ->
                    val f1 = rootProject.file(path)
                    val f2 = file(path)
                    if (f1.exists()) f1 else f2
                }
                storePassword = keystoreProperties.getProperty("storePassword") ?: ""
            } else {
                storeFile = file("upload-keystore.jks")
                storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
                keyAlias = System.getenv("KEY_ALIAS") ?: ""
                keyPassword = System.getenv("KEY_PASSWORD") ?: ""
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

// A release signed with the debug key cannot update the published Play app.
// Fail release builds without the upload keystore unless debug signing is
// explicitly requested for local testing (ALLOW_DEBUG_SIGNING=true).
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any { task ->
        task.project == project &&
            (task.name == "assembleRelease" || task.name == "bundleRelease")
    }
    if (buildsRelease && !hasReleaseKeystore &&
        System.getenv("ALLOW_DEBUG_SIGNING") != "true"
    ) {
        throw GradleException(
            "Release signing is not configured: provide android/key.properties or set KEYSTORE_PASSWORD, " +
                "KEY_ALIAS, KEY_PASSWORD and provide android/app/upload-keystore.jks, " +
                "or set ALLOW_DEBUG_SIGNING=true for a local test build."
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
