package com.jkasfc.projects_hub

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var askedNotifications = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "projects_hub/native")
        // Buttons of the media notification -> Dart -> web player.
        MediaPlaybackService.onAction = { action, position ->
            ch.invokeMethod("mediaAction", mapOf("action" to action, "position" to position))
        }
        ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "mediaUpdate" -> {
                        askNotificationPermission()
                        MediaPlaybackService.update(
                            this,
                            MediaInfo(
                                title = call.argument<String>("title") ?: "",
                                artist = call.argument<String>("artist") ?: "",
                                playing = call.argument<Boolean>("playing") ?: false,
                                positionMs = (call.argument<Number>("position") ?: 0).toLong(),
                                durationMs = (call.argument<Number>("duration") ?: 0).toLong(),
                                hue = (call.argument<Number>("hue") ?: 280).toInt(),
                            ),
                        )
                        result.success(null)
                    }
                    "mediaStop" -> {
                        MediaPlaybackService.stop(this)
                        result.success(null)
                    }
                    "isAppInstalled" -> {
                        val pkg = call.argument<String>("package") ?: ""
                        result.success(launchIntentFor(pkg) != null)
                    }
                    "launchApp" -> {
                        val intent = launchIntentFor(call.argument<String>("package") ?: "")
                        if (intent == null) {
                            result.success(false)
                        } else {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        }
                    }
                    "openUrl" -> {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url")))
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: ActivityNotFoundException) {
                            result.success(false)
                        }
                    }
                    "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                    "requestAllFilesAccess" -> {
                        requestAllFilesAccess()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        // The web player dies with the activity: remove its notification too.
        MediaPlaybackService.onAction = null
        MediaPlaybackService.stop(this)
        super.onDestroy()
    }

    private fun askNotificationPermission() {
        if (askedNotifications || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        askedNotifications = true
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 43)
        }
    }

    private fun launchIntentFor(pkg: String): Intent? =
        if (pkg.isBlank()) null else packageManager.getLaunchIntentForPackage(pkg)

    private fun hasAllFilesAccess(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED
        }

    private fun requestAllFilesAccess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                        Uri.parse("package:$packageName"),
                    ),
                )
            } catch (e: ActivityNotFoundException) {
                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
            }
        } else {
            requestPermissions(arrayOf(android.Manifest.permission.READ_EXTERNAL_STORAGE), 42)
        }
    }
}
