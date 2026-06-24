package com.xiaoxin.binance_alpha

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AppWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        // 拦截自定义定时刷新广播，直接跑 onUpdate
        if (intent.action == ACTION_REFRESH) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                android.content.ComponentName(context, AppWidgetProvider::class.java)
            )
            onUpdate(context, mgr, ids)
            return
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            // 先渲染基本布局
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            views.setTextViewText(R.id.widget_checkin_count, "--")
            views.setTextViewText(R.id.widget_airdrop_count, "0")
            views.setTextViewText(R.id.widget_warning_count, "0")

            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pi = PendingIntent.getActivity(context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_root, pi)
            appWidgetManager.updateAppWidget(appWidgetId, views)

            // 拉取数据
            fetchAndUpdate(context, appWidgetManager, appWidgetId)
        }

        // 调度 10 秒后的下一次定时刷新（AlarmManager 是系统级，进程被杀也能唤醒）
        scheduleNextRefresh(context)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(
            android.content.ComponentName(context, AppWidgetProvider::class.java)
        )
        onUpdate(context, mgr, ids)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        val alarmMgr = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = buildRefreshPendingIntent(context)
        alarmMgr.cancel(pi)
    }

    private fun buildRefreshPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, AppWidgetProvider::class.java).apply {
            action = ACTION_REFRESH
        }
        return PendingIntent.getBroadcast(context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun scheduleNextRefresh(context: Context) {
        val alarmMgr = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = buildRefreshPendingIntent(context)
        val triggerAt = System.currentTimeMillis() + 10000

        try {
            // setAlarmClock 强制唤醒，无视所有省电/后台限制，无需任何权限
            alarmMgr.setAlarmClock(
                AlarmManager.AlarmClockInfo(triggerAt, null),
                pi
            )
        } catch (_: Exception) {
            // 极少数设备可能不支持 setAlarmClock，降级到 setExact
            try {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                    alarmMgr.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                } else {
                    alarmMgr.set(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                }
            } catch (_: Exception) {
                // 最坏情况：Handler 兜底（仅 App 存活时有效）
                Handler(Looper.getMainLooper()).postDelayed({
                    val mgr = AppWidgetManager.getInstance(context)
                    val ids = mgr.getAppWidgetIds(
                        android.content.ComponentName(context, AppWidgetProvider::class.java)
                    )
                    onUpdate(context, mgr, ids)
                }, 10000)
            }
        }
    }

    private fun fetchAndUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        Thread {
            try {
                val json = fetchData()
                if (json != null) {
                    context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        .edit().putString(KEY_DATA, json).apply()
                    Handler(Looper.getMainLooper()).post {
                        refreshUi(context, appWidgetManager, appWidgetId, json)
                    }
                }
            } catch (_: Exception) {
                val cached = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .getString(KEY_DATA, null)
                if (cached != null) {
                    Handler(Looper.getMainLooper()).post {
                        refreshUi(context, appWidgetManager, appWidgetId, cached)
                    }
                }
            }
        }.start()
    }

    companion object {
        private const val PREFS_NAME = "widget_prefs"
        private const val KEY_DATA = "widget_data"
        private const val ACTION_REFRESH = "com.xiaoxin.binance_alpha.WIDGET_REFRESH"

        fun updateFromApp(context: Context, jsonData: String) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit().putString(KEY_DATA, jsonData).apply()
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                android.content.ComponentName(context, AppWidgetProvider::class.java)
            )
            for (id in ids) {
                refreshUi(context, mgr, id, jsonData)
            }
        }

        private fun refreshUi(
            context: Context, mgr: AppWidgetManager, id: Int, jsonStr: String
        ) {
            try {
                val json = JSONObject(jsonStr)
                val views = RemoteViews(context.packageName, R.layout.widget_layout)

                val checkin = json.optInt("today_checkin", 0)
                views.setTextViewText(R.id.widget_checkin_count, String.format("%,d", checkin))
                views.setTextViewText(R.id.widget_airdrop_count, json.optInt("today_airdrop_count", 0).toString())
                views.setTextViewText(R.id.widget_warning_count, json.optInt("warning_count", 0).toString())

                val airdrops = json.optJSONArray("latest_airdrops")
                val aId = listOf(R.id.widget_airdrop_1, R.id.widget_airdrop_2, R.id.widget_airdrop_3)
                for (i in 0 until 3) {
                    if (airdrops != null && i < airdrops.length()) {
                        val item = airdrops.getJSONObject(i)
                        val name = item.optString("name", "")
                        val token = item.optString("token", "")
                        val display = if (name.isNotEmpty()) name else token
                        val time = item.optString("time", "")
                        val points = item.optString("points", "")
                        val prefix = if (item.optString("type") == "warning") "⚠️ " else ""
                        views.setTextViewText(aId[i], "$prefix$display  $time  $points")
                    } else {
                        views.setTextViewText(aId[i], "")
                    }
                }

                val now = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date())
                views.setTextViewText(R.id.widget_update_time, "更新 $now")

                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pi = PendingIntent.getActivity(context, 0, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(R.id.widget_root, pi)

                mgr.updateAppWidget(id, views)
            } catch (_: Exception) { }
        }

        private fun fetchData(): String? {
            return try {
                val conn = URL("https://alpha123.uk/api/data?fresh=1").openConnection() as HttpURLConnection
                conn.requestMethod = "GET"
                conn.setRequestProperty("User-Agent", "Mozilla/5.0")
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                if (conn.responseCode != 200) return null
                val body = BufferedReader(InputStreamReader(conn.inputStream)).readText()
                conn.disconnect()

                val root = JSONObject(body)
                val result = JSONObject()

                result.put("bnb_price", root.optDouble("bnb_price_usd", 0.0))

                val checkins = root.optJSONArray("alpha_checkins")
                if (checkins != null) {
                    for (i in 0 until checkins.length()) {
                        val c = checkins.getJSONObject(i)
                        if (c.optString("key") == "today") {
                            result.put("today_checkin", c.optInt("count", 0))
                            break
                        }
                    }
                }

                val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
                val raw = root.optJSONArray("airdrops")
                val filtered = JSONArray()
                var aCount = 0
                var wCount = 0
                if (raw != null) {
                    for (i in 0 until raw.length()) {
                        val item = raw.getJSONObject(i)
                        val date = item.optString("date", "")
                        if (date.isEmpty() || date >= today) {
                            filtered.put(item)
                            if (item.optString("type") == "warning") wCount++ else aCount++
                        }
                    }
                }
                result.put("today_airdrop_count", aCount)
                result.put("warning_count", wCount)

                val latest = JSONArray()
                for (i in 0 until minOf(filtered.length(), 3)) {
                    latest.put(filtered.getJSONObject(i))
                }
                result.put("latest_airdrops", latest)

                result.toString()
            } catch (_: Exception) { null }
        }
    }
}
