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
        private data class DayRowIds(val rowId: Int, val timeId: Int, val titleId: Int)

        private val TODAY_ROWS = listOf(
            DayRowIds(R.id.today_row_1, R.id.today_time_1, R.id.today_title_1),
            DayRowIds(R.id.today_row_2, R.id.today_time_2, R.id.today_title_2),
            DayRowIds(R.id.today_row_3, R.id.today_time_3, R.id.today_title_3),
            DayRowIds(R.id.today_row_4, R.id.today_time_4, R.id.today_title_4),
        )
        private val TOMORROW_ROWS = listOf(
            DayRowIds(R.id.tomorrow_row_1, R.id.tomorrow_time_1, R.id.tomorrow_title_1),
            DayRowIds(R.id.tomorrow_row_2, R.id.tomorrow_time_2, R.id.tomorrow_title_2),
            DayRowIds(R.id.tomorrow_row_3, R.id.tomorrow_time_3, R.id.tomorrow_title_3),
        )
        private val DAYAFTER_ROWS = listOf(
            DayRowIds(R.id.dayafter_row_1, R.id.dayafter_time_1, R.id.dayafter_title_1),
            DayRowIds(R.id.dayafter_row_2, R.id.dayafter_time_2, R.id.dayafter_title_2),
            DayRowIds(R.id.dayafter_row_3, R.id.dayafter_time_3, R.id.dayafter_title_3),
        )

        private fun launchPendingIntent(context: Context, appWidgetId: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "es.antonborri.home_widget.action.LAUNCH"
                data = Uri.parse("darias://open/?page=calendar")
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
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            val isLarge = minHeight >= 200
            val pendingIntent = launchPendingIntent(context, appWidgetId)

            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val schedulesJson = prefs.getString("widget_schedules_cache", "[]")

            val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
            val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
            val today = Calendar.getInstance()

            if (isLarge) {
                val views = RemoteViews(context.packageName, R.layout.calendar_widget_large)
                try {
                    val schedules = JSONArray(schedulesJson)
                    val cal2 = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
                    val cal3 = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 2) }

                    val todayList = mutableListOf<Pair<String, String>>()
                    val tomorrowList = mutableListOf<Pair<String, String>>()
                    val dayAfterList = mutableListOf<Pair<String, String>>()

                    for (i in 0 until schedules.length()) {
                        val s = schedules.getJSONObject(i)
                        val startStr = s.optString("startDate", "")
                        if (startStr.isEmpty()) continue
                        val cleanStr = if (startStr.length > 19) startStr.substring(0, 19) else startStr
                        val startDate = try { dateFormat.parse(cleanStr) } catch (e: Exception) { null } ?: continue
                        val cal = Calendar.getInstance().apply { time = startDate }
                        val isAllDay = s.optBoolean("isAllDay", false)
                        val title = s.optString("title", "")
                        val timeStr = if (isAllDay) "終日" else timeFormat.format(startDate)

                        fun isSameDay(a: Calendar, b: Calendar) =
                            a.get(Calendar.YEAR) == b.get(Calendar.YEAR) &&
                            a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)

                        when {
                            isSameDay(cal, today) -> todayList.add(timeStr to title)
                            isSameDay(cal, cal2) -> tomorrowList.add(timeStr to title)
                            isSameDay(cal, cal3) -> dayAfterList.add(timeStr to title)
                        }
                    }

                    fun fillSection(list: List<Pair<String, String>>, rows: List<DayRowIds>, emptyId: Int) {
                        if (list.isEmpty()) {
                            views.setViewVisibility(emptyId, View.VISIBLE)
                        } else {
                            views.setViewVisibility(emptyId, View.GONE)
                            for (i in 0 until minOf(rows.size, list.size)) {
                                val (time, title) = list[i]
                                views.setViewVisibility(rows[i].rowId, View.VISIBLE)
                                views.setTextViewText(rows[i].timeId, time)
                                views.setTextViewText(rows[i].titleId, title)
                            }
                        }
                    }

                    fillSection(todayList, TODAY_ROWS, R.id.today_empty)
                    fillSection(tomorrowList, TOMORROW_ROWS, R.id.tomorrow_empty)
                    fillSection(dayAfterList, DAYAFTER_ROWS, R.id.dayafter_empty)

                } catch (e: Exception) {
                    views.setViewVisibility(R.id.today_empty, View.VISIBLE)
                    views.setViewVisibility(R.id.tomorrow_empty, View.VISIBLE)
                    views.setViewVisibility(R.id.dayafter_empty, View.VISIBLE)
                }
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } else {
                val views = RemoteViews(context.packageName, R.layout.calendar_widget)
                try {
                    val schedules = JSONArray(schedulesJson)
                    var todayTitle = "予定なし"
                    var todayTime = ""

                    for (i in 0 until schedules.length()) {
                        val s = schedules.getJSONObject(i)
                        val startStr = s.optString("startDate", "")
                        if (startStr.isEmpty()) continue
                        val cleanStr = if (startStr.length > 19) startStr.substring(0, 19) else startStr
                        val startDate = try { dateFormat.parse(cleanStr) } catch (e: Exception) { null } ?: continue
                        val cal = Calendar.getInstance().apply { time = startDate }
                        if (cal.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                            cal.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)) {
                            val isAllDay = s.optBoolean("isAllDay", false)
                            todayTitle = s.optString("title", "")
                            todayTime = if (isAllDay) "終日" else timeFormat.format(startDate)
                            break
                        }
                    }
                    views.setTextViewText(R.id.schedule_title, todayTitle)
                    views.setTextViewText(R.id.schedule_time, todayTime)
                    val todayFormat = SimpleDateFormat("M月d日(E)", Locale.JAPAN)
                    views.setTextViewText(R.id.today_date, todayFormat.format(today.time))
                } catch (e: Exception) {
                    views.setTextViewText(R.id.schedule_title, "予定なし")
                    views.setTextViewText(R.id.schedule_time, "")
                }
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }
    }
}
