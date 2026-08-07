import java.io.File

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val shortPathBuildDir = File("C:/Users/ACERLA~1/alumni_system/build")
rootProject.layout.buildDirectory.set(shortPathBuildDir)

subprojects {
    val newSubprojectBuildDir = File(shortPathBuildDir, project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
