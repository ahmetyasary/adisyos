import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:adisyos/themes/app_theme.dart';
import 'package:adisyos/translations/app_translations.dart';
import 'package:adisyos/views/home_view.dart';
import 'package:adisyos/views/auth_screen.dart';
import 'package:adisyos/services/menu_service.dart';
import 'package:adisyos/services/table_service.dart';
import 'package:adisyos/services/sales_history_service.dart';
import 'package:adisyos/services/kitchen_service.dart';
import 'package:adisyos/services/inventory_service.dart';
import 'package:adisyos/services/shift_service.dart';
import 'package:adisyos/guards/auth_middleware.dart';
// Clean architecture layers
import 'package:adisyos/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:adisyos/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:adisyos/features/auth/domain/usecases/login_usecase.dart';
import 'package:adisyos/features/auth/domain/usecases/logout_usecase.dart';
import 'package:adisyos/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:adisyos/features/auth/domain/usecases/get_user_role_usecase.dart';
import 'package:adisyos/features/auth/presentation/controller/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,   // dark icons on light bg (Android)
      statusBarBrightness: Brightness.light,       // dark icons on light bg (iOS)
    ),
  );

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  _registerAuth();

  // Registration order matters: SalesHistoryService, KitchenService and
  // InventoryService must all exist before TableService starts.
  Get.put(SalesHistoryService());
  Get.put(KitchenService());
  Get.put(InventoryService());
  Get.put(ShiftService());
  Get.put(MenuService());
  Get.put(TableService());

  runApp(const MyApp());
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
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Adisyos',
      debugShowCheckedModeBanner: false,
      scrollBehavior: _SmoothScrollBehavior(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
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
