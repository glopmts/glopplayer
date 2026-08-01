package com.glopblog.glopplayer

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import java.io.File
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class PlayerWidgetProvider : AppWidgetProvider() {
  private companion object {
    private const val PREFERENCES_NAME = "HomeWidgetPreferences"
  }

  override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
    appWidgetIds.forEach { updateAppWidget(context, appWidgetManager, it) }
  }

  override fun onReceive(context: Context, intent: Intent) {
    super.onReceive(context, intent)
    if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
      val appWidgetManager = AppWidgetManager.getInstance(context)
      val appWidgetIds = appWidgetManager.getAppWidgetIds(
        ComponentName(context, PlayerWidgetProvider::class.java),
      )
      appWidgetIds.forEach { updateAppWidget(context, appWidgetManager, it) }
    }
  }

  private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
    val preferences: SharedPreferences =
      context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    val title = preferences.getString("title", "")?.takeIf { it.isNotBlank() } ?: "GlopPlay"
    val artist = preferences.getString("artist", "")?.takeIf { it.isNotBlank() } ?: "Reprodução"
    val artworkPath = preferences.getString("artworkPath", "") ?: ""
    val isPlaying = preferences.getBoolean("isPlaying", false)

    val views = RemoteViews(context.packageName, R.layout.player_widget_layout)
    views.setTextViewText(R.id.widget_title, title)
    views.setTextViewText(R.id.widget_artist, artist)
    views.setImageViewResource(
      R.id.widget_play_pause,
      if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
    )

    if (artworkPath.isNotBlank()) {
      try {
        val artworkFile = File(artworkPath)
        if (artworkFile.exists()) {
          val bitmap = BitmapFactory.decodeFile(artworkFile.absolutePath)
          if (bitmap != null) {
            views.setImageViewBitmap(R.id.widget_artwork, bitmap)
          } else {
            views.setImageViewResource(R.id.widget_artwork, R.mipmap.ic_launcher)
          }
        } else {
          views.setImageViewResource(R.id.widget_artwork, R.mipmap.ic_launcher)
        }
      } catch (ignored: Exception) {
        views.setImageViewResource(R.id.widget_artwork, R.mipmap.ic_launcher)
      }
    } else {
      views.setImageViewResource(R.id.widget_artwork, R.mipmap.ic_launcher)
    }

    views.setOnClickPendingIntent(
      R.id.widget_container,
      HomeWidgetLaunchIntent.getActivity(
        context,
        MainActivity::class.java,
        Uri.parse("glopplayer://open"),
      ),
    )

    views.setOnClickPendingIntent(
      R.id.widget_previous,
      HomeWidgetLaunchIntent.getActivity(
        context,
        MainActivity::class.java,
        Uri.parse("glopplayer://previous"),
      ),
    )
    views.setOnClickPendingIntent(
      R.id.widget_play_pause,
      HomeWidgetLaunchIntent.getActivity(
        context,
        MainActivity::class.java,
        Uri.parse("glopplayer://playPause"),
      ),
    )
    views.setOnClickPendingIntent(
      R.id.widget_next,
      HomeWidgetLaunchIntent.getActivity(
        context,
        MainActivity::class.java,
        Uri.parse("glopplayer://next"),
      ),
    )

    appWidgetManager.updateAppWidget(appWidgetId, views)
  }
}
