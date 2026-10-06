import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav.dart';
import 'services/auth_service.dart';
import 'utils/app_route.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/monitoring_hub_screen.dart';
import 'screens/resource_monitoring_screen.dart';
import 'screens/env_monitoring_screen.dart';
import 'screens/history_log_screen.dart';
import 'screens/nutrition_screen.dart';
import 'screens/nutrition_feed_program_screen.dart';
import 'screens/nutrition_vitamins_screen.dart';
import 'screens/report_create_screen.dart';
import 'screens/farm_logs_screen.dart';
import 'screens/farm_log_input_screen.dart';
import 'screens/report_upload_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/advisory_list_screen.dart';
import 'services/nutrition_service.dart';
import 'services/vitamin_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore the persisted light/dark choice before the first frame.
  await farmoraTheme.load();
  // Load any session persisted by the Hostinger PHP auth flow.
  await AuthService.instance.restore();
  runApp(const FarmoraApp());
}

class FarmoraApp extends StatelessWidget {
  const FarmoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Watching the theme controller rebuilds the entire tree the instant the
    // switch flips, so every FarmoraColors getter resolves against the new
    // palette without an app restart.
    return ListenableBuilder(
      listenable: farmoraTheme,
      builder: (context, _) => MaterialApp(
        title: 'Farmora',
        debugShowCheckedModeBanner: false,
        theme: FarmoraTheme.themeData,
        darkTheme: FarmoraTheme.darkThemeData,
        themeMode: farmoraTheme.isDark ? ThemeMode.dark : ThemeMode.light,
        // Deliberately not `const`: a fresh MainShell instance forces every
        // screen below it to rebuild and re-read the palette. A `const` here
        // would canonicalise the subtree so a theme flip would NOT repaint
        // until some unrelated setState fired in the current screen.
        // ignore: prefer_const_constructors
        home: MainShell(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  String _screen = 'login';
  bool _initialized = false;
  bool _needsRefreshFarmLogs = false;
  bool _needsRefreshReports = false;

  // The id of the user whose data is currently loaded into the process-wide
  // service singletons. Used to detect a logout or an account switch so the
  // caches can be cleared and re-fetched for the new user.
  String? _loadedUserId;

  final List<String> _navScreens = const [
    'home',
    'monitoringHub',
    'resourceMonitoring',
    'envMonitoring',
    'historyLog',
    'nutrition',
    'nutritionFeedProgram',
    'nutritionVitamins',
    'farmLogs',
    'reportCreate',
    'profile',
  ];

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    // A restored session means the user lands straight on home.
    _initialized = true;
    if (AuthService.instance.isSignedIn) {
      _screen = 'home';
      _loadedUserId = AuthService.instance.userIdStr;
    }
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _setupAuthListener() {
    AuthService.instance.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final auth = AuthService.instance;
    final newUserId = auth.isSignedIn ? auth.userIdStr : null;
    if (!mounted) return;

    // Clear cached per-user data whenever the account changes or the user
    // signs out, so a fresh login never shows the previous user's records.
    if (newUserId != _loadedUserId) {
      VitaminService.instance.reset();
      NutritionService.instance.reset();
      _loadedUserId = newUserId;
    }

    setState(() {
      if (auth.isSignedIn) {
        // Always land on (or stay on) home for a newly authenticated user.
        if (_screen == 'login') _screen = 'home';
      } else {
        _screen = 'login';
      }
    });
  }

  void _go(String id) {
    setState(() => _screen = id);
  }

  void _triggerFarmLogsRefresh() {
    setState(() {
      _needsRefreshFarmLogs = true;
    });
  }

  void _triggerReportsRefresh() {
    setState(() {
      _needsRefreshReports = true;
    });
  }

  Future<void> _signOut() async {
    await AuthService.instance.logout();
    // Belt-and-braces: the auth listener also resets, but clear eagerly here
    // so cached data is gone before the sign-out frame paints.
    VitaminService.instance.reset();
    NutritionService.instance.reset();
    _loadedUserId = null;
  }

  Widget _buildScreen() {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_screen) {
      case 'login':
        return LoginScreen(onEnter: () => _go('home'));
      case 'home':
        return HomeScreen(go: _go);
      case 'monitoringHub':
        return MonitoringHubScreen(go: _go);
      case 'resourceMonitoring':
        return ResourceMonitoringScreen(go: _go);
      case 'envMonitoring':
        return EnvMonitoringScreen(go: _go);
      case 'historyLog':
        return HistoryLogScreen(go: _go);
      case 'nutrition':
        return NutritionScreen(go: _go);
      case 'nutritionFeedProgram':
        return NutritionFeedProgramScreen(go: _go);
      case 'nutritionVitamins':
        return NutritionVitaminsScreen(go: _go);
      case 'reportCreate':
        return ReportCreateScreen(
          go: _go,
          needsRefresh: _needsRefreshReports,
          onRefreshComplete: () => setState(() => _needsRefreshReports = false),
        );
      case 'farmLogs':
        return FarmLogsScreen(
          go: _go,
          needsRefresh: _needsRefreshFarmLogs,
          onRefreshComplete: () =>
              setState(() => _needsRefreshFarmLogs = false),
        );
      case 'farmLogInput':
        return FarmLogInputScreen(
            go: _go, onSubmitted: _triggerFarmLogsRefresh);
      case 'reportUpload':
        return ReportUploadScreen(go: _go, onSubmitted: _triggerReportsRefresh);
      case 'camera':
        return CameraScreen(go: _go);
      case 'notifications':
        return NotificationsScreen(go: _go);
      case 'profile':
        return ProfileScreen(go: _go, onSignOut: _signOut);
      case 'feedback':
        return FeedbackScreen(go: _go);
      case 'advisoryList':
        return AdvisoryListScreen(go: _go);
      default:
        return HomeScreen(go: _go);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showNav = _navScreens.contains(_screen);

    return PopScope(
      // On the login screen let the system back button exit the app.
      canPop: _screen == 'login',
      onPopInvokedWithResult: (didPop, _) {
        // For sub-screens, route back to their logical parent instead of
        // closing the app.
        if (didPop) return;
        const childParents = {
          'resourceMonitoring': 'monitoringHub',
          'envMonitoring': 'monitoringHub',
          'historyLog': 'monitoringHub',
          'nutrition': 'monitoringHub',
          'nutritionFeedProgram': 'nutrition',
          'nutritionVitamins': 'nutrition',
          'farmLogInput': 'farmLogs',
          'reportUpload': 'reportCreate',
          'camera': 'farmLogs',
          'notifications': 'home',
          'feedback': 'profile',
          'advisoryList': 'home',
        };
        _go(childParents[_screen] ?? 'home');
      },
      child: Scaffold(
        backgroundColor: FarmoraColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  // shellScreenTransition applies its own ease, so feed it a
                  // linear ramp to avoid double-easing.
                  switchInCurve: Curves.linear,
                  switchOutCurve: Curves.linear,
                  transitionBuilder: shellScreenTransition,
                  child: KeyedSubtree(
                    // A new key per screen triggers the slide + fade.
                    key: ValueKey(_screen),
                    child: _buildScreen(),
                  ),
                ),
              ),
              if (showNav) BottomNav(screen: _screen, go: _go),
            ],
          ),
        ),
      ),
    );
  }
}
