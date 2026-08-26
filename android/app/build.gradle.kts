import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clé de signature de production.
//
// android/key.properties n'est JAMAIS versionné (cf. .gitignore) : il est créé
// à la main en local, et reconstitué depuis les secrets GitHub en CI.
// Sans lui, on retombe sur la clé de debug — utile pour `flutter run --release`,
// mais un APK ainsi signé ne peut pas remplacer une installation existante.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseKeystore) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

android {
    namespace = "com.faucigny.estimpro"
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
        applicationId = "com.faucigny.estimpro"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Limite aux architectures des vrais appareils Android.
        // x86 (émulateur) fait échouer la compilation native de pdfrx (CMake).
        ndk {
            abiFilters += setOf("arm64-v8a", "armeabi-v7a")
        }
    }

    // Prevents AGP from compressing ML Kit .tflite model files
    androidResources {
        noCompress += listOf("tflite")
    }

    packaging {
        jniLibs {
            // Avoids duplicate native lib conflicts from ML Kit transitive deps
            pickFirsts += setOf("**/libmlkitcore.so", "**/libtflite.so")
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                println(
                    "\n" +
                    "╔══════════════════════════════════════════════════════════════════╗\n" +
                    "║  ATTENTION : build release signée avec la CLÉ DE DEBUG.          ║\n" +
                    "║  android/key.properties est absent.                              ║\n" +
                    "║  Cet APK ne pourra PAS remplacer une installation existante      ║\n" +
                    "║  (il faudrait désinstaller, donc perdre les estimations).        ║\n" +
                    "╚══════════════════════════════════════════════════════════════════╝\n"
                )
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
