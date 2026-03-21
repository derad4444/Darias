package com.darias.darias

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray

class MemoWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private data class MemoRowIds(val rowId: Int, val titleId: Int, val contentId: Int, val dateId: Int, val pinId: Int)

        private val ROW_IDS = listOf(
            MemoRowIds(R.id.memo_row_1, R.id.memo_title_1, R.id.memo_content_1, R.id.memo_date_1, R.id.memo_pin_1),
            MemoRowIds(R.id.memo_row_2, R.id.memo_title_2, R.id.memo_content_2, R.id.memo_date_2, R.id.memo_pin_2),
            MemoRowIds(R.id.memo_row_3, R.id.memo_title_3, R.id.memo_content_3, R.id.memo_date_3, R.id.memo_pin_3),
            MemoRowIds(R.id.memo_row_4, R.id.memo_title_4, R.id.memo_content_4, R.id.memo_date_4, R.id.memo_pin_4),
            MemoRowIds(R.id.memo_row_5, R.id.memo_title_5, R.id.memo_content_5, R.id.memo_date_5, R.id.memo_pin_5),
        )

        private fun launchPendingIntent(context: Context, appWidgetId: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "es.antonborri.home_widget.action.LAUNCH"
                data = Uri.parse("darias://open/?page=memo")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context, appWidgetId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0))
            val pendingIntent = launchPendingIntent(context, appWidgetId)
            val isLarge = minHeight >= 200

            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val memosJson = prefs.getString("widget_memos_cache", "[]")
            val totalCount = prefs.getInt("widget_memos_total_count", 0)

            if (isLarge) {
                val views = RemoteViews(context.packageName, R.layout.memo_widget_large)
                try {
                    val memos = JSONArray(memosJson)
                    views.setTextViewText(R.id.memo_count, "${totalCount}件のメモ")
                    if (memos.length() == 0) {
                        views.setViewVisibility(R.id.memo_empty, View.VISIBLE)
                    } else {
                        views.setViewVisibility(R.id.memo_empty, View.GONE)
                        for (i in 0 until minOf(5, memos.length())) {
                            val memo = memos.getJSONObject(i)
                            val title = memo.optString("title", "")
                            val content = memo.optString("content", "")
                            val isPinned = memo.optBoolean("isPinned", false)
                            val updatedAt = memo.optString("updatedAt", "")
                            val dateStr = if (updatedAt.length >= 10) updatedAt.substring(0, 10) else ""
                            val row = ROW_IDS[i]
                            views.setViewVisibility(row.rowId, View.VISIBLE)
                            views.setTextViewText(row.titleId, title)
                            views.setTextViewText(row.contentId, content)
                            views.setTextViewText(row.dateId, dateStr)
                            if (isPinned) {
                                views.setViewVisibility(row.pinId, View.VISIBLE)
                                views.setTextViewText(row.pinId, "📌")
                            } else {
                                views.setViewVisibility(row.pinId, View.GONE)
                            }
                        }
                    }
                } catch (e: Exception) {
                    views.setViewVisibility(R.id.memo_empty, View.VISIBLE)
                }
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } else {
                val views = RemoteViews(context.packageName, R.layout.memo_widget)
                try {
                    val memos = JSONArray(memosJson)
                    if (memos.length() > 0) {
                        val firstMemo = memos.getJSONObject(0)
                        val title = firstMemo.optString("title", "")
                        val content = firstMemo.optString("content", "")
                        val isPinned = firstMemo.optBoolean("isPinned", false)
                        val displayTitle = if (isPinned) "📌 $title" else title
                        val previewContent = if (content.length > 50) content.substring(0, 50) + "..." else content
                        views.setTextViewText(R.id.memo_title, displayTitle)
                        views.setTextViewText(R.id.memo_content, previewContent)
                        views.setTextViewText(R.id.memo_count, "${totalCount}件のメモ")
                    } else {
                        views.setTextViewText(R.id.memo_title, "メモなし")
                        views.setTextViewText(R.id.memo_content, "")
                        views.setTextViewText(R.id.memo_count, "")
                    }
                } catch (e: Exception) {
                    views.setTextViewText(R.id.memo_title, "メモなし")
                    views.setTextViewText(R.id.memo_content, "")
                    views.setTextViewText(R.id.memo_count, "")
                }
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }
    }
}
