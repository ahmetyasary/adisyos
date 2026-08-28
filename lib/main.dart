import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orderix/themes/app_theme.dart';
import 'package:orderix/themes/app_colors.dart';
import 'package:orderix/translations/app_translations.dart';
import 'package:orderix/navigation/app_shell.dart';
import 'package:orderix/views/auth_screen.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/kitchen_service.dart';
import 'package:orderix/services/inventory_service.dart';
import 'package:orderix/services/shift_service.dart';
import 'package:orderix/services/day_service.dart';
import 'package:orderix/services/menu_service.dart';
import 'package:orderix/services/digital_menu_service.dart';
import 'package:orderix/services/digital_menu_order_service.dart';
import 'package:orderix/services/local_notify_service.dart';
import 'package:orderix/services/table_service.dart';
import 'package:orderix/services/cari_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/services/staff_service.dart';
import 'package:orderix/services/section_service.dart';
import 'package:orderix/guards/auth_middleware.dart';
import 'package:orderix/services/subscription_service.dart';
// Clean architecture layers
import 'package:orderix/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:orderix/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:orderix/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/login_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/logout_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/get_user_role_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/reset_password_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/signup_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/update_password_usecase.dart';
import 'package:orderix/features/auth/domain/usecases/change_password_usecase.dart';
import 'package:orderix/features/auth/presentation/controller/auth_controller.dart';
import 'package:orderix/features/ordi/presentation/ordi_controller.dart';
import 'package:orderix/features/ordi/presentation/ordi_voice_service.dart';
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
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  _assertEnv('SUPABASE_URL', _kSupabaseUrl);
  _assertEnv('SUPABASE_ANON_KEY', _kSupabaseAnonKey);

  await Supabase.initialize(
    url: _kSupabaseUrl,
    anonKey: _kSupabaseAnonKey,
  );

  await SubscriptionService.configure();

  _registerAuth();
  Get.put(SubscriptionService());

  // Registration order matters: SalesHistoryService, KitchenService and
  // InventoryService must all exist before TableService starts.
  Get.put(SettingsService());
  // Apply saved theme before first frame (prefs hydrate continues in onInit).
  await SettingsService.to.ensureThemeLoaded();
  Get.put(StaffService());
  Get.put(SectionService());
  Get.put(SalesHistoryService());
  Get.put(CariService());
  Get.put(KitchenService());
  Get.put(InventoryService());
  Get.put(ShiftService());
  Get.put(DayService());
  Get.put(MenuService());
  Get.put(DigitalMenuService());
  Get.put(TableService());
  await Get.putAsync(() => LocalNotifyService().init());
  Get.put(DigitalMenuOrderService());

  // Ordi reads the services above to build its context snapshot, so it must be
  // registered after them.
  Get.put(OrdiController());
  await Get.putAsync(() => OrdiVoiceService().init());

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
    loginUseCase: LoginUseCase(repository),
    logoutUseCase: LogoutUseCase(repository),
    getCurrentUserUseCase: GetCurrentUserUseCase(repository),
    getUserRoleUseCase: GetUserRoleUseCase(repository),
    signUpUseCase: SignUpUseCase(repository),
    deleteAccountUseCase: DeleteAccountUseCase(repository),
    resetPasswordUseCase: ResetPasswordUseCase(repository),
    updatePasswordUseCase: UpdatePasswordUseCase(repository),
    changePasswordUseCase: ChangePasswordUseCase(repository),
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
      SubscriptionService.to.refreshCustomerInfo();
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
      if (Get.isRegistered<DigitalMenuOrderService>()) {
        DigitalMenuOrderService.to.onAppResumed();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Orderix',
      debugShowCheckedModeBanner: false,
      scrollBehavior: _SmoothScrollBehavior(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: AppTheme.themeModeFrom(SettingsService.to.themeMode.value),
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
      builder: (context, child) {
        return Obx(() {
          // Depend on preference + epoch so AppColors stays correct.
          final mode = SettingsService.to.themeMode.value;
          final _ = SettingsService.to.themeEpoch.value;
          final scale = SettingsService.to.uiScaleFactor;
          final preferred = AppTheme.themeModeFrom(mode);
          // Resolve from preference + platform — never copy lagging Theme.
          final brightness = switch (preferred) {
            ThemeMode.light => Brightness.light,
            ThemeMode.dark => Brightness.dark,
            ThemeMode.system => MediaQuery.platformBrightnessOf(context),
          };
          AppColors.syncBrightness(brightness);
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  AppColors.isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness:
                  AppColors.isDark ? Brightness.dark : Brightness.light,
            ),
          );
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: ResponsiveBreakpoints.builder(
              child: child!,
              breakpoints: [
                const Breakpoint(start: 0, end: 450, name: MOBILE),
                const Breakpoint(start: 451, end: 800, name: TABLET),
                const Breakpoint(start: 801, end: 1920, name: DESKTOP),
                const Breakpoint(
                  start: 1921,
                  end: double.infinity,
                  name: '4K',
                ),
              ],
            ),
          );
        });
      },
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
          page: () => const AppShell(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: AppRoutes.reports,
          page: () => const AppShell(initialSectionId: 'reports'),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: AppRoutes.employees,
          page: () => const AppShell(initialSectionId: 'staff_report'),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: AppRoutes.settings,
          page: () => const AppShell(initialSectionId: 'settings'),
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
  ) =>
      child;
}
