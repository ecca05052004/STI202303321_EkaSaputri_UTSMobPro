import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/home_page.dart';
import 'pages/gallery_page.dart';
import 'pages/settings_page.dart';
import 'pages/add_note_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  runApp(PersonalJournalApp(isDarkMode: isDarkMode));
}

class PersonalJournalApp extends StatefulWidget {
  final bool isDarkMode;
  const PersonalJournalApp({super.key, required this.isDarkMode});

  @override
  State<PersonalJournalApp> createState() => _PersonalJournalAppState();
}

class _PersonalJournalAppState extends State<PersonalJournalApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  void _toggleTheme(bool value) async {
    setState(() => _isDarkMode = value);
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Journal',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF8F5FF),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(colorScheme: const ColorScheme.dark(primary: Colors.indigo)),
      home: MainPage(onThemeChanged: _toggleTheme, isDarkMode: _isDarkMode),
    );
  }
}

class MainPage extends StatefulWidget {
  final void Function(bool) onThemeChanged;
  final bool isDarkMode;

  const MainPage({
    super.key,
    required this.onThemeChanged,
    required this.isDarkMode,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 1;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Widget> _pages = [
      GalleryPage(searchQuery: _searchQuery),
      HomePage(searchQuery: _searchQuery),
      SettingsPage(
        onThemeChanged: widget.onThemeChanged,
        isDarkMode: widget.isDarkMode,
      ),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 2,
        toolbarHeight: 70,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _selectedIndex != 2
              ? Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF3F3F5),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.4)
                            : Colors.grey.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14.5,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search,
                        size: 22,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      hintText: _selectedIndex == 0
                          ? 'Cari foto di galeri...'
                          : 'Cari catatan...',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
        ),
      ),

      // === BODY (switch antar halaman) ===
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Stack(
            children: [
              _pages[_selectedIndex],

              // FAB tambah catatan hanya di halaman HOME
              if (_selectedIndex == 1)
                Positioned(
                  bottom: 72,
                  right: 30,
                  child: FloatingActionButton(
                    heroTag: 'addNoteBtn',
                    backgroundColor: Colors.indigo.shade400,
                    elevation: 8,
                    tooltip: 'Tambah Catatan',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddNotePage(),
                        ),
                      );
                    },
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),

      // === FAB utama (menu Home) ===
      floatingActionButton: FloatingActionButton.large(
        heroTag: 'homeBtn',
        onPressed: () => setState(() => _selectedIndex = 1),
        backgroundColor: Colors.indigo,
        shape: const CircleBorder(),
        elevation: 8,
        tooltip: 'Beranda',
        child: const Icon(Icons.home, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // === Bottom Navigation ===
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        elevation: 10,
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        shadowColor: Colors.black38,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.photo_library),
                onPressed: () => _onItemTapped(0),
                color: _selectedIndex == 0
                    ? Colors.indigo
                    : theme.iconTheme.color?.withOpacity(0.6),
                iconSize: 26,
                tooltip: 'Galeri',
              ),
              const SizedBox(width: 48),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _onItemTapped(2),
                color: _selectedIndex == 2
                    ? Colors.indigo
                    : theme.iconTheme.color?.withOpacity(0.6),
                iconSize: 26,
                tooltip: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
