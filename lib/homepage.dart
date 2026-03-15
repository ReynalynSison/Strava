import 'package:flutter/cupertino.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/record_screen.dart';
import 'screens/you_screen.dart';
import 'settings.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  // Shared controller — passed down so any screen can switch tabs
  final CupertinoTabController _tabController = CupertinoTabController();

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.list_bullet),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.play_circle_fill),
            label: 'Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_crop_circle_fill),
            label: 'You',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return HomeScreen(onGoToRecord: () => _tabController.index = 2);
          case 1:
            return HistoryScreen(onGoToRecord: () => _tabController.index = 2);
          case 2:
            return const RecordScreen();
          case 3:
            return const YouScreen();
          case 4:
            return const Settings();
          default:
            return HomeScreen(onGoToRecord: () => _tabController.index = 2);
        }
      },
    );
  }
}
