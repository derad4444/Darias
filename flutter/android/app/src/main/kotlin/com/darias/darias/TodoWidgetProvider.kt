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

    companion object {
        private val ROW_IDS = listOf(
            Triple(R.id.todo_row_1, R.id.todo_priority_1, R.id.todo_title_1),
            Triple(R.id.todo_row_2, R.id.todo_priority_2, R.id.todo_title_2),
            Triple(R.id.todo_row_3, R.id.todo_priority_3, R.id.todo_title_3),
            Triple(R.id.todo_row_4, R.id.todo_priority_4, R.id.todo_title_4),
            Triple(R.id.todo_row_5, R.id.todo_priority_5, R.id.todo_title_5),
            Triple(R.id.todo_row_6, R.id.todo_priority_6, R.id.todo_title_6),
            Triple(R.id.todo_row_7, R.id.todo_priority_7, R.id.todo_title_7),
            Triple(R.id.todo_row_8, R.id.todo_priority_8, R.id.todo_title_8),
        )
        private val DUE_IDS = listOf(
            R.id.todo_due_1, R.id.todo_due_2, R.id.todo_due_3, R.id.todo_due_4,
            R.id.todo_due_5, R.id.todo_due_6, R.id.todo_due_7, R.id.todo_due_8,
        )

        private fun launchPendingIntent(context: Context, appWidgetId: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "es.antonborri.home_widget.action.LAUNCH"
                data = Uri.parse("darias://open/?page=todo")
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
            val isLarge = minHeight >= 200
            val pendingIntent = launchPendingIntent(context, appWidgetId)

            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val todosJson = prefs.getString("widget_todos_cache", "[]")

            if (isLarge) {
                val views = RemoteViews(context.packageName, R.layout.todo_widget_large)
                try {
                    val todos = JSONArray(todosJson)
                    val count = todos.length()
                    views.setTextViewText(R.id.todo_count, "${count}件のタスク")

                    if (count == 0) {
                        views.setViewVisibility(R.id.todo_empty, View.VISIBLE)
                    } else {
                        views.setViewVisibility(R.id.todo_empty, View.GONE)
                        for (i in 0 until minOf(8, count)) {
                            val todo = todos.getJSONObject(i)
                            val title = todo.optString("title", "")
                            val priority = todo.optString("priority", "medium")
                            val dueDate = todo.optString("dueDate", "")
                            val priorityIcon = when (priority) {
                                "high" -> "🔴"
                                "medium" -> "🟡"
                                else -> "⚪"
                            }
                            val (rowId, priorityId, titleId) = ROW_IDS[i]
                            views.setViewVisibility(rowId, View.VISIBLE)
                            views.setTextViewText(priorityId, priorityIcon)
                            views.setTextViewText(titleId, title)
                            views.setTextViewText(DUE_IDS[i], if (dueDate.isNotEmpty()) dueDate.substring(0, minOf(10, dueDate.length)) else "")
                        }
                    }
                } catch (e: Exception) {
                    views.setViewVisibility(R.id.todo_empty, View.VISIBLE)
                }
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } else {
                val views = RemoteViews(context.packageName, R.layout.todo_widget)
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
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }
    }
}
