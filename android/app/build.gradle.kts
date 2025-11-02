plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")   // สำคัญสำหรับ Firebase
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "com.jeab.app"   // แก้ชื่อถ้าต้องการ
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    defaultConfig {
        applicationId = "com.jeab.app"  // ต้องตรงกับ google-services.json
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release { signingConfig = signingConfigs.getByName("debug") }
    }
}
flutter { source = "../.." }
