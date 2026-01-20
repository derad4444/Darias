package com.darias.darias

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
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
        private fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.memo_widget)

            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val memosJson = prefs.getString("widget_memos_cache", "[]")
            val totalCount = prefs.getInt("widget_memos_total_count", 0)

            try {
                val memos = JSONArray(memosJson)

                if (memos.length() > 0) {
                    val firstMemo = memos.getJSONObject(0)
                    val title = firstMemo.optString("title", "")
                    val content = firstMemo.optString("content", "")
                    val isPinned = firstMemo.optBoolean("isPinned", false)

                    val displayTitle = if (isPinned) "📌 $title" else title
                    val previewContent = if (content.length > 50) {
                        content.substring(0, 50) + "..."
                    } else {
                        content
                    }

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

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
