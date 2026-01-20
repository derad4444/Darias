package com.darias.darias

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class TodoWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // First widget instance
    }

    override fun onDisabled(context: Context) {
        // Last widget instance removed
    }

    companion object {
        private fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.todo_widget)

            // Get data from SharedPreferences (saved by home_widget)
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val todosJson = prefs.getString("widget_todos_cache", "[]")

            try {
                val todos = JSONArray(todosJson)
                val todoCount = todos.length()

                if (todoCount > 0) {
                    val firstTodo = todos.getJSONObject(0)
                    val title = firstTodo.optString("title", "")
                    val priority = firstTodo.optString("priority", "medium")

                    val priorityIcon = when (priority) {
                        "high" -> "🔴"
                        "medium" -> "🟡"
                        else -> "⚪"
                    }

                    views.setTextViewText(R.id.todo_title, "$priorityIcon $title")
                    views.setTextViewText(R.id.todo_count, "${todoCount}件のタスク")
                } else {
                    views.setTextViewText(R.id.todo_title, "タスクなし")
                    views.setTextViewText(R.id.todo_count, "")
                }
            } catch (e: Exception) {
                views.setTextViewText(R.id.todo_title, "タスクなし")
                views.setTextViewText(R.id.todo_count, "")
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
