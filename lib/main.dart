import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav.dart';
import 'services/supabase_client.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore the persisted light/dark choice before the first frame.
  await farmoraTheme.load();
  await initSupabase();
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
        // screen below it to rebuild and re-read the palette.
        home: const MainShell(),
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
  }

  void _setupAuthListener() {
    supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (mounted) {
        setState(() {
          if (session != null) {
            if (_screen == 'login') {
              _screen = 'home';
            }
          } else {
            _screen = 'login';
          }
          _initialized = true;
        });
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
    await supabase.auth.signOut();
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
