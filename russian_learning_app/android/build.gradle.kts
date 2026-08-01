allprojects {
    repositories {
        google()
        mavenCentral()
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

// Some plugins (flutter_timezone, flutter_tts, speech_to_text) still apply
// their own old-style Kotlin Gradle plugin with a Kotlin JVM target that
// doesn't match the Java target AGP picks for their Android library module,
// which fails the build with "Inconsistent JVM Target Compatibility".
// Force every subproject's Java/Kotlin compile tasks onto the same JVM 17
// target so this can't happen regardless of what an individual plugin
// declares.
// tasks.withType(...).configureEach{} is lazy and applies to tasks created
// at any point (past or future), so this does not need - and must not use -
// afterEvaluate: by the time this runs for :app, evaluationDependsOn above
// has already forced :app to be fully evaluated for other subprojects, and
// calling afterEvaluate on an already-evaluated project throws.
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
