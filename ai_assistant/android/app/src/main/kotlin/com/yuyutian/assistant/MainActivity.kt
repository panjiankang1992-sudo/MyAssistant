package com.yuyutian.assistant

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.CalendarContract
import android.provider.Settings
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val channelName = "my_assistant/calendar"
    private val smsChannelName = "my_assistant/sms"
    private val reminderChannelName = "my_assistant/todo_reminders"
    private val permissionsChannelName = "my_assistant/permissions"
    private val appLauncherChannelName = "my_assistant/app_launcher"
    private val calendarRequestCode = 4201
    private val notificationRequestCode = 4202
    private val smsRequestCode = 4203
    private val voiceRequestCode = 4204
    private var pendingRange: Pair<Long, Long>? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingSmsDays: Int = 7
    private var pendingSmsResult: MethodChannel.Result? = null
    private var pendingNotificationResult: MethodChannel.Result? = null
    private var pendingCalendarAuthResult: MethodChannel.Result? = null
    private var pendingSmsAuthResult: MethodChannel.Result? = null
    private var pendingVoiceAuthResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permissionsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openPermissionSettings" -> {
                        val target = call.argument<String>("target") ?: ""
                        openPermissionSettings(target, result)
                    }
                    "openAuthorizationSettings", "openAppSettings" -> {
                        result.success(openAppSettings())
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appLauncherChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listApps" -> result.success(queryLaunchableApps())
                    "openApp" -> {
                        val packageName = call.argument<String>("packageName")
                            ?: call.argument<String>("id")
                        val activityName = call.argument<String>("activityName")
                        if (packageName.isNullOrBlank()) {
                            result.error("bad_args", "缺少应用包名", null)
                            return@setMethodCallHandler
                        }
                        result.success(openInstalledApp(packageName, activityName))
                    }
                    else -> result.notImplemented()
                }
            }
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, smsChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "fetchRecent") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val days = call.argument<Int>("days") ?: 7
                if (ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.READ_SMS
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    pendingSmsDays = days
                    pendingSmsResult = result
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.READ_SMS),
                        smsRequestCode
                    )
                    return@setMethodCallHandler
                }
                result.success(queryRecentSms(days))
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
                    "ensureNotificationPermission" -> {
                        requestNotificationPermissionIfNeeded(result)
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
        when (requestCode) {
            calendarRequestCode -> {
                if (pendingResult != null) {
                    val result = pendingResult ?: return
                    val range = pendingRange
                    pendingResult = null
                    pendingRange = null
                    if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED && range != null) {
                        result.success(queryCalendarEvents(range.first, range.second))
                    } else {
                        result.error("calendar_denied", "没有日历访问权限", null)
                    }
                    return
                }
                val result = pendingCalendarAuthResult ?: return
                pendingCalendarAuthResult = null
                result.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            }
            smsRequestCode -> {
                if (pendingSmsResult != null) {
                    val result = pendingSmsResult ?: return
                    val days = pendingSmsDays
                    pendingSmsResult = null
                    pendingSmsDays = 7
                    if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                        result.success(queryRecentSms(days))
                    } else {
                        result.error("sms_denied", "没有短信读取权限", null)
                    }
                    return
                }
                val result = pendingSmsAuthResult ?: return
                pendingSmsAuthResult = null
                result.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            }
            notificationRequestCode -> {
                val result = pendingNotificationResult ?: return
                pendingNotificationResult = null
                val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
                result.success(granted)
            }
            voiceRequestCode -> {
                val result = pendingVoiceAuthResult ?: return
                pendingVoiceAuthResult = null
                result.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            }
        }
    }

    private fun openPermissionSettings(target: String, result: MethodChannel.Result) {
        when (target) {
            "calendar" -> requestCalendarPermission(result)
            "sms" -> requestSmsPermission(result)
            "notifications" -> requestNotificationPermissionIfNeeded(result)
            "exact_alarm" -> result.success(openExactAlarmSettings())
            "voice" -> requestVoicePermission(result)
            else -> result.success(openAppSettings())
        }
    }

    private fun requestCalendarPermission(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        pendingCalendarAuthResult = result
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_CALENDAR), calendarRequestCode)
    }

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        pendingSmsAuthResult = result
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_SMS), smsRequestCode)
    }

    private fun requestVoicePermission(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        pendingVoiceAuthResult = result
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), voiceRequestCode)
    }

    private fun openExactAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return try {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                .setData(Uri.parse("package:$packageName"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            openAppSettings()
        }
    }

    private fun openAppSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:$packageName"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun queryLaunchableApps(): List<Map<String, Any?>> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(0)
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(intent, 0)
        }
        return resolved
            .mapNotNull { info ->
                val activity = info.activityInfo ?: return@mapNotNull null
                val packageName = activity.packageName ?: return@mapNotNull null
                val activityName = activity.name ?: return@mapNotNull null
                val label = info.loadLabel(packageManager)?.toString()
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() }
                    ?: packageName
                mapOf(
                    "platform" to "android",
                    "id" to packageName,
                    "label" to label,
                    "subtitle" to packageName,
                    "packageName" to packageName,
                    "activityName" to activityName
                )
            }
            .distinctBy { it["packageName"] as String }
            .sortedBy { (it["label"] as String).lowercase() }
    }

    private fun openInstalledApp(packageName: String, activityName: String?): Boolean {
        return try {
            val intent = if (!activityName.isNullOrBlank()) {
                Intent(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_LAUNCHER)
                    .setComponent(ComponentName(packageName, activityName))
            } else {
                packageManager.getLaunchIntentForPackage(packageName)
            } ?: return false
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
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

    private fun queryRecentSms(days: Int): List<Map<String, Any?>> {
        val sinceMillis = System.currentTimeMillis() - days.coerceAtLeast(1) * 24L * 60L * 60L * 1000L
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE
        )
        val cursor: Cursor? = contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            "${Telephony.Sms.DATE} >= ?",
            arrayOf(sinceMillis.toString()),
            "${Telephony.Sms.DATE} DESC"
        )
        val messages = mutableListOf<Map<String, Any?>>()
        cursor?.use {
            val idIndex = it.getColumnIndexOrThrow(Telephony.Sms._ID)
            val addressIndex = it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val bodyIndex = it.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val dateIndex = it.getColumnIndexOrThrow(Telephony.Sms.DATE)
            while (it.moveToNext() && messages.size < 80) {
                val id = it.getLong(idIndex).toString()
                val body = it.getString(bodyIndex) ?: continue
                messages.add(
                    mapOf(
                        "id" to "android-sms-$id",
                        "address" to (it.getString(addressIndex) ?: ""),
                        "body" to body,
                        "receivedAtMillis" to it.getLong(dateIndex),
                        "platform" to "android"
                    )
                )
            }
        }
        return messages
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

    private fun requestNotificationPermissionIfNeeded(result: MethodChannel.Result? = null) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result?.success(true)
            return
        }
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result?.success(true)
            return
        }
        if (result != null) {
            pendingNotificationResult = result
        }
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationRequestCode
        )
    }
}
