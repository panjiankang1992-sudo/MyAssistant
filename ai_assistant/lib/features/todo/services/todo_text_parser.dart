class ParsedResult {
  final String title;
  final String type;
  final String time;
  final DateTime date;
  final String source;
  final String? description;

  ParsedResult({
    required this.title,
    required this.type,
    required this.time,
    required this.date,
    this.source = 'recommend',
    this.description,
  });
}

class TodoTextParser {
  static ParsedResult parse(String input) {
    final now = DateTime.now();
    var title = input;
    var date = DateTime(now.year, now.month, now.day);
    var time = '09:00';
    var type = 'personal';
    String? description;

    final datePatterns = [
      (_RegExps.tomorrow, () => now.add(const Duration(days: 1))),
      (_RegExps.dayAfterTomorrow, () => now.add(const Duration(days: 2))),
      (_RegExps.nextWeekDay, (Match m) {
        final weekday = _weekdayFromChinese(m.group(1)!);
        return _nextWeekday(now, weekday);
      }),
      (_RegExps.thisWeekDay, (Match m) {
        final weekday = _weekdayFromChinese(m.group(1)!);
        return _thisOrNextWeekday(now, weekday);
      }),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.$1.firstMatch(title);
      if (match != null) {
        if (pattern.$2 is DateTime Function()) {
          date = (pattern.$2 as DateTime Function())();
        } else {
          date = (pattern.$2 as DateTime Function(Match))(match);
        }
        title = title.replaceFirst(pattern.$1, '');
        break;
      }
    }

    final explicitTimeMatch = _RegExps.explicitTime.firstMatch(input);
    if (explicitTimeMatch != null) {
      final hourStr = explicitTimeMatch.group(1)!;
      final minuteStr = explicitTimeMatch.group(2);
      var hour = int.parse(hourStr);
      final minute = minuteStr != null && minuteStr.isNotEmpty
          ? int.parse(minuteStr)
          : 0;

      if (hour < 12 &&
          (_RegExps.afternoon.hasMatch(input) ||
              _RegExps.evening.hasMatch(input))) {
        hour += 12;
      }

      time =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      title = title.replaceFirst(_RegExps.explicitTime, '');
    } else {
      final timeOfDayPatterns = [
        (_RegExps.morning, '08:00'),
        (_RegExps.forenoon, '10:00'),
        (_RegExps.noon, '12:00'),
        (_RegExps.afternoon, '15:00'),
        (_RegExps.evening, '19:00'),
      ];

      for (final pattern in timeOfDayPatterns) {
        if (pattern.$1.hasMatch(input)) {
          time = pattern.$2;
          title = title.replaceFirst(pattern.$1, '');
          break;
        }
      }
    }

    final typePatterns = [
      (_RegExps.work, 'work'),
      (_RegExps.bill, 'bill'),
      (_RegExps.health, 'health'),
    ];

    for (final pattern in typePatterns) {
      if (pattern.$1.hasMatch(input)) {
        type = pattern.$2;
        break;
      }
    }

    if (_RegExps.meeting.hasMatch(input)) {
      description = '请提前准备相关材料';
    } else if (_RegExps.payment.hasMatch(input)) {
      description = '请保留支付凭证';
    } else if (_RegExps.exercise.hasMatch(input)) {
      description = '记得带运动装备';
    }

    for (final pattern in [
      _RegExps.tomorrow,
      _RegExps.dayAfterTomorrow,
      _RegExps.nextWeekDay,
      _RegExps.thisWeekDay,
      _RegExps.morning,
      _RegExps.forenoon,
      _RegExps.noon,
      _RegExps.afternoon,
      _RegExps.evening,
      _RegExps.explicitTime,
      _RegExps.imperative,
    ]) {
      title = title.replaceAll(pattern, '');
    }

    title = title.replaceAll(RegExp(r'\s+'), '').trim();

    return ParsedResult(
      title: title.isEmpty ? input : title,
      type: type,
      time: time,
      date: date,
      description: description,
    );
  }

  static int _weekdayFromChinese(String chinese) {
    const map = {
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '日': 7,
      '天': 7,
    };
    return map[chinese] ?? 1;
  }

  static DateTime _nextWeekday(DateTime now, int weekday) {
    final currentWeekday = now.weekday;
    var daysToAdd = weekday - currentWeekday;
    if (daysToAdd <= 0) daysToAdd += 7;
    return now.add(Duration(days: daysToAdd));
  }

  static DateTime _thisOrNextWeekday(DateTime now, int weekday) {
    final currentWeekday = now.weekday;
    var daysToAdd = weekday - currentWeekday;
    if (daysToAdd < 0) daysToAdd += 7;
    return now.add(Duration(days: daysToAdd));
  }
}

class _RegExps {
  static final tomorrow = RegExp(r'明天');
  static final dayAfterTomorrow = RegExp(r'后天');
  static final nextWeekDay = RegExp(r'下周([一二三四五六日天])');
  static final thisWeekDay = RegExp(r'周([一二三四五六日天])');
  static final explicitTime = RegExp(r'(\d{1,2})[点:：](\d{0,2})');
  static final morning = RegExp(r'早上');
  static final forenoon = RegExp(r'上午');
  static final noon = RegExp(r'中午');
  static final afternoon = RegExp(r'下午');
  static final evening = RegExp(r'晚上');
  static final work = RegExp(r'会议|开会|汇报|周报|项目|客户|产品|方案|评审|排期');
  static final bill = RegExp(r'帐单|缴费|物业|房租|还钱|付款|报销|水电');
  static final health = RegExp(r'健身|跑步|游泳|体检|医院|药');
  static final meeting = RegExp(r'会议|开会');
  static final payment = RegExp(r'缴费|付款|报销');
  static final exercise = RegExp(r'健身|跑步|游泳');
  static final imperative = RegExp(r'去|要|记得|别忘了|帮我');
}
