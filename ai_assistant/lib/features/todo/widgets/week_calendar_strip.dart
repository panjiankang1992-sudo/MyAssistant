import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class WeekCalendarStrip extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final String? Function(DateTime date)? badgeBuilder;
  final Color? Function(DateTime date)? badgeColorBuilder;

  const WeekCalendarStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.badgeBuilder,
    this.badgeColorBuilder,
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
        _queueScrollToDate(widget.selectedDate, width / 7, animate: true);
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

  void _queueScrollToDate(
    DateTime date,
    double itemWidth, {
    required bool animate,
    int attempt = 0,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
        if (attempt < 8) {
          _queueScrollToDate(
            date,
            itemWidth,
            animate: animate,
            attempt: attempt + 1,
          );
        }
        return;
      }
      _scrollToDate(date, itemWidth, animate: animate);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / 7;
        if (!_didInitialPosition) {
          _didInitialPosition = true;
          _queueScrollToDate(widget.selectedDate, itemWidth, animate: false);
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
              itemExtent: itemWidth,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: _rangeBefore + _rangeAfter + 1,
              itemBuilder: (context, index) {
                final day = _dateForIndex(index);
                final isToday = _isSameDay(day, today);
                final isSelected = _isSameDay(day, widget.selectedDate);
                final badge = widget.badgeBuilder?.call(day);
                final badgeColor =
                    widget.badgeColorBuilder?.call(day) ?? scheme.primary;

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
                                ? scheme.primary
                                : scheme.appSubtleText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 38,
                          height: 34,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Align(
                                alignment: Alignment.center,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? (isToday
                                              ? scheme.primary
                                              : scheme.primary.withValues(
                                                  alpha: 0.14,
                                                ))
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
                                                  ? scheme.onPrimary
                                                  : scheme.primary)
                                            : (isToday
                                                  ? scheme.primary
                                                  : scheme.appText),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (badge != null && badge.trim().isNotEmpty)
                                Positioned(
                                  right: -2,
                                  bottom: -1,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: scheme.appSurface.withValues(
                                        alpha: 0.92,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Text(
                                        badge,
                                        maxLines: 1,
                                        overflow: TextOverflow.visible,
                                        style: TextStyle(
                                          fontSize: 8,
                                          height: 1.0,
                                          fontWeight: FontWeight.w800,
                                          color: isSelected && isToday
                                              ? scheme.primary
                                              : badgeColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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
