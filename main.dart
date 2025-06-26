import 'package:flutter/material.dart';
import 'pages/record_page.dart';
import 'pages/library_page.dart';
import 'pages/settings_page.dart';

// a single global notifier:
// you can move this into its own file if you prefer
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() => runApp(SheetMusicApp());

class SheetMusicApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentMode, __) {
        return MaterialApp(
          title: 'Recorder & Transcriber',
          themeMode: currentMode,
          // light theme:
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.white,
            fontFamily: 'Montserrat',
            textTheme: const TextTheme(
              titleLarge: TextStyle(fontWeight: FontWeight.w600),
              titleMedium: TextStyle(fontWeight: FontWeight.w500),
              bodyMedium: TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
          // dark theme:
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.black,
            fontFamily: 'Montserrat',
            textTheme: const TextTheme(
              titleLarge: TextStyle(fontWeight: FontWeight.w600),
              titleMedium: TextStyle(fontWeight: FontWeight.w500),
              bodyMedium: TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
          home: HomeScaffold(),
        );
      },
    );
  }
}

class HomeScaffold extends StatefulWidget {
  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  int _currentIndex = 0;
  final _pages = [RecordPage(), LibraryPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'Converter',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
