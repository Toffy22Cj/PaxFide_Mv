import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.paxfide_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.paxfide_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Dos sabores (DDM-41):
    // - normal: nunca permite HTTP sin cifrar (base de Android).
    // - demo: id distinto (".demo") para no confundirlo con la app normal; permite HTTP sin cifrar SOLO para el host de
    //   PAXFIDE_API_BASE_URL cuando ese valor es http:// (p. ej. el backend local en una red de pruebas). Con https
    //   (túnel) no permite nada en claro.
    flavorDimensions += "entorno"
    productFlavors {
        create("normal") {
            dimension = "entorno"
        }
        create("demo") {
            dimension = "entorno"
            applicationIdSuffix = ".demo"
            versionNameSuffix = "-demo"
        }
    }

    sourceSets {
        getByName("demo") {
            res.srcDir(layout.buildDirectory.dir("generated/paxfide/demoRes"))
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// ---------------------------------------------------------------------------------------------------------------
// network_security_config del sabor demo, generado en cada build desde las dart-defines (DDM-41).
// Flutter pasa --dart-define y --dart-define-from-file a Gradle como -Pdart-defines (cada valor "CLAVE=valor" en
// base64, separados por comas).
// ---------------------------------------------------------------------------------------------------------------
fun paxfideDartDefines(): Map<String, String> {
    val raw = project.findProperty("dart-defines") as String? ?: return emptyMap()
    return raw.split(",").filter { it.isNotBlank() }.mapNotNull {
        val decoded = String(Base64.getDecoder().decode(it), Charsets.UTF_8)
        val i = decoded.indexOf('=')
        if (i <= 0) null else decoded.substring(0, i) to decoded.substring(i + 1)
    }.toMap()
}

/** Host con permiso de HTTP sin cifrar: solo si la URL de la API es http:// y tiene host. Si no, ninguno. */
fun paxfideCleartextHost(): String? {
    val api = paxfideDartDefines()["PAXFIDE_API_BASE_URL"]?.trim() ?: return null
    val uri = try { java.net.URI(api) } catch (e: Exception) { return null }
    if (uri.scheme != "http" || uri.host.isNullOrBlank()) return null
    // Solo letras, dígitos, puntos y guiones: el valor va dentro de un XML.
    return uri.host.takeIf { Regex("^[A-Za-z0-9.-]+$").matches(it) }
}

val paxfideDemoNetworkConfig by tasks.registering {
    val host = paxfideCleartextHost()
    val out = layout.buildDirectory.file("generated/paxfide/demoRes/xml/network_security_config.xml")
    inputs.property("cleartextHost", host ?: "")
    outputs.file(out)
    doLast {
        val domain = if (host == null) "" else """
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">$host</domain>
    </domain-config>"""
        out.get().asFile.apply {
            parentFile.mkdirs()
            writeText("""<?xml version="1.0" encoding="utf-8"?>
<!-- Generado por build.gradle.kts (sabor demo). No editar. -->
<network-security-config>
    <base-config cleartextTrafficPermitted="false" />$domain
</network-security-config>
""")
        }
    }
}

tasks.matching { it.name.startsWith("preDemo") || it.name.matches(Regex("generateDemo.*Resources")) }.configureEach {
    dependsOn(paxfideDemoNetworkConfig)
}
