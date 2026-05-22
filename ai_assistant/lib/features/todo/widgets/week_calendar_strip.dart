import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class WeekCalendarStrip extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const WeekCalendarStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<WeekCalendarStrip> createState() => _WeekCalendarStripState();
}

class _WeekCalendarStripState extends State<WeekCalendarStrip> {
  late PageController _pageController;
  late DateTime _initialWeekStart;

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  static const _initialPage = 520; // middle of 1040 pages (~20 year range)

  @override
  void initState() {
    super.initState();
    _initialWeekStart = _mondayOfWeek(widget.selectedDate);
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(covariant WeekCalendarStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDay(widget.selectedDate, oldWidget.selectedDate)) {
      final targetPage = _pageForDate(widget.selectedDate);
      if (_pageController.hasClients && (_pageController.page?.round() ?? _initialPage) != targetPage) {
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _mondayOfWeek(DateTime date) {
    final d = date.weekday;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: d - 1));
  }

  int _pageForDate(DateTime date) {
    final monday = _mondayOfWeek(date);
    final diff = monday.difference(_initialWeekStart).inDays;
    return _initialPage + diff ~/ 7;
  }

  DateTime _weekStartForPage(int page) {
    return _initialWeekStart.add(Duration(days: (page - _initialPage) * 7));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return SizedBox(
      height: 64,
      child: PageView.builder(
        controller: _pageController,
        itemCount: 1040,
        itemBuilder: (context, page) {
          final weekStart = _weekStartForPage(page);
          return Row(
            children: List.generate(7, (i) {
              final day = weekStart.add(Duration(days: i));
              final isToday = _isSameDay(day, today);
              final isSelected = _isSameDay(day, widget.selectedDate);

              return Expanded(
                child: GestureDetector(
                  onTap: () => widget.onDateSelected(day),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _weekdays[i],
                        style: TextStyle(
                          fontFamily: 'PingFang SC',
                          fontFamilyFallback: const ['.SF Pro Text', 'system-ui', 'sans-serif'],
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? (isToday ? AppColors.primary : AppColors.primaryLight)
                              : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontFamily: 'PingFang SC',
                              fontFamilyFallback: const ['.SF Pro Text', 'system-ui', 'sans-serif'],
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected
                                  ? (isToday ? Colors.white : AppColors.primary)
                                  : (isToday ? AppColors.primary : AppColors.text),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
