allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // The bundled `integration_test` plugin requests dynamic versions
    // (androidx.test:runner:1.2+, rules:1.2+, espresso-core:3.3+). The trailing
    // `+` forces Gradle to fetch maven-metadata.xml from every repo, including
    // the Flutter artifact mirror, which can return NoSuchKey / time out and
    // fail the build. Pin them to fixed versions on Google Maven so no metadata
    // lookup is needed.
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.test" && requested.name == "runner") {
                useVersion("1.6.2")
            }
            if (requested.group == "androidx.test" && requested.name == "rules") {
                useVersion("1.6.1")
            }
            if (requested.group == "androidx.test.espresso" && requested.name == "espresso-core") {
                useVersion("3.6.1")
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
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
