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
// which fails the build with "Inconsistent JVM Target Compatibility". A
// plain configureEach lost to those plugins' own explicit
// compileOptions.sourceCompatibility (applied later in the same
// configuration pass), so this needs afterEvaluate to run after the
// plugin's own build.gradle has already set its (wrong) value.
// :app is excluded because evaluationDependsOn(":app") above already forces
// it to be fully evaluated before other subprojects are configured, so by
// the time this block runs for :app, calling afterEvaluate on it would
// throw "Cannot run Project.afterEvaluate(Action) when the project is
// already evaluated". :app already declares the correct JVM 17 target
// itself, so it doesn't need this anyway.
subprojects {
    if (project.path != ":app") {
        afterEvaluate {
            tasks.withType<JavaCompile>().configureEach {
                sourceCompatibility = JavaVersion.VERSION_17.toString()
                targetCompatibility = JavaVersion.VERSION_17.toString()
            }
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
