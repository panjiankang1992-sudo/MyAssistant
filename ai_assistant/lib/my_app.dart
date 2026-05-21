import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/auth_page.dart';
import 'features/todo/todo_page.dart';
import 'features/copilot/copilot_page.dart';
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
    const _PlaceholderPage(icon: Icons.account_balance_wallet_outlined, label: '记账'),
    const _PlaceholderPage(icon: Icons.edit_note, label: '随手记'),
    const CopilotPage(),
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
              child: IndexedStack(
                index: _currentIndex,
                children: _pages(),
              ),
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              backgroundColor: Colors.transparent,
              elevation: 0,
              height: 56,
              indicatorColor: Colors.transparent,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.check_circle_outline), label: '待办'),
                NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: '记账'),
                NavigationDestination(icon: Icon(Icons.edit_note), label: '随手记'),
                NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'Copilot'),
              ],
            ),
          ),
        ),
        if (_profileOpen)
          ProfilePanel(
            onClose: _closeProfile,
          ),
      ],
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PlaceholderPage({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.textTertiary.withOpacity(0.6)),
          const SizedBox(height: 8),
          Text(
            '$label 功能开发中',
            style: const TextStyle(
              fontFamily: 'PingFang SC',
              fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}