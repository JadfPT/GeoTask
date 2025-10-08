// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("kotlin-android")
}

// Liga o build do módulo app ao tooling do Flutter
val flutterRoot = File(rootProject.projectDir, "../..")
apply(from = File(flutterRoot, "packages/flutter_tools/gradle/flutter.gradle"))

val flutterVersionCode =
    (project.findProperty("flutter.versionCode") as String?)?.toIntOrNull() ?: 1
val flutterVersionName =
    (project.findProperty("flutter.versionName") as String?) ?: "1.0"

android {
    // ⚠️ Usa o namespace que já tens no teu projeto (mantém!)
    // Se precisares mudar, garante que coincide com o package do AndroidManifest
    namespace = "com.example.geotask" // <- coloca aqui o teu namespace atual

    compileSdk = 34

    defaultConfig {
        // ⚠️ Mantém o teu applicationId atual
        applicationId = "com.example.geotask" // <- coloca aqui o teu applicationId atual
        minSdk = 21
        targetSdk = 34

        versionCode = flutterVersionCode
        versionName = flutterVersionName

        // Necessário para localização em foreground/background em alguns devices
        // (não ativa por si só background; apenas evita crash em APIs antigas)
        multiDexEnabled = true
    }

    // Usa Java/Kotlin 17 (recomendado com AGP 8+)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            // Mantém simples no MVP: sem minify; quando fores assinar, ativa e configura ProGuard
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // útil para testes de localização/notificações
            isMinifyEnabled = false
        }
    }

    packaging {
        // Evita conflitos comuns de licenças/metadata de libs
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "META-INF/DEPENDENCIES"
            excludes += "META-INF/NOTICE"
            excludes += "META-INF/LICENSE"
            excludes += "META-INF/LICENSE.txt"
            excludes += "META-INF/NOTICE.txt"
        }
    }
}

// Dependências Kotlin de base (opcional, mas inofensivo)
dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
    implementation("androidx.core:core-ktx:1.13.1")
}
