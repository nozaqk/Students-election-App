plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val studentUrl = (project.findProperty("studentUrl") as String).trimEnd('/')

android {
    namespace = "com.mozack.electionvote"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.mozack.electionvote"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
        buildConfigField("String", "STUDENT_URL", "\"$studentUrl\"")
    }
    buildFeatures { buildConfig = true }
    // Release signing: supply keystore details via gradle.properties or CI secrets — never commit them.
    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.activity:activity-ktx:1.9.2")
    implementation("androidx.webkit:webkit:1.11.0")
    implementation("androidx.work:work-runtime:2.9.1")
    testImplementation("junit:junit:4.13.2")
}
