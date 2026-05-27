import 'package:flutter/gestures.dart';
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
  final _scrollController = ScrollController();
  final _rangeBefore = 3650;
  final _rangeAfter = 3650;
  late DateTime _anchorDate;
  bool _didInitialPosition = false;
  DateTime? _lastTappedDate;

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _anchorDate = _dateOnly(DateTime.now());
  }

  @override
  void didUpdateWidget(covariant WeekCalendarStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDay(widget.selectedDate, oldWidget.selectedDate)) {
      if (_lastTappedDate != null &&
          _isSameDay(widget.selectedDate, _lastTappedDate!)) {
        _lastTappedDate = null;
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final width = context.size?.width;
        if (width == null || width <= 0) return;
        _scrollToDate(widget.selectedDate, width / 7, animate: true);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _dateForIndex(int index) {
    return _anchorDate.add(Duration(days: index - _rangeBefore));
  }

  int _indexForDate(DateTime date) {
    return _dateOnly(date).difference(_anchorDate).inDays + _rangeBefore;
  }

  void _scrollToDate(DateTime date, double itemWidth, {required bool animate}) {
    final target = ((_indexForDate(date) - 3) * itemWidth).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / 7;
        if (!_didInitialPosition) {
          _didInitialPosition = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scrollController.hasClients) return;
            _scrollToDate(widget.selectedDate, itemWidth, animate: false);
          });
        }

        return ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: SizedBox(
            height: 64,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: _rangeBefore + _rangeAfter + 1,
              itemBuilder: (context, index) {
                final day = _dateForIndex(index);
                final isToday = _isSameDay(day, today);
                final isSelected = _isSameDay(day, widget.selectedDate);

                return SizedBox(
                  width: itemWidth,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _lastTappedDate = day;
                      widget.onDateSelected(day);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _weekdays[day.weekday - 1],
                          style: TextStyle(
                            fontFamily: 'PingFang SC',
                            fontFamilyFallback: const [
                              '.SF Pro Text',
                              'system-ui',
                              'sans-serif',
                            ],
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
                                ? (isToday
                                      ? AppColors.primary
                                      : AppColors.primaryLight)
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontFamily: 'PingFang SC',
                                fontFamilyFallback: const [
                                  '.SF Pro Text',
                                  'system-ui',
                                  'sans-serif',
                                ],
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? (isToday
                                          ? Colors.white
                                          : AppColors.primary)
                                    : (isToday
                                          ? AppColors.primary
                                          : AppColors.text),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
