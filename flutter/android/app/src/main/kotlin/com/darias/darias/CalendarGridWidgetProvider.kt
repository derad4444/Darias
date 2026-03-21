package com.darias.darias

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.*

class CalendarGridWidgetProvider : AppWidgetProvider() {

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

        // Day number TextViews: d_{row}_{col}
        private val DAY_IDS = arrayOf(
            intArrayOf(R.id.d_0_0, R.id.d_0_1, R.id.d_0_2, R.id.d_0_3, R.id.d_0_4, R.id.d_0_5, R.id.d_0_6),
            intArrayOf(R.id.d_1_0, R.id.d_1_1, R.id.d_1_2, R.id.d_1_3, R.id.d_1_4, R.id.d_1_5, R.id.d_1_6),
            intArrayOf(R.id.d_2_0, R.id.d_2_1, R.id.d_2_2, R.id.d_2_3, R.id.d_2_4, R.id.d_2_5, R.id.d_2_6),
            intArrayOf(R.id.d_3_0, R.id.d_3_1, R.id.d_3_2, R.id.d_3_3, R.id.d_3_4, R.id.d_3_5, R.id.d_3_6),
            intArrayOf(R.id.d_4_0, R.id.d_4_1, R.id.d_4_2, R.id.d_4_3, R.id.d_4_4, R.id.d_4_5, R.id.d_4_6),
            intArrayOf(R.id.d_5_0, R.id.d_5_1, R.id.d_5_2, R.id.d_5_3, R.id.d_5_4, R.id.d_5_5, R.id.d_5_6),
        )

        private data class DayScheduleInfo(
            val title: String,
            val colorInt: Int,
            val isAllDay: Boolean,
            val isHoliday: Boolean = false,
            val isOverflow: Boolean = false
        )

        // Schedule TextViews (large only): s_{row}_{col}
        private val SCHED_IDS = arrayOf(
            intArrayOf(R.id.s_0_0, R.id.s_0_1, R.id.s_0_2, R.id.s_0_3, R.id.s_0_4, R.id.s_0_5, R.id.s_0_6),
            intArrayOf(R.id.s_1_0, R.id.s_1_1, R.id.s_1_2, R.id.s_1_3, R.id.s_1_4, R.id.s_1_5, R.id.s_1_6),
            intArrayOf(R.id.s_2_0, R.id.s_2_1, R.id.s_2_2, R.id.s_2_3, R.id.s_2_4, R.id.s_2_5, R.id.s_2_6),
            intArrayOf(R.id.s_3_0, R.id.s_3_1, R.id.s_3_2, R.id.s_3_3, R.id.s_3_4, R.id.s_3_5, R.id.s_3_6),
            intArrayOf(R.id.s_4_0, R.id.s_4_1, R.id.s_4_2, R.id.s_4_3, R.id.s_4_4, R.id.s_4_5, R.id.s_4_6),
            intArrayOf(R.id.s_5_0, R.id.s_5_1, R.id.s_5_2, R.id.s_5_3, R.id.s_5_4, R.id.s_5_5, R.id.s_5_6),
        )

        // Second schedule slot: s2_{row}_{col}
        private val SCHED2_IDS = arrayOf(
            intArrayOf(R.id.s2_0_0, R.id.s2_0_1, R.id.s2_0_2, R.id.s2_0_3, R.id.s2_0_4, R.id.s2_0_5, R.id.s2_0_6),
            intArrayOf(R.id.s2_1_0, R.id.s2_1_1, R.id.s2_1_2, R.id.s2_1_3, R.id.s2_1_4, R.id.s2_1_5, R.id.s2_1_6),
            intArrayOf(R.id.s2_2_0, R.id.s2_2_1, R.id.s2_2_2, R.id.s2_2_3, R.id.s2_2_4, R.id.s2_2_5, R.id.s2_2_6),
            intArrayOf(R.id.s2_3_0, R.id.s2_3_1, R.id.s2_3_2, R.id.s2_3_3, R.id.s2_3_4, R.id.s2_3_5, R.id.s2_3_6),
            intArrayOf(R.id.s2_4_0, R.id.s2_4_1, R.id.s2_4_2, R.id.s2_4_3, R.id.s2_4_4, R.id.s2_4_5, R.id.s2_4_6),
            intArrayOf(R.id.s2_5_0, R.id.s2_5_1, R.id.s2_5_2, R.id.s2_5_3, R.id.s2_5_4, R.id.s2_5_5, R.id.s2_5_6),
        )

