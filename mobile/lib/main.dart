import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'models/platform_model.dart';
import 'models/post_model.dart';
import 'services/storage_service.dart';
import 'services/update_service.dart';
import 'pages/dashboard_page.dart';
import 'pages/compose_page.dart';
import 'pages/accounts_page.dart';
import 'pages/history_page.dart';
import 'pages/settings_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface900,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const PostXApp());
}

class PostXApp extends StatelessWidget {
  const PostXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PostX App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
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
  List<PlatformAccount> _accounts = [];
  List<PostHistoryEntry> _history = [];
  Map<String, dynamic> _settings = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final accounts = await StorageService.loadAccounts();
    final history = await StorageService.loadHistory();
    final settings = await StorageService.loadSettings();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _history = history;
      _settings = settings;
    });
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    final update = await UpdateService.checkForUpdate();
    if (update != null && mounted) {
      UpdateService.showUpdateDialog(context, update);
    }
  }

  Future<void> _handleLogin(SocialPlatform platform) async {
    final config = getPlatformConfig(platform);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WebViewLoginPage(platform: config),
      ),
    );

    if (result == true && mounted) {
      final existing = _accounts.where((a) => a.platformId == platform).firstOrNull;
      if (existing != null) {
        existing.isConnected = true;
        existing.lastLogin = DateTime.now();
        existing.displayName = '${config.name} User';
      } else {
        _accounts.add(PlatformAccount(
          platformId: platform,
          username: platform.name,
          displayName: '${config.name} User',
          isConnected: true,
          lastLogin: DateTime.now(),
        ));
      }
      await StorageService.saveAccounts(_accounts);
      setState(() {});
    }
  }

  Future<void> _handleLogout(SocialPlatform platform) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface800,
        title: const Text('Disconnect Account'),
        content: Text('Disconnect from ${getPlatformConfig(platform).name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Disconnect', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _accounts.removeWhere((a) => a.platformId == platform);
      await StorageService.saveAccounts(_accounts);
      setState(() {});
    }
  }

  Future<void> _handlePost(
    String text,
    List<String> images,
    Set<SocialPlatform> platforms,
  ) async {
    for (final platform in platforms) {
      final entry = PostHistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        imagePaths: images,
        platform: platform,
        status: PostStatus.success,
        postedAt: DateTime.now(),
      );
      _history.insert(0, entry);
    }
    await StorageService.saveHistory(_history);
    if (!mounted) return;
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Posted to ${platforms.length} platform(s)'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface800,
        title: const Text('Clear History'),
        content: const Text('Delete all post history? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear All', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _history.clear();
      await StorageService.saveHistory(_history);
      setState(() {});
    }
  }

  void _handleSettingsUpdate(String key, dynamic value) {
    setState(() => _settings[key] = value);
    StorageService.saveSettings(_settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            DashboardPage(
              accounts: _accounts,
              history: _history,
              onCompose: () => setState(() => _currentIndex = 1),
            ),
            ComposePage(
              accounts: _accounts,
              onPost: _handlePost,
            ),
            AccountsPage(
              accounts: _accounts,
              onLogin: _handleLogin,
              onLogout: _handleLogout,
            ),
            HistoryPage(
              history: _history,
              onClearHistory: _handleClearHistory,
            ),
            SettingsPage(
              settings: _settings,
              onUpdate: _handleSettingsUpdate,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        height: 64,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.red),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_square),
            selectedIcon: Icon(Icons.edit_square, color: AppColors.red),
            label: 'Compose',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: AppColors.red),
            label: 'Accounts',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history, color: AppColors.red),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppColors.red),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
