import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/story_provider.dart';
import 'providers/friend_provider.dart';
import 'providers/message_provider.dart';
import 'providers/social_provider.dart';
import 'providers/coop_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'services/api_service.dart';
import 'services/offline_service.dart';
import 'services/socket_service.dart';
import 'services/push_notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  final apiService = ApiService();
  await apiService.init();

  final offlineService = OfflineService();
  await offlineService.init();

  final themeProvider = ThemeProvider();
  final socketService = SocketService(apiService);
  final pushService = PushNotificationService(apiService);

  // Initialize push notifications (safe — gracefully fails if Firebase not configured)
  try {
    await pushService.init();
  } catch (_) {}

  runApp(StoryForgeApp(
    apiService: apiService,
    offlineService: offlineService,
    themeProvider: themeProvider,
    socketService: socketService,
    pushService: pushService,
  ));
}

class StoryForgeApp extends StatelessWidget {
  final ApiService apiService;
  final OfflineService offlineService;
  final ThemeProvider themeProvider;
  final SocketService socketService;
  final PushNotificationService pushService;

  const StoryForgeApp({
    super.key,
    required this.apiService,
    required this.offlineService,
    required this.themeProvider,
    required this.socketService,
    required this.pushService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<OfflineService>.value(value: offlineService),
        ChangeNotifierProvider<SocketService>.value(value: socketService),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService, socketService, pushService)),
        ChangeNotifierProvider(create: (_) => StoryProvider(apiService, socketService, offlineService)),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => FriendProvider(apiService, socketService)),
        ChangeNotifierProvider(create: (_) => MessageProvider(apiService, socketService)),
        ChangeNotifierProvider(create: (_) => SocialProvider(apiService, socketService)),
        ChangeNotifierProvider(create: (_) => CoopProvider(apiService, socketService)),
        ChangeNotifierProvider(create: (_) => NotificationProvider(apiService, socketService)),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, tp, _) {
          return MaterialApp(
            title: 'StoryForge',
            debugShowCheckedModeBanner: false,
            themeMode: tp.themeMode,
            theme: tp.lightTheme,
            darkTheme: tp.darkTheme,
            locale: tp.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  Future<void> _checkAuth() async {
    final auth = context.read<AuthProvider>();
    await auth.tryAutoLogin();
    setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final auth = context.watch<AuthProvider>();
    if (auth.isAuthenticated) {
      return const DashboardScreen();
    }
    return const LoginScreen();
  }
}
