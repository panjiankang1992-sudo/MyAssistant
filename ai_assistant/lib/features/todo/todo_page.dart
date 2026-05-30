import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/todo_provider.dart';
import 'providers/selected_date_provider.dart';
import 'widgets/add_todo_modal.dart';
import 'widgets/todo_detail_modal.dart';
import 'widgets/todo_list.dart';
import 'widgets/week_calendar_strip.dart';
import '../../core/platform/app_performance.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/todo.dart';
import '../../shared/widgets/app_controls.dart';
import '../../shared/widgets/profile_avatar_button.dart';

class TodoPage extends ConsumerStatefulWidget {
  final VoidCallback? onAvatarTap;

  const TodoPage({super.key, this.onAvatarTap});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _poetryLines = [
    '山重水复疑无路，柳暗花明又一村。',
    '长风破浪会有时，直挂云帆济沧海。',
    '莫愁前路无知己，天下谁人不识君。',
    '会当凌绝顶，一览众山小。',
    '纸上得来终觉浅，绝知此事要躬行。',
    '不畏浮云遮望望眼，自缘身在最高层。',
  ];
  int _poetryIndex = 0;
  Timer? _poetryTimer;
  Timer? _bookkeepingFeedbackTimer;
  bool _poetryVisible = true;
  bool _showBookkeepingFeedback = false;
  bool _bookkeepingFeedbackSuccess = false;
  int _bookkeepingFeedbackTick = 0;
  bool _calendarSyncing = false;
  Map<DateTime, int> _todoDateCounts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted) {
        ref.read(todoNotifierProvider.notifier).loadSelectedDateTodos();
        _loadTodoDateCounts();
      }
    });
    if (!AppPerformance.lowLatencyMode) {
      _poetryTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        setState(() => _poetryVisible = false);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _poetryIndex = (_poetryIndex + 1) % _poetryLines.length;
              _poetryVisible = true;
            });
          }
        });
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poetryTimer?.cancel();
    _bookkeepingFeedbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncCalendarTodos() async {
    if (_calendarSyncing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _calendarSyncing = true);
    try {
      final result = await ref
          .read(todoNotifierProvider.notifier)
          .importCalendarTodos(force: true);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.unsupported
                  ? '当前平台暂不支持直接读取系统日历'
                  : result.created == 0
                  ? '日历同步完成，暂无新代办'
                  : '已从日历生成 ${result.created} 条代办',
            ),
            duration: const Duration(milliseconds: 1400),
          ),
        );
      await _loadTodoDateCounts();
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('无法读取系统日历，请检查日历权限')));
    } finally {
      if (mounted) setState(() => _calendarSyncing = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(todoNotifierProvider.notifier).loadSelectedDateTodos();
      _loadTodoDateCounts();
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _titleForDate(DateTime date) {
    if (_isToday(date)) return '今日待办';
    return '${date.month}月${date.day}日 待办';
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Map<DateTime, int> _todoCountsByDate(List<Todo> todos) {
    final counts = <DateTime, int>{};
    for (final todo in todos) {
      if (todo.deleted) continue;
      final day = _dateOnly(todo.date);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _loadTodoDateCounts() async {
    final allTodos = await ref.read(datasourceProvider).getAllTodos();
    if (!mounted) return;
    setState(() => _todoDateCounts = _todoCountsByDate(allTodos));
  }

  void _displayBookkeepingFeedback({required bool success}) {
    _bookkeepingFeedbackTimer?.cancel();
    setState(() {
      _bookkeepingFeedbackTick++;
      _bookkeepingFeedbackSuccess = success;
      _showBookkeepingFeedback = true;
    });
  }

  void _hideBookkeepingFeedback() {
    _bookkeepingFeedbackTimer?.cancel();
    _bookkeepingFeedbackTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() => _showBookkeepingFeedback = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<Todo>>(todoNotifierProvider, (previous, next) {
      if (previous == next) return;
      Future.microtask(_loadTodoDateCounts);
    });
    final selectedDate = ref.watch(selectedDateProvider);
    final todos = ref.watch(todoNotifierProvider);
    final isToday = _isToday(selectedDate);
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = AppPerformance.shouldReduceMotion(context);

    return Scaffold(
      backgroundColor: scheme.appPage,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _TodoPageTitle(
                                  title: _titleForDate(selectedDate),
                                  selectedDate: selectedDate,
                                  reduceMotion: reduceMotion,
                                  color: scheme.appText,
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () async {
                                    final allTodos = await ref
                                        .read(datasourceProvider)
                                        .getAllTodos();
                                    if (!context.mounted) return;
                                    final counts = _todoCountsByDate(allTodos);
                                    final picked = await showAppDatePicker(
                                      context: context,
                                      initialDate: selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                      markerBuilder: (date) {
                                        final count = counts[_dateOnly(date)];
                                        if (count == null || count <= 0) {
                                          return null;
                                        }
                                        return AppDateMarker(
                                          label: '$count',
                                          color: AppColors.primary,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      ref
                                              .read(
                                                selectedDateProvider.notifier,
                                              )
                                              .date =
                                          picked;
                                    }
                                  },
                                  child: Icon(
                                    Icons.calendar_month_outlined,
                                    size: 24,
                                    color: scheme.appMutedText,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                IconButton(
                                  tooltip: '同步系统日历',
                                  onPressed: _calendarSyncing
                                      ? null
                                      : _syncCalendarTodos,
                                  icon: _calendarSyncing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          Icons.event_available_rounded,
                                          size: 22,
                                          color: scheme.appMutedText,
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            _PoetryLine(
                              text: _poetryLines[_poetryIndex],
                              visible: _poetryVisible,
                              reduceMotion: reduceMotion,
                              color: scheme.appMutedText,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ProfileAvatarButton(onTap: widget.onAvatarTap),
                    ],
                  ),
                ),
                WeekCalendarStrip(
                  selectedDate: selectedDate,
                  badgeBuilder: (date) {
                    final count = _todoDateCounts[_dateOnly(date)] ?? 0;
                    return count > 0 ? '$count' : null;
                  },
                  badgeColorBuilder: (_) => AppColors.primary,
                  onDateSelected: (date) {
                    ref.read(selectedDateProvider.notifier).date = date;
                  },
                ),
                Expanded(
                  child: TodoList(
                    todos: todos,
                    readOnly: !isToday,
                    onToggle: (todo) {
                      ref
                          .read(todoNotifierProvider.notifier)
                          .toggleComplete(todo.id);
                    },
                    onDelete: (todo) {
                      ref
                          .read(todoNotifierProvider.notifier)
                          .deleteTodo(todo.id);
                    },
                    onTap: (todo) {
                      showTodoDetail(context, todo, readOnly: !isToday);
                    },
                    onActionTap: (todo) async {
                      final messenger = ScaffoldMessenger.of(context);
                      if (todo.source == 'calendar') {
                        final opened = await ref
                            .read(todoNotifierProvider.notifier)
                            .executeTodoAction(todo);
                        if (!mounted) return;
                        if (!opened) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('未能打开系统日历')),
                          );
                        }
                        return;
                      }
                      if (todo.action == 'bookkeeping') {
                        _displayBookkeepingFeedback(success: false);
                      }
                      final actionHandled = await ref
                          .read(todoNotifierProvider.notifier)
                          .executeTodoAction(todo);
                      if (!mounted) return;
                      if (todo.action == 'bookkeeping') {
                        if (actionHandled) {
                          _displayBookkeepingFeedback(success: true);
                          _hideBookkeepingFeedback();
                        } else {
                          setState(() => _showBookkeepingFeedback = false);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('未识别到金额，未记账')),
                          );
                        }
                        return;
                      }
                      if (todo.action.startsWith('open_app')) {
                        if (!actionHandled) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('未能打开目标应用')),
                          );
                        }
                        return;
                      }
                      if (actionHandled) {
                        _displayBookkeepingFeedback(success: true);
                        _hideBookkeepingFeedback();
                      }
                    },
                    onComplete: (todo) {
                      ref
                          .read(todoNotifierProvider.notifier)
                          .toggleComplete(todo.id);
                    },
                    onDefer: (todo) {
                      ref.read(todoNotifierProvider.notifier).updateTodo(todo);
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_showBookkeepingFeedback)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: _BookkeepingFeedbackAnimation(
                    key: ValueKey(
                      '$_bookkeepingFeedbackTick-$_bookkeepingFeedbackSuccess',
                    ),
                    success: _bookkeepingFeedbackSuccess,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: AppAddFab(
        tooltip: '新增代办',
        onPressed: () => showAddTodoModal(context, initialDate: selectedDate),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _TodoPageTitle extends StatelessWidget {
  final String title;
  final DateTime selectedDate;
  final bool reduceMotion;
  final Color color;

  const _TodoPageTitle({
    required this.title,
    required this.selectedDate,
    required this.reduceMotion,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      title,
      key: ValueKey(selectedDate),
      style: TextStyle(
        fontFamily: 'PingFang SC',
        fontFamilyFallback: const ['.SF Pro Text', 'system-ui', 'sans-serif'],
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: color,
      ),
    );
    if (reduceMotion) return text;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: text,
    );
  }
}

class _PoetryLine extends StatelessWidget {
  final String text;
  final bool visible;
  final bool reduceMotion;
  final Color color;

  const _PoetryLine({
    required this.text,
    required this.visible,
    required this.reduceMotion,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final child = Text(
      text,
      style: TextStyle(
        fontFamily: 'PingFang SC',
        fontFamilyFallback: const ['.SF Pro Text', 'system-ui', 'sans-serif'],
        fontSize: 12,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: color,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (reduceMotion) return child;
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: child,
    );
  }
}

class _BookkeepingFeedbackAnimation extends StatefulWidget {
  final bool success;

  const _BookkeepingFeedbackAnimation({super.key, required this.success});

  @override
  State<_BookkeepingFeedbackAnimation> createState() =>
      _BookkeepingFeedbackAnimationState();
}

class _BookkeepingFeedbackAnimationState
    extends State<_BookkeepingFeedbackAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.success ? 560 : 760),
    );
    if (widget.success) {
      _controller.forward();
    } else {
      _controller.repeat();
    }
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.82,
          end: 1.06,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 38,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.06,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 62,
      ),
    ]).animate(_controller);
    _opacity = widget.success
        ? TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 18),
            TweenSequenceItem(tween: ConstantTween(1.0), weight: 52),
            TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
          ]).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          )
        : const AlwaysStoppedAnimation(1.0);
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final penX = -34 + 68 * _progress.value;
        final penY = 3 - 8 * Curves.easeInOut.transform(_progress.value);
        final title = widget.success ? '已记录' : '正在记账...';
        final subtitle = widget.success ? '账单已保存' : '正在写入账单';
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Semantics(
              liveRegion: true,
              label: title,
              child: Container(
                width: 188,
                height: 138,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                decoration: BoxDecoration(
                  color: scheme.appElevatedSurface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.appBorder.withValues(alpha: 0.75),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 58,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: 22,
                            right: 22,
                            top: 28,
                            child: CustomPaint(
                              size: const Size(double.infinity, 22),
                              painter: _BookkeepingLinePainter(
                                progress: _progress.value,
                                baseColor: scheme.appBorder,
                                inkColor: scheme.primary,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 3 + penY,
                            left: 76 + penX,
                            child: Transform.rotate(
                              angle: -0.45,
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFB340),
                                      Color(0xFFFF7A59),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFF9500,
                                      ).withValues(alpha: 0.25),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'PingFang SC',
                        fontFamilyFallback: [
                          '.SF Pro Text',
                          'system-ui',
                          'sans-serif',
                        ],
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ).copyWith(color: scheme.appText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'PingFang SC',
                        fontFamilyFallback: [
                          '.SF Pro Text',
                          'system-ui',
                          'sans-serif',
                        ],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ).copyWith(color: scheme.appMutedText),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BookkeepingLinePainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  final Color inkColor;

  const _BookkeepingLinePainter({
    required this.progress,
    required this.baseColor,
    required this.inkColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = baseColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final inkPaint = Paint()
      ..color = inkColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, size.height * 0.45)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.1,
        size.width * 0.35,
        size.height * 0.78,
        size.width * 0.52,
        size.height * 0.46,
      )
      ..cubicTo(
        size.width * 0.68,
        size.height * 0.17,
        size.width * 0.76,
        size.height * 0.75,
        size.width,
        size.height * 0.42,
      );
    canvas.drawPath(path, basePaint);

    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0)),
        inkPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BookkeepingLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
