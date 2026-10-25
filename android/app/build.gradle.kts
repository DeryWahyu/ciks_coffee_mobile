plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.cikscoffee.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    // CI supplies the existing manual-install key explicitly instead of
    // depending on the runner's Android user-home directory.
    val ciKeystore = System.getenv("CIKS_ANDROID_KEYSTORE")
    if (!ciKeystore.isNullOrBlank()) {
        signingConfigs.getByName("debug") {
            storeFile = file(ciKeystore)
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.cikscoffee.app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Release/profile builds remain HTTPS-only by default.
        manifestPlaceholders["usesCleartextTraffic"] = "false"

        // The release builder opts out of Flutter's three-ABI defaults, then
        // filters every native dependency, including JNI libraries from plugins.
        if (providers.gradleProperty("disable-abi-filtering").orNull == "true") {
            val platformAbis = mapOf(
                "android-arm" to "armeabi-v7a",
                "android-arm64" to "arm64-v8a",
                "android-x64" to "x86_64",
            )
            val targetPlatforms = providers.gradleProperty("target-platform")
                .getOrElse("android-arm,android-arm64,android-x64")
            ndk {
                abiFilters.clear()
                abiFilters.addAll(targetPlatforms.split(",").map { platformAbis.getValue(it) })
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
