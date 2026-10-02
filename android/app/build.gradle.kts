plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val hasReleaseKeystore =
    System.getenv("KEYSTORE_PASSWORD") != null && file("upload-keystore.jks").exists()

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
        minSdk = 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = file("upload-keystore.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
            keyAlias = System.getenv("KEY_ALIAS") ?: ""
            keyPassword = System.getenv("KEY_PASSWORD") ?: ""
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
            "Release signing is not configured: set KEYSTORE_PASSWORD, " +
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