        // Third schedule slot: s3_{row}_{col}
        private val SCHED3_IDS = arrayOf(
            intArrayOf(R.id.s3_0_0, R.id.s3_0_1, R.id.s3_0_2, R.id.s3_0_3, R.id.s3_0_4, R.id.s3_0_5, R.id.s3_0_6),
            intArrayOf(R.id.s3_1_0, R.id.s3_1_1, R.id.s3_1_2, R.id.s3_1_3, R.id.s3_1_4, R.id.s3_1_5, R.id.s3_1_6),
            intArrayOf(R.id.s3_2_0, R.id.s3_2_1, R.id.s3_2_2, R.id.s3_2_3, R.id.s3_2_4, R.id.s3_2_5, R.id.s3_2_6),
            intArrayOf(R.id.s3_3_0, R.id.s3_3_1, R.id.s3_3_2, R.id.s3_3_3, R.id.s3_3_4, R.id.s3_3_5, R.id.s3_3_6),
            intArrayOf(R.id.s3_4_0, R.id.s3_4_1, R.id.s3_4_2, R.id.s3_4_3, R.id.s3_4_4, R.id.s3_4_5, R.id.s3_4_6),
            intArrayOf(R.id.s3_5_0, R.id.s3_5_1, R.id.s3_5_2, R.id.s3_5_3, R.id.s3_5_4, R.id.s3_5_5, R.id.s3_5_6),
        )

        private fun isJapaneseHoliday(year: Int, month: Int, day: Int): Boolean {
            if (month == 1 && day == 1) return true
            if (month == 2 && day == 11) return true
            if (month == 2 && day == 23) return true
            if (month == 4 && day == 29) return true
            if (month == 5 && day == 3) return true
            if (month == 5 && day == 4) return true
            if (month == 5 && day == 5) return true
            if (month == 8 && day == 11) return true
            if (month == 11 && day == 3) return true
            if (month == 11 && day == 23) return true
            return when (Triple(year, month, day)) {
                Triple(2024, 1, 8) -> true; Triple(2024, 2, 12) -> true
                Triple(2024, 3, 20) -> true; Triple(2024, 5, 6) -> true
                Triple(2024, 7, 15) -> true; Triple(2024, 8, 12) -> true
                Triple(2024, 9, 16) -> true; Triple(2024, 9, 22) -> true
                Triple(2024, 9, 23) -> true; Triple(2024, 10, 14) -> true
                Triple(2024, 11, 4) -> true
                Triple(2025, 1, 13) -> true; Triple(2025, 2, 24) -> true
                Triple(2025, 3, 20) -> true; Triple(2025, 5, 6) -> true
                Triple(2025, 7, 21) -> true; Triple(2025, 9, 15) -> true
                Triple(2025, 9, 23) -> true; Triple(2025, 10, 13) -> true
                Triple(2025, 11, 24) -> true
                Triple(2026, 1, 12) -> true; Triple(2026, 3, 20) -> true
                Triple(2026, 5, 6) -> true; Triple(2026, 7, 20) -> true
                Triple(2026, 9, 21) -> true; Triple(2026, 9, 23) -> true
                Triple(2026, 10, 12) -> true
                Triple(2027, 1, 11) -> true; Triple(2027, 3, 21) -> true
                Triple(2027, 7, 19) -> true; Triple(2027, 9, 20) -> true
                Triple(2027, 9, 23) -> true; Triple(2027, 10, 11) -> true
                else -> false
            }
        }

