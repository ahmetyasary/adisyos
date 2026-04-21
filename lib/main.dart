import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orderix/themes/app_theme.dart';
import 'package:orderix/translations/app_translations.dart';
import 'package:orderix/views/home_view.dart';
import 'package:orderix/views/auth_screen.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/kitchen_service.dart';
import 'package:orderix/services/inventory_service.dart';
import 'package:orderix/services/shift_service.dart';
import 'package:orderix/services/day_service.dart';
import 'package:orderix/services/menu_service.dart';
import 'package:orderix/services/table_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/services/staff_service.dart';
import 'package:orderix/services/section_service.dart';
import 'package:orderix/guards/auth_middleware.dart';
// Clean architecture layers
import 'package:orderix/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:orderix/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:orderix/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/login_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/logout_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/get_user_role_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/signup_usecase.dart';
import 'package:orderix/features/auth/presentation/controller/auth_controller.dart';
import 'package:orderix/views/signup_screen.dart';
import 'package:orderix/utils/app_info.dart';

// Supabase credentials are injected at build time via `--dart-define` (or
// `--dart-define-from-file=.env.local`). They are NEVER hardcoded and NEVER
// bundled as an asset, so they cannot be read from the shipped .ipa/.apk.
const String _kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String _kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppInfo.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,   // dark icons on light bg (Android)
      statusBarBrightness: Brightness.light,       // dark icons on light bg (iOS)
    ),
  );

  _assertEnv('SUPABASE_URL', _kSupabaseUrl);
  _assertEnv('SUPABASE_ANON_KEY', _kSupabaseAnonKey);

  await Supabase.initialize(
    url: _kSupabaseUrl,
    anonKey: _kSupabaseAnonKey,
  );

  _registerAuth();

  // Registration order matters: SalesHistoryService, KitchenService and
  // InventoryService must all exist before TableService starts.
  Get.put(SettingsService());
  Get.put(StaffService());
  Get.put(SectionService());
  Get.put(SalesHistoryService());
  Get.put(KitchenService());
  Get.put(InventoryService());
  Get.put(ShiftService());
  Get.put(DayService());
  Get.put(MenuService());
  Get.put(TableService());

  runApp(const MyApp());
}

/// Fails fast at startup if a required build-time environment variable is
/// missing. This prevents accidentally shipping a build without the correct
/// Supabase credentials and makes the misconfiguration obvious in debug.
void _assertEnv(String name, String value) {
  if (value.trim().isEmpty) {
    throw StateError(
      'Missing required compile-time env var "$name". '
      'Pass it via --dart-define=$name=... '
      'or --dart-define-from-file=.env.local at build/run time.',
    );
  }
}

/// Wires the full clean-architecture auth graph.
void _registerAuth() {
  final dataSource = SupabaseAuthDataSource(Supabase.instance.client);
  final repository = AuthRepositoryImpl(dataSource);

  Get.put(AuthController(
    loginUseCase:          LoginUseCase(repository),
    logoutUseCase:         LogoutUseCase(repository),
    getCurrentUserUseCase: GetCurrentUserUseCase(repository),
    getUserRoleUseCase:    GetUserRoleUseCase(repository),
    signUpUseCase:         SignUpUseCase(repository),
    deleteAccountUseCase:  DeleteAccountUseCase(repository),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back from background — refresh all services to catch
      // any changes that arrived while realtime was disconnected.
      SettingsService.to.refresh();
      StaffService.to.load();
      SectionService.to.load();
      SalesHistoryService.to.refresh();
      KitchenService.to.refresh();
      InventoryService.to.refresh();
      ShiftService.to.refresh();
      DayService.to.refresh();
      MenuService.to.refresh();
      TableService.to.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Orderix',
      debugShowCheckedModeBanner: false,
      scrollBehavior: _SmoothScrollBehavior(),
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      translations: AppTranslations(),
      locale: const Locale('tr', 'TR'),
      fallbackLocale: const Locale('en', 'US'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),
          const Breakpoint(start: 451, end: 800, name: TABLET),
          const Breakpoint(start: 801, end: 1920, name: DESKTOP),
          const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
      ),
      initialRoute: AppRoutes.login,
      getPages: [
        GetPage(
          name: AppRoutes.login,
          page: () => const AuthScreen(),
        ),
        GetPage(
          name: AppRoutes.signup,
          page: () => const SignUpScreen(),
        ),
        GetPage(
          name: AppRoutes.home,
          page: () => const HomeView(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: AppRoutes.reports,
          page: () => const HomeView(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: AppRoutes.employees,
          page: () => const HomeView(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: AppRoutes.settings,
          page: () => const HomeView(),
          middlewares: [AuthMiddleware()],
        ),
      ],
    );
  }
}

/// Removes bounce/glow overscroll on all platforms.
/// Uses ClampingScrollPhysics (hard stop at edges) everywhere.
class _SmoothScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
