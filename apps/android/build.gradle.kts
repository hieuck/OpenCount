plugins {
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
}

kotlin {
    androidTarget {
        compilations.all {
            compileTaskProvider.configure {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
        }
    }

    sourceSets {
        val androidMain by getting {
            dependencies {
                implementation(project(":packages:shared"))
                implementation("androidx.compose.ui:ui:1.6.7")
                implementation("androidx.compose.material3:material3:1.2.1")
                implementation("androidx.compose.foundation:foundation:1.6.7")
                implementation("androidx.activity:activity-compose:1.9.1")
                implementation("androidx.navigation:navigation-compose:2.7.7")
                implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.8.4")
                implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.4")
            }
        }
    }
}

android {
    namespace = "com.opencount.android"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.opencount.android"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildFeatures { compose = true }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