        private fun getJapaneseHolidayName(year: Int, month: Int, day: Int): String? {
            val fixed = mapOf(
                Pair(1, 1) to "元日", Pair(2, 11) to "建国記念の日",
                Pair(2, 23) to "天皇誕生日", Pair(4, 29) to "昭和の日",
                Pair(5, 3) to "憲法記念日", Pair(5, 4) to "みどりの日",
                Pair(5, 5) to "こどもの日", Pair(8, 11) to "山の日",
                Pair(11, 3) to "文化の日", Pair(11, 23) to "勤労感謝の日"
            )
            fixed[Pair(month, day)]?.let { return it }
            return when (Triple(year, month, day)) {
                Triple(2024, 1, 8) -> "成人の日"; Triple(2024, 2, 12) -> "振替休日"
                Triple(2024, 3, 20) -> "春分の日"; Triple(2024, 5, 6) -> "振替休日"
                Triple(2024, 7, 15) -> "海の日"; Triple(2024, 8, 12) -> "振替休日"
                Triple(2024, 9, 16) -> "敬老の日"; Triple(2024, 9, 22) -> "振替休日"
                Triple(2024, 9, 23) -> "秋分の日"; Triple(2024, 10, 14) -> "スポーツの日"
                Triple(2024, 11, 4) -> "振替休日"
                Triple(2025, 1, 13) -> "成人の日"; Triple(2025, 2, 24) -> "振替休日"
                Triple(2025, 3, 20) -> "春分の日"; Triple(2025, 5, 6) -> "振替休日"
                Triple(2025, 7, 21) -> "海の日"; Triple(2025, 9, 15) -> "敬老の日"
                Triple(2025, 9, 23) -> "秋分の日"; Triple(2025, 10, 13) -> "スポーツの日"
                Triple(2025, 11, 24) -> "振替休日"
                Triple(2026, 1, 12) -> "成人の日"; Triple(2026, 3, 20) -> "春分の日"
                Triple(2026, 5, 6) -> "振替休日"; Triple(2026, 7, 20) -> "海の日"
                Triple(2026, 9, 21) -> "敬老の日"; Triple(2026, 9, 23) -> "秋分の日"
                Triple(2026, 10, 12) -> "スポーツの日"
                Triple(2027, 1, 11) -> "成人の日"; Triple(2027, 3, 21) -> "春分の日"
                Triple(2027, 7, 19) -> "海の日"; Triple(2027, 9, 20) -> "敬老の日"
                Triple(2027, 9, 23) -> "秋分の日"; Triple(2027, 10, 11) -> "スポーツの日"
                else -> null
            }
        }

