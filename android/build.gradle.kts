allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redirect build directory only for the root project and the app module
// to avoid "Different Roots" error with plugins on drive C:
val newBuildDir: Directory = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    if (project.name == "app") {
        project.layout.buildDirectory.value(newBuildDir.dir(project.name))
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
buildscript {
    repositories {
        google() // <--- Must be first
        mavenCentral()
    }
}