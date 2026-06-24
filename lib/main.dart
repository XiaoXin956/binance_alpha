import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/history_page.dart';

void main() {
  runApp(const BinanceAlphaApp());
}

class BinanceAlphaApp extends StatelessWidget {
  const BinanceAlphaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '币安阿尔法',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // colorScheme: ColorScheme.fromSeed(
        //   seedColor: const Color(0xFFF0B90B), // Binance 黄
        //   brightness: Brightness.light,
        // ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    HistoryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? '币安阿尔法' : '历史记录'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '历史',
          ),
        ],
      ),
    );
  }
}
