plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")   // สำหรับ Firebase
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.jeab.app"   // แพ็กเกจหลักของแอป
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.jeab.app"   // ต้องตรงกับ google-services.json
        minSdk = flutter.minSdkVersion                      // หรือ flutter.minSdkVersion ก็ได้
        targetSdk = 34                   // หรือ flutter.targetSdkVersion ก็ได้
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        // ✅ เพิ่ม debug block เพื่อปิด resource shrinking
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }

        release {
            signingConfig = signingConfigs.getByName("debug")

            // ปิด resource shrinking เพื่อป้องกัน error ตอนนี้
            isMinifyEnabled = false
            isShrinkResources = false

            // ถ้าจะเปิดในภายหลัง ให้เปิดสองบรรทัดนี้พร้อมกัน
            // isMinifyEnabled = true
            // isShrinkResources = true

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
