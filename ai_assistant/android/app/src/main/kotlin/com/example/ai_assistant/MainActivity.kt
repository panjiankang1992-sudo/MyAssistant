package com.example.ai_assistant

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.os.Build
import android.provider.CalendarContract
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val channelName = "my_assistant/calendar"
    private val reminderChannelName = "my_assistant/todo_reminders"
    private val calendarRequestCode = 4201
    private val notificationRequestCode = 4202
    private var pendingRange: Pair<Long, Long>? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "openCalendar") {
                    result.success(openCalendarApp())
                    return@setMethodCallHandler
                }
                if (call.method != "fetchEvents") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val startMillis = call.argument<Long>("startMillis")
                val endMillis = call.argument<Long>("endMillis")
                if (startMillis == null || endMillis == null) {
                    result.error("bad_args", "缺少日历查询时间范围", null)
                    return@setMethodCallHandler
                }
                if (ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.READ_CALENDAR
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    pendingRange = Pair(startMillis, endMillis)
                    pendingResult = result
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.READ_CALENDAR),
                        calendarRequestCode
                    )
                    return@setMethodCallHandler
                }
                result.success(queryCalendarEvents(startMillis, endMillis))
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, reminderChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        val id = call.argument<String>("id")
                        val title = call.argument<String>("title")
                        val body = call.argument<String>("body")
                        val fireAtMillis = call.argument<Long>("fireAtMillis")
                        if (id == null || title == null || body == null || fireAtMillis == null) {
                            result.error("bad_args", "缺少提醒参数", null)
                            return@setMethodCallHandler
                        }
                        requestNotificationPermissionIfNeeded()
                        scheduleTodoReminder(id, title, body, fireAtMillis)
                        result.success(null)
                    }
                    "cancel" -> {
                        val id = call.argument<String>("id")
                        if (id == null) {
                            result.error("bad_args", "缺少提醒 ID", null)
                            return@setMethodCallHandler
                        }
                        cancelTodoReminder(id)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != calendarRequestCode) return
        val result = pendingResult ?: return
        val range = pendingRange
        pendingResult = null
        pendingRange = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED && range != null) {
            result.success(queryCalendarEvents(range.first, range.second))
        } else {
            result.error("calendar_denied", "没有日历访问权限", null)
        }
    }

    private fun queryCalendarEvents(startMillis: Long, endMillis: Long): List<Map<String, Any?>> {
        val projection = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.DESCRIPTION,
            CalendarContract.Instances.EVENT_LOCATION,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.ALL_DAY
        )
        val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
        ContentUris.appendId(builder, startMillis)
        ContentUris.appendId(builder, endMillis)
        val cursor: Cursor? = contentResolver.query(
            builder.build(),
            projection,
            null,
            null,
            "${CalendarContract.Instances.BEGIN} ASC"
        )
        val events = mutableListOf<Map<String, Any?>>()
        cursor?.use {
            val idIndex = it.getColumnIndexOrThrow(CalendarContract.Instances.EVENT_ID)
            val titleIndex = it.getColumnIndexOrThrow(CalendarContract.Instances.TITLE)
            val descriptionIndex = it.getColumnIndexOrThrow(CalendarContract.Instances.DESCRIPTION)
            val locationIndex = it.getColumnIndexOrThrow(CalendarContract.Instances.EVENT_LOCATION)
            val startIndex = it.getColumnIndexOrThrow(CalendarContract.Instances.BEGIN)
            val endIndex = it.getColumnIndexOrThrow(CalendarContract.Instances.END)
            val allDayIndex = it.getColumnIndexOrThrow(CalendarContract.Instances.ALL_DAY)
            while (it.moveToNext()) {
                val id = it.getLong(idIndex).toString()
                val title = it.getString(titleIndex) ?: continue
                val start = it.getLong(startIndex)
                val end = if (it.isNull(endIndex)) start else it.getLong(endIndex)
                events.add(
                    mapOf(
                        "id" to "android-event-$id-$start",
                        "title" to title,
                        "notes" to (it.getString(descriptionIndex) ?: ""),
                        "location" to (it.getString(locationIndex) ?: ""),
                        "startMillis" to start,
                        "endMillis" to end,
                        "allDay" to (it.getInt(allDayIndex) == 1),
                        "platform" to "android",
                        "sourceType" to "event"
                    )
                )
            }
        }
        return events
    }

    private fun openCalendarApp(): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_APP_CALENDAR)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            try {
                val intent = Intent(Intent.ACTION_VIEW)
                    .setData(CalendarContract.CONTENT_URI)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun scheduleTodoReminder(
        id: String,
        title: String,
        body: String,
        fireAtMillis: Long
    ) {
        if (fireAtMillis <= System.currentTimeMillis()) return
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = reminderPendingIntent(id, title, body)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
            alarmManager.set(AlarmManager.RTC_WAKEUP, fireAtMillis, pendingIntent)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                fireAtMillis,
                pendingIntent
            )
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, fireAtMillis, pendingIntent)
        }
    }

    private fun cancelTodoReminder(id: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(reminderPendingIntent(id, "", ""))
    }

    private fun reminderPendingIntent(
        id: String,
        title: String,
        body: String
    ): PendingIntent {
        val intent = Intent(this, TodoReminderReceiver::class.java).apply {
            putExtra(TodoReminderReceiver.EXTRA_ID, id)
            putExtra(TodoReminderReceiver.EXTRA_TITLE, title)
            putExtra(TodoReminderReceiver.EXTRA_BODY, body)
        }
        return PendingIntent.getBroadcast(
            this,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        ) return
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationRequestCode
        )
    }
}
