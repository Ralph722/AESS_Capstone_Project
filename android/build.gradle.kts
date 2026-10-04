import java.io.File

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Keep Gradle output under <project>/build (where the flutter tool expects
// the APK) without hardcoding absolute paths.
val projectBuildDir = File(rootProject.projectDir.parentFile, "build")
rootProject.layout.buildDirectory.set(projectBuildDir)
subprojects {
    val subBuildDir = File(projectBuildDir, project.name)
    project.layout.buildDirectory.set(subBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
