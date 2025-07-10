buildscript {
    repositories {
        google() // Use Google's Maven repository
        mavenCentral() // Use Maven Central repository
    }
    dependencies {
        // Add this line to the dependencies block
        classpath("com.google.gms:google-services:4.4.2") // Apply the google services plugin

        // More classpath dependencies can be added here
    }
}

allprojects {
    repositories {
        google() // Use Google's Maven repository
        mavenCentral() // Use Maven Central repository
    }
}

rootProject.buildDir = File("../build")

subprojects {
    buildDir = File(rootProject.buildDir, name)
}

subprojects {
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
