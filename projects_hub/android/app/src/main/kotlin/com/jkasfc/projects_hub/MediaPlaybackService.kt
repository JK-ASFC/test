package com.jkasfc.projects_hub

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat

/** What the web player is playing, as sent by the built-in app (Fondu musique). */
data class MediaInfo(
    val title: String = "",
    val artist: String = "",
    val playing: Boolean = false,
    val positionMs: Long = 0,
    val durationMs: Long = 0,
    val hue: Int = 280,
)

/**
 * Media notification + MediaSession for the built-in music player, like
 * YouTube's: title, artwork, ⏮ ⏯ ⏭, −10 s / +10 s and a seek bar (Android
 * 13+), also on the lock screen and Bluetooth headsets. Being a foreground
 * service, it also keeps the app (and the music) alive with the screen off.
 *
 * Buttons are forwarded to Flutter through [onAction], which relays them to
 * the web page.
 */
class MediaPlaybackService : Service() {

    companion object {
        const val CHANNEL_ID = "playback"
        const val NOTIFICATION_ID = 4242
        const val EXTRA_ACTION = "media_action"
        private const val SEEK_STEP_MS = 10_000L
        private const val ACTION_REWIND10 = "rewind"
        private const val ACTION_FORWARD10 = "forward"

        var instance: MediaPlaybackService? = null
            private set

        /** Latest info, applied as soon as the service is created. */
        var pending: MediaInfo? = null

        /** (action, positionMs) -> Flutter. Actions: play, pause, next, prev, seek, rewind, forward, stop. */
        var onAction: ((String, Long) -> Unit)? = null

        fun update(context: Context, info: MediaInfo) {
            val running = instance
            if (running != null) {
                running.apply(info)
                return
            }
            pending = info
            val intent = Intent(context, MediaPlaybackService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (_: Exception) {
                // Android 12+ refuses to start it from the background (e.g. the
                // notification was dismissed while the app was hidden): it
                // comes back at the next update made with the app on screen.
                pending = null
            }
        }

        fun stop(context: Context) {
            pending = null
            context.stopService(Intent(context, MediaPlaybackService::class.java))
        }
    }

    private lateinit var session: MediaSessionCompat
    private var info = MediaInfo()
    private var artKey = ""
    private var art: Bitmap? = null
    private val main = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        createChannel()
        session = MediaSessionCompat(this, "MesProjets").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() = emit("play")
                override fun onPause() = emit("pause")
                override fun onSkipToNext() = emit("next")
                override fun onSkipToPrevious() = emit("prev")
                override fun onStop() = emit("stop")
                override fun onFastForward() = emit(ACTION_FORWARD10)
                override fun onRewind() = emit(ACTION_REWIND10)
                override fun onSeekTo(pos: Long) = emit("seek", pos)
                override fun onCustomAction(action: String?, extras: android.os.Bundle?) {
                    if (action != null) emit(action)
                }
            })
            setSessionActivity(openAppIntent())
            isActive = true
        }
        // Must go foreground right away (startForegroundService contract).
        goForeground()
        pending?.let { apply(it) }
        pending = null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.getStringExtra(EXTRA_ACTION)?.let { emit(it) }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        emit("stop")
        stopSelf()
    }

    override fun onDestroy() {
        instance = null
        holdWakeLock(false)
        session.isActive = false
        session.release()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun emit(action: String, position: Long = -1) {
        main.post { onAction?.invoke(action, position) }
    }

    /** Keeps the CPU awake while music plays with the screen off. */
    private fun holdWakeLock(hold: Boolean) {
        val lock = wakeLock ?: (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "MesProjets:playback")
            .apply { setReferenceCounted(false) }
            .also { wakeLock = it }
        if (hold && !lock.isHeld) lock.acquire(6 * 60 * 60 * 1000L)
        if (!hold && lock.isHeld) lock.release()
    }

    fun apply(newInfo: MediaInfo) {
        info = newInfo
        holdWakeLock(info.playing)
        val key = "${info.title}|${info.hue}"
        if (key != artKey) {
            artKey = key
            art = makeArt(info.title, info.hue)
        }
        session.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, info.title)
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, info.artist)
                .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, "Boom Player")
                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, info.durationMs)
                .putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, art)
                .build(),
        )
        session.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or PlaybackStateCompat.ACTION_SEEK_TO or
                        PlaybackStateCompat.ACTION_FAST_FORWARD or PlaybackStateCompat.ACTION_REWIND or
                        PlaybackStateCompat.ACTION_STOP,
                )
                .addCustomAction(ACTION_REWIND10, "−10 s", R.drawable.ic_media_rewind10)
                .addCustomAction(ACTION_FORWARD10, "+10 s", R.drawable.ic_media_forward10)
                .setState(
                    if (info.playing) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED,
                    info.positionMs,
                    if (info.playing) 1f else 0f,
                    SystemClock.elapsedRealtime(),
                )
                .build(),
        )
        NotificationManagerCompat.from(this).let { nm ->
            if (nm.areNotificationsEnabled()) {
                try {
                    nm.notify(NOTIFICATION_ID, buildNotification())
                } catch (_: SecurityException) {
                    // POST_NOTIFICATIONS refused: the session still works (lock screen, headset).
                }
            }
        }
    }

    private fun goForeground() {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        } else {
            0
        }
        ServiceCompat.startForeground(this, NOTIFICATION_ID, buildNotification(), type)
    }

    private fun buildNotification() = NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(R.drawable.ic_stat_music)
        .setContentTitle(info.title.ifEmpty { "Boom Player" })
        .setContentText(info.artist)
        .setSubText("Fondu musique")
        .setLargeIcon(art)
        .setContentIntent(openAppIntent())
        .setDeleteIntent(actionIntent("stop", 9))
        .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        .setOnlyAlertOnce(true)
        .setShowWhen(false)
        .setOngoing(info.playing)
        .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
        .addAction(R.drawable.ic_media_prev, "Précédent", actionIntent("prev", 1))
        .addAction(R.drawable.ic_media_rewind10, "−10 s", actionIntent(ACTION_REWIND10, 2))
        .addAction(
            if (info.playing) R.drawable.ic_media_pause else R.drawable.ic_media_play,
            if (info.playing) "Pause" else "Lecture",
            actionIntent(if (info.playing) "pause" else "play", 3),
        )
        .addAction(R.drawable.ic_media_forward10, "+10 s", actionIntent(ACTION_FORWARD10, 4))
        .addAction(R.drawable.ic_media_next, "Suivant", actionIntent("next", 5))
        .setStyle(
            androidx.media.app.NotificationCompat.MediaStyle()
                .setMediaSession(session.sessionToken)
                .setShowActionsInCompactView(0, 2, 4),
        )
        .build()

    private fun actionIntent(action: String, code: Int): PendingIntent = PendingIntent.getService(
        this,
        code,
        Intent(this, MediaPlaybackService::class.java).putExtra(EXTRA_ACTION, action),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun openAppIntent(): PendingIntent {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        return PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(CHANNEL_ID, "Lecture en cours", NotificationManager.IMPORTANCE_LOW).apply {
            description = "Commandes de la musique (Fondu musique)"
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    /** Square artwork: gradient in the track's colour with its initials (like the in-app cover). */
    private fun makeArt(title: String, hue: Int): Bitmap {
        val size = 320
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val c1 = Color.HSVToColor(floatArrayOf(hue.toFloat(), 0.72f, 0.92f))
        val c2 = Color.HSVToColor(floatArrayOf(((hue + 50) % 360).toFloat(), 0.75f, 0.95f))
        val bg = Paint().apply {
            shader = LinearGradient(0f, 0f, size.toFloat(), size.toFloat(), c1, c2, Shader.TileMode.CLAMP)
        }
        canvas.drawRect(0f, 0f, size.toFloat(), size.toFloat(), bg)
        val words = title.split(Regex("\\s+")).filter { it.isNotEmpty() }
        val initials = when {
            words.size > 1 -> "${words[0].first()}${words[1].first()}"
            words.size == 1 -> words[0].take(2)
            else -> "♪"
        }.uppercase()
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(235, 255, 255, 255)
            textSize = size * 0.36f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }
        val y = size / 2f - (text.descent() + text.ascent()) / 2f
        canvas.drawText(initials, size / 2f, y, text)
        return bmp
    }
}
