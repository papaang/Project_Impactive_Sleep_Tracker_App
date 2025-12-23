buildscript {
    // Define the Kotlin version here to fix the share_plus error
    val kotlin_version = "1.9.10"
    
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        // Classpath for the Android Gradle Plugin
        classpath("com.android.tools.build:gradle:7.3.0")
        // Classpath for the Kotlin Gradle Plugin
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}