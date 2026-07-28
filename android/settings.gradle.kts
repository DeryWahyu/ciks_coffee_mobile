import org.gradle.api.artifacts.repositories.MavenArtifactRepository

// Maven Central is served through Google's hosted mirror because the primary
// Maven hosts return HTTP 403 on the current development network.
val mavenCentralMirrorUrl = uri("https://maven-central.storage-download.googleapis.com/maven2")
val blockedMavenCentralHosts = setOf("repo.maven.apache.org", "repo1.maven.org")

gradle.beforeProject {
    buildscript.repositories.withType<MavenArtifactRepository>().configureEach {
        if (url.host in blockedMavenCentralHosts) {
            setUrl(mavenCentralMirrorUrl)
        }
    }
    repositories.withType<MavenArtifactRepository>().configureEach {
        if (url.host in blockedMavenCentralHosts) {
            setUrl(mavenCentralMirrorUrl)
        }
    }
}
pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        maven { url = uri("https://maven-central.storage-download.googleapis.com/maven2") }
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("com.google.gms.google-services") version "4.5.0" apply false
}

include(":app")
