import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/core_providers.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/auth_page.dart';
import 'features/bookkeeping/bookkeeping_page.dart';
import 'features/todo/todo_page.dart';
import 'features/copilot/copilot_page.dart';
import 'features/notes/notes_page.dart';
import 'features/profile/profile_panel.dart';
import 'features/profile/profile_provider.dart';
import 'data/api/api_client.dart';
import 'data/api/profile_service.dart';
import 'features/sync/webdav_provisioner.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      locale: const Locale('zh', 'CN'),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});
  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final savedToken = await ApiClient.loadSavedToken();
    if (savedToken != null && mounted) {
      setState(() => _checking = false);
      ref.read(authProvider.notifier).restoreSession(savedToken);
    } else {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final authState = ref.watch(authProvider);
    if (!authState.isLoggedIn) {
      return const AuthPage();
    }
    return const HomePage();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _profileOpen = false;
  bool _profileFetched = false;

  List<Widget> _pages() => [
    TodoPage(onAvatarTap: _openProfile),
    BookkeepingPage(onAvatarTap: _openProfile),
    NotesPage(onAvatarTap: _openProfile),
    CopilotPage(onAvatarTap: _openProfile),
  ];

  void _openProfile() {
    setState(() => _profileOpen = true);
  }

  void _closeProfile() {
    setState(() => _profileOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Consumer(
          builder: (context, ref, child) {
            ref.watch(dataSyncServiceProvider);
            if (!_profileFetched) {
              _profileFetched = true;
              Future.microtask(() async {
                try {
                  final profileResp = await ProfileService.getProfile();
                  if (profileResp != null) {
                    ref.read(profileProvider.notifier).updateFromServer({
                      'nickname': profileResp.nickname,
                      'username': profileResp.username,
                      'email': profileResp.email,
                      'phone': profileResp.phone,
                      'avatar': profileResp.avatar,
                    });
                  }
                  final provisioner = WebDavProvisioner();
                  await provisioner.syncFromServer();
                } catch (_) {}
              });
            }
            return const SizedBox.shrink();
          },
        ),
        Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(_currentIndex),
              child: IndexedStack(index: _currentIndex, children: _pages()),
            ),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 5,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 54,
                child: Row(
                  children: [
                    _BottomNavItem(
                      icon: Icons.check_circle_outline,
                      label: '待办',
                      selected: _currentIndex == 0,
                      onTap: () => setState(() => _currentIndex = 0),
                    ),
                    _BottomNavItem(
                      icon: Icons.account_balance_wallet_outlined,
                      label: '记账',
                      selected: _currentIndex == 1,
                      onTap: () => setState(() => _currentIndex = 1),
                    ),
                    _BottomNavItem(
                      icon: Icons.edit_note,
                      label: '随手记',
                      selected: _currentIndex == 2,
                      onTap: () => setState(() => _currentIndex = 2),
                    ),
                    _BottomNavItem(
                      icon: Icons.auto_awesome,
                      label: 'Copilot',
                      selected: _currentIndex == 3,
                      onTap: () => setState(() => _currentIndex = 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_profileOpen) ProfilePanel(onClose: _closeProfile),
      ],
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textTertiary;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: AppColors.primary.withValues(alpha: 0.04),
            highlightColor: AppColors.primary.withValues(alpha: 0.025),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.055)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.10)
                      : Colors.transparent,
                  width: 0.6,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(height: 3),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PingFang SC',
                        fontFamilyFallback: const [
                          '.SF Pro Text',
                          'system-ui',
                          'sans-serif',
                        ],
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: color,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
