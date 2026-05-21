import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import 'providers/todo_provider.dart';
import 'services/seed_data.dart';
import 'widgets/add_todo_modal.dart';
import 'widgets/todo_detail_modal.dart';
import 'widgets/todo_list.dart';
import '../../core/theme/app_theme.dart';
import '../profile/profile_provider.dart';

class TodoPage extends ConsumerStatefulWidget {
  final VoidCallback? onAvatarTap;

  const TodoPage({super.key, this.onAvatarTap});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> with TickerProviderStateMixin {
  final _poetryLines = [
    '山重水复疑无路，柳暗花明又一村。',
    '长风破浪会有时，直挂云帆济沧海。',
    '莫愁前路无知己，天下谁人不识君。',
    '会当凌绝顶，一览众山小。',
    '纸上得来终觉浅，绝知此事要躬行。',
    '不畏浮云遮望望眼，自缘身在最高层。',
  ];
  static const _avatarColors = [
    [Color(0xFF667EEA), Color(0xFF764BA2)],
    [Color(0xFF0071E3), Color(0xFF00C6FF)],
    [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    [Color(0xFF34C759), Color(0xFF30D5C8)],
    [Color(0xFFFF9500), Color(0xFFFF5E3A)],
    [Color(0xFFAF52DE), Color(0xFF5856D6)],
  ];
  int _poetryIndex = 0;
  Timer? _poetryTimer;
  bool _poetryVisible = true;

  // FAB 拖动状态
  Offset _fabOffset = Offset.zero; // 相对于默认右下角的偏移

  @override
  void initState() {
    super.initState();
    _poetryTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) {
        setState(() => _poetryVisible = false);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _poetryIndex = (_poetryIndex + 1) % _poetryLines.length;
              _poetryVisible = true;
            });
          }
        });
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = ref.read(todoRepoProvider);
      await SeedData.seedIfEmpty(repo);
      ref.read(todoNotifierProvider.notifier).loadTodayTodos();
    });
  }

  @override
  void dispose() {
    _poetryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todoNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
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
                        const Text(
                          '今日待办',
                          style: TextStyle(
                            fontFamily: 'PingFang SC',
                            fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedOpacity(
                          opacity: _poetryVisible ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _poetryLines[_poetryIndex],
                            style: const TextStyle(
                              fontFamily: 'PingFang SC',
                              fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _AvatarButton(
                    onTap: widget.onAvatarTap,
                    letter: ref.watch(profileProvider).name.isNotEmpty
                        ? ref.watch(profileProvider).name[0]
                        : '?',
                    gradientColors: _avatarColors[ref.watch(profileProvider).avatarColorIndex.clamp(0, _avatarColors.length - 1)],
                    serverAvatarUrl: ref.watch(profileProvider).serverAvatarUrl,
                    localAvatarPath: ref.watch(profileProvider).avatarPath,
                  ),
                ],
              ),
            ),
            Expanded(
              child: TodoList(
                todos: todos,
                onToggle: (todo) {
                  ref.read(todoNotifierProvider.notifier).toggleComplete(todo.id);
                },
                onDelete: (todo) {
                  ref.read(todoNotifierProvider.notifier).deleteTodo(todo.id);
                },
                onTap: (todo) {
                  showTodoDetail(context, todo);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _DraggableFAB(
        offset: _fabOffset,
        onOffsetChanged: (o) => setState(() => _fabOffset = o),
        onPressed: () => showAddTodoModal(context),
      ),
    );
  }
}

/// 支持长按拖动的 FAB，默认右下角
class _DraggableFAB extends StatefulWidget {
  final Offset offset;
  final ValueChanged<Offset> onOffsetChanged;
  final VoidCallback onPressed;

  const _DraggableFAB({
    required this.offset,
    required this.onOffsetChanged,
    required this.onPressed,
  });

  @override
  State<_DraggableFAB> createState() => _DraggableFABState();
}

class _DraggableFABState extends State<_DraggableFAB> {
  Offset _offset = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _offset = widget.offset;
  }

  @override
  void didUpdateWidget(covariant _DraggableFAB oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.offset != oldWidget.offset) {
      _offset = widget.offset;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _offset,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          setState(() => _offset += details.delta);
          widget.onOffsetChanged(_offset);
        },
        onPanEnd: (_) {
          // 短暂延迟后重置拖动状态，避免 tap 误触
          Future.microtask(() => setState(() => _isDragging = false));
        },
        onTap: _isDragging ? null : widget.onPressed,
        child: FloatingActionButton(
          onPressed: widget.onPressed,
          backgroundColor: AppColors.primary,
          elevation: 4,
          highlightElevation: 6,
          child: const Icon(Icons.add, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}

class _AvatarButton extends StatefulWidget {
  final VoidCallback? onTap;
  final String letter;
  final List<Color> gradientColors;
  final String? serverAvatarUrl;
  final String? localAvatarPath;

  _AvatarButton({this.onTap, this.letter = '?', this.gradientColors = const [Color(0xFF667EEA), Color(0xFF764BA2)], this.serverAvatarUrl, this.localAvatarPath});

  @override
  State<_AvatarButton> createState() => _AvatarButtonState();
}

class _AvatarButtonState extends State<_AvatarButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Widget avatarChild;
    if (widget.serverAvatarUrl != null && widget.serverAvatarUrl!.isNotEmpty) {
      final url = widget.serverAvatarUrl!;
      // 后端返回 data:image/...;base64,... 格式的数据URI
      if (url.startsWith('data:')) {
        final base64Str = url.split(',').last;
        try {
          final bytes = base64Decode(base64Str);
          avatarChild = ClipOval(
            child: Image.memory(bytes, width: 40, height: 40, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildGradientAvatar()),
          );
        } catch (_) {
          avatarChild = _buildGradientAvatar();
        }
      } else {
        avatarChild = ClipOval(
          child: Image.network(url, width: 40, height: 40, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildGradientAvatar()),
        );
      }
    } else if (widget.localAvatarPath != null && widget.localAvatarPath!.isNotEmpty) {
      avatarChild = ClipOval(
        child: Image.file(
          File(widget.localAvatarPath!),
          width: 40, height: 40, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildGradientAvatar(),
        ),
      );
    } else {
      avatarChild = _buildGradientAvatar();
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: avatarChild,
      ),
    );
  }

  Widget _buildGradientAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: widget.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33764BA2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          widget.letter,
          style: TextStyle(
            fontFamily: 'PingFang SC',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}