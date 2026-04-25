import org.gradle.api.tasks.AbstractCopyTask

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

fun purgeAppleDoubleFiles(target: File) {
    if (!target.exists()) return

    target.walkTopDown()
        .onEnter { file -> file.name != ".git" }
        .filter { it.name.startsWith("._") }
        .forEach { file ->
            if (!file.delete()) {
                file.deleteOnExit()
            }
        }
}

// Keep Flutter's expected APK output path in the project build directory, but
// build every Android module in a temp directory to avoid macOS AppleDouble
// sidecar files and flaky resource merges on the external drive.
val flutterBuildRoot = rootProject.projectDir.parentFile.resolve("build")
val androidBuildRoot = File(
    System.getProperty("java.io.tmpdir"),
    "sk_bags_staff_android_build",
)
rootProject.layout.buildDirectory.set(flutterBuildRoot)

subprojects {
    val targetBuildDir = File(androidBuildRoot, project.name)
    project.layout.buildDirectory.set(targetBuildDir)
    project.evaluationDependsOn(":app")

    if (project.path == ":app") {
        val syncFlutterOutputs =
            tasks.register<Sync>("syncFlutterOutputs") {
                from(project.layout.buildDirectory.dir("outputs"))
                into(File(flutterBuildRoot, "app/outputs"))
            }

        tasks.matching {
            it.name == "assembleDebug" ||
                it.name == "assembleRelease" ||
                it.name == "bundleRelease"
        }.configureEach {
            finalizedBy(syncFlutterOutputs)
        }
    }
}

val purgeAppleDoubleFilesTask =
    tasks.register("purgeAppleDoubleFiles") {
        doLast {
            purgeAppleDoubleFiles(rootProject.layout.buildDirectory.asFile.get())
            purgeAppleDoubleFiles(androidBuildRoot)
            purgeAppleDoubleFiles(rootProject.projectDir.parentFile)
        }
    }

subprojects {
    tasks.withType(AbstractCopyTask::class.java).configureEach {
        exclude("**/._*")
        exclude("**/._.*")
    }

    tasks.configureEach {
        if (name != "purgeAppleDoubleFiles") {
            doFirst {
                purgeAppleDoubleFiles(rootProject.layout.buildDirectory.asFile.get())
                purgeAppleDoubleFiles(androidBuildRoot)
                purgeAppleDoubleFiles(rootProject.projectDir.parentFile)
            }
            doLast {
                purgeAppleDoubleFiles(rootProject.layout.buildDirectory.asFile.get())
                purgeAppleDoubleFiles(androidBuildRoot)
                purgeAppleDoubleFiles(rootProject.projectDir.parentFile)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    dependsOn(purgeAppleDoubleFilesTask)
    delete(rootProject.layout.buildDirectory)
    delete(androidBuildRoot)
}
