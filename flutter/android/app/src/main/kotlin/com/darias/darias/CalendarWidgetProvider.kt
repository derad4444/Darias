package com.darias.darias

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.*

class CalendarWidgetProvider : AppWidgetProvider() {

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
            val views = RemoteViews(context.packageName, R.layout.calendar_widget)

            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val schedulesJson = prefs.getString("widget_schedules_cache", "[]")

            try {
                val schedules = JSONArray(schedulesJson)
                val today = Calendar.getInstance()
                val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
                val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())

                var todayScheduleTitle = "予定なし"
                var todayScheduleTime = ""

                for (i in 0 until schedules.length()) {
                    val schedule = schedules.getJSONObject(i)
                    val startDateStr = schedule.optString("startDate", "")

                    if (startDateStr.isNotEmpty()) {
                        val startDate = dateFormat.parse(startDateStr)
                        if (startDate != null) {
                            val scheduleCalendar = Calendar.getInstance()
                            scheduleCalendar.time = startDate

                            if (scheduleCalendar.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                                scheduleCalendar.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)
                            ) {
                                val isAllDay = schedule.optBoolean("isAllDay", false)
                                todayScheduleTitle = schedule.optString("title", "")
                                todayScheduleTime = if (isAllDay) "終日" else timeFormat.format(startDate)
                                break
                            }
                        }
                    }
                }

                views.setTextViewText(R.id.schedule_title, todayScheduleTitle)
                views.setTextViewText(R.id.schedule_time, todayScheduleTime)

                // Show today's date
                val todayFormat = SimpleDateFormat("M月d日(E)", Locale.JAPAN)
                views.setTextViewText(R.id.today_date, todayFormat.format(today.time))

            } catch (e: Exception) {
                views.setTextViewText(R.id.schedule_title, "予定なし")
                views.setTextViewText(R.id.schedule_time, "")
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