        private fun launchPendingIntent(context: Context, appWidgetId: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "es.antonborri.home_widget.action.LAUNCH"
                data = Uri.parse("darias://open/?page=calendar")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context, appWidgetId + 1000, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun renderScheduleSlot(views: RemoteViews, viewId: Int, info: DayScheduleInfo) {
            when {
                info.isOverflow -> {
                    views.setTextViewText(viewId, info.title)
                    views.setTextColor(viewId, Color.parseColor("#888888"))
                    views.setInt(viewId, "setBackgroundColor", Color.TRANSPARENT)
                }
                info.isHoliday -> {
                    views.setTextViewText(viewId, info.title)
                    views.setTextColor(viewId, Color.parseColor("#CC0000"))
                    views.setInt(viewId, "setBackgroundColor", Color.argb(51, 204, 0, 0))
                }
                info.isAllDay -> {
                    views.setTextViewText(viewId, info.title)
                    views.setTextColor(viewId, Color.WHITE)
                    views.setInt(viewId, "setBackgroundColor", info.colorInt)
                }
                else -> {
                    views.setTextViewText(viewId, info.title)
                    views.setTextColor(viewId, info.colorInt)
                    views.setInt(viewId, "setBackgroundColor", Color.TRANSPARENT)
                }
            }
        }

        private fun fillGrid(
            views: RemoteViews,
            today: Calendar,
            daySchedules: Map<Int, List<DayScheduleInfo>>,
            isLarge: Boolean
        ) {
            val year = today.get(Calendar.YEAR)
            val month = today.get(Calendar.MONTH)
            val todayDay = today.get(Calendar.DAY_OF_MONTH)

            val cal = Calendar.getInstance()
            cal.set(year, month, 1)
            val firstWeekday = cal.get(Calendar.DAY_OF_WEEK) - 1 // 0=Sun
            val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)

            val colorToday = Color.WHITE
            val colorSunday = Color.parseColor("#CC0000")
            val colorSaturday = Color.parseColor("#3366CC")
            val colorNormal = Color.parseColor("#333333")

            for (row in 0..5) {
                for (col in 0..6) {
                    val dayId = DAY_IDS[row][col]
                    val day = row * 7 + col - firstWeekday + 1

                    if (day < 1 || day > daysInMonth) {
                        views.setTextViewText(dayId, "")
                        views.setInt(dayId, "setBackgroundColor", Color.TRANSPARENT)
                        if (isLarge) {
                            views.setTextViewText(SCHED_IDS[row][col], "")
                            views.setInt(SCHED_IDS[row][col], "setBackgroundColor", Color.TRANSPARENT)
                        }
                    } else {
                        views.setTextViewText(dayId, "$day")
                        val isToday = day == todayDay
                        val isSunday = col == 0
                        val isSaturday = col == 6
                        val isHoliday = isJapaneseHoliday(year, month + 1, day)
                        val textColor = when {
                            isToday -> colorToday
                            isSunday || isHoliday -> colorSunday
                            isSaturday -> colorSaturday
                            else -> colorNormal
                        }
                        views.setTextColor(dayId, textColor)
                        if (isToday) {
                            views.setInt(dayId, "setBackgroundResource", R.drawable.widget_day_today)
                        } else {
                            views.setInt(dayId, "setBackgroundColor", Color.TRANSPARENT)
                        }
                        if (isLarge) {
                            val allInfos = daySchedules[day] ?: emptyList()
                            val total = allInfos.size
                            val maxDisplay = 3
                            val displayInfos: List<DayScheduleInfo> = if (total > maxDisplay) {
                                val remaining = total - (maxDisplay - 1)
                                allInfos.take(maxDisplay - 1) + DayScheduleInfo(
                                    title = "+$remaining",
                                    colorInt = Color.parseColor("#888888"),
                                    isAllDay = false,
                                    isOverflow = true
                                )
                            } else {
                                allInfos.take(maxDisplay)
                            }
                            val slots = listOf(SCHED_IDS[row][col], SCHED2_IDS[row][col], SCHED3_IDS[row][col])
                            for (i in slots.indices) {
                                val viewId = slots[i]
                                if (i < displayInfos.size) {
                                    renderScheduleSlot(views, viewId, displayInfos[i])
                                } else {
                                    views.setTextViewText(viewId, "")
                                    views.setInt(viewId, "setBackgroundColor", Color.TRANSPARENT)
                                }
                            }
                        }
                    }
                }
            }
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT,
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0))
            val isLarge = maxHeight >= 200
            val pendingIntent = launchPendingIntent(context, appWidgetId)

            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val schedulesJson = prefs.getString("widget_schedules_cache", "[]")
            val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
            val today = Calendar.getInstance()

            val layoutId = if (isLarge) R.layout.calendar_grid_widget_large else R.layout.calendar_grid_widget
            val views = RemoteViews(context.packageName, layoutId)

            try {
                val monthFormat = SimpleDateFormat("yyyy年M月", Locale.JAPAN)
                views.setTextViewText(R.id.month_label, monthFormat.format(today.time))

                val schedules = JSONArray(schedulesJson)
                // day -> up to 2 schedule entries (holiday first, then user schedules)
                val daySchedules = mutableMapOf<Int, MutableList<DayScheduleInfo>>()
                for (i in 0 until schedules.length()) {
                    val s = schedules.getJSONObject(i)
                    val startStr = s.optString("startDate", "")
                    if (startStr.isEmpty()) continue
                    val cleanStr = if (startStr.length > 19) startStr.substring(0, 19) else startStr
                    val startDate = try { dateFormat.parse(cleanStr) } catch (e: Exception) { null } ?: continue
                    val cal = Calendar.getInstance().apply { time = startDate }
                    if (cal.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                        cal.get(Calendar.MONTH) == today.get(Calendar.MONTH)) {
                        val d = cal.get(Calendar.DAY_OF_MONTH)
                        val list = daySchedules.getOrPut(d) { mutableListOf() }
                        val colorHexStr = s.optString("colorHex", "")
                        val colorInt = if (colorHexStr.isNotEmpty()) {
                            try { Color.parseColor(colorHexStr) } catch (e: Exception) { Color.parseColor("#E91E8C") }
                        } else {
                            Color.parseColor("#E91E8C")
                        }
                        list.add(DayScheduleInfo(
                            title = s.optString("title", ""),
                            colorInt = colorInt,
                            isAllDay = s.optBoolean("isAllDay", false)
                        ))
                    }
                }
                // Insert holidays as first entry for each holiday day
                val calTmp = Calendar.getInstance()
                calTmp.set(today.get(Calendar.YEAR), today.get(Calendar.MONTH), 1)
                val daysInMonth = calTmp.getActualMaximum(Calendar.DAY_OF_MONTH)
                val curYear = today.get(Calendar.YEAR)
                val curMonth = today.get(Calendar.MONTH) + 1
                val holidayColor = Color.parseColor("#CC0000")
                for (d in 1..daysInMonth) {
                    val name = getJapaneseHolidayName(curYear, curMonth, d) ?: continue
                    val list = daySchedules.getOrPut(d) { mutableListOf() }
                    list.add(0, DayScheduleInfo(title = name, colorInt = holidayColor, isAllDay = false, isHoliday = true))
                }

                fillGrid(views, today, daySchedules, isLarge)

            } catch (e: Exception) {
                // keep grid empty on error
            }

            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
