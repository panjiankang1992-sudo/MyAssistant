import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final _pages = const [
    _TabContent(color: Color(0xFFFFE0E0), label: '待办 - 粉色'),
    _TabContent(color: Color(0xFFE0FFE0), label: '记账 - 绿色'),
    _TabContent(color: Color(0xFFE0E0FF), label: '随手记 - 蓝色'),
    _TabContent(color: Color(0xFFFFE0FF), label: 'Copilot - 紫色'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: '待办'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: '记账'),
          NavigationDestination(icon: Icon(Icons.edit_note), label: '随手记'),
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'Copilot'),
        ],
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  final Color color;
  final String label;
  const _TabContent({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Center(child: Text(label, style: const TextStyle(fontSize: 22))),
    );
  }
}
