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
// their own old-style Kotlin Gradle plugin without an explicit Kotlin JVM
// target, so it falls back to the Kotlin compiler's own default (1.8),
// while AGP compiles their Java sources against Java 11 (these plugins do
// set compileOptions.sourceCompatibility = VERSION_11 themselves) - two
// different CI runs confirmed forcing the Java side back up to 17 from
// here never sticks (AGP/KGP re-assert 11 for Java later in their own
// internal evaluation, no matter whether this uses configureEach or
// afterEvaluate), so instead of fighting Java, just make Kotlin match the
// Java target that's already in effect (11).
// :app is excluded because evaluationDependsOn(":app") above already forces
// it to be fully evaluated before other subprojects are configured, so by
// the time this block runs for :app, calling afterEvaluate on it would
// throw "Cannot run Project.afterEvaluate(Action) when the project is
// already evaluated". :app already declares a consistent JVM 17 target for
// both Java and Kotlin itself, so it doesn't need this anyway.
subprojects {
    if (project.path != ":app") {
        afterEvaluate {
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
