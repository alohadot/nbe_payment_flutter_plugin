group = "com.example.nbe_payment_flutter_plugin"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.2.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "com.example.nbe_payment_flutter_plugin"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

// The Gateway SDK is not published to a public registry; it ships inside this plugin as a
// local Maven repository. Gradle resolves this module's dependencies with the repositories of
// the consuming app, so registering the repository on this module alone is not enough — it
// has to be visible to every project in the host build.
val gatewaySdkRepository = file("gateway-repo")
rootProject.allprojects {
    repositories {
        maven {
            url = uri(gatewaySdkRepository)
            content { includeGroup("com.mastercard.gateway") }
        }
    }
}

val gatewaySdkVersion = "2.0.17"

dependencies {
    implementation("com.mastercard.gateway:Mobile_SDK_Android:$gatewaySdkVersion")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
