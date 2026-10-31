import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/status_screen.dart';
import '../features/auth/domain/user_profile.dart';
import 'presentation/shared.dart';
import 'presentation/calendar_pages.dart';
import 'presentation/auth_pages.dart';
import 'presentation/booking_pages.dart';
import 'presentation/admin_pages.dart';
import 'presentation/info_pages.dart';
import 'presentation/support_pages.dart';

// Palette measured from fond.boyarka.site (Astra global colors).
ThemeData dachaTheme() {
  const green = Color(0xFF36674D);
  const text = Color(0xFF666666);
  const border = Color(0xFFD1D5DB);
  const pale = Color(0xFFF0F5FA);
  const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(4)),
  );
  final scheme = ColorScheme.fromSeed(seedColor: green).copyWith(
    primary: green,
    onPrimary: Colors.white,
    secondary: const Color(0xFF309140),
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: text,
    onSurfaceVariant: text,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: pale,
    surfaceContainer: pale,
    surfaceContainerHigh: pale,
    surfaceContainerHighest: pale,
    outline: const Color(0xFF757575),
    outlineVariant: border,
    primaryContainer: pale,
    onPrimaryContainer: green,
    secondaryContainer: pale,
    onSecondaryContainer: green,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.white,
    textTheme: base.textTheme
        .apply(bodyColor: text, displayColor: text)
        .copyWith(
          headlineMedium: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            color: text,
            height: 1.25,
          ),
          headlineSmall: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: text,
            height: 1.3,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: text,
          ),
          bodyLarge: const TextStyle(fontSize: 18, color: text, height: 1.5),
          bodyMedium: const TextStyle(fontSize: 16, color: text, height: 1.5),
          labelLarge: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: green,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 72,
      shape: Border(bottom: BorderSide(color: border)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: green,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: green,
        side: const BorderSide(color: green),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: green,
        minimumSize: const Size(48, 48),
        shape: shape,
      ),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        side: BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: const InputDecorationThemeData(
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: border),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: green, width: 2),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: pale,
      selectedColor: pale,
      labelStyle: TextStyle(
        color: green,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide(color: border),
      shape: shape,
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
  );
}

const dachaLocalizations = GlobalMaterialLocalizations.delegates;
const dachaLocales = [Locale('uk')];

GoRouter createRouter({String? initialLocation}) => GoRouter(
  initialLocation: initialLocation,
  overridePlatformDefaultLocation: initialLocation != null,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => CalendarPage(
        date: state.uri.queryParameters['date'],
        roomId: state.uri.queryParameters['room'],
        view: state.uri.queryParameters['view'],
      ),
    ),
    GoRoute(
      path: '/calendar',
      builder: (context, state) => CalendarPage(
        pagePath: '/calendar',
        date: state.uri.queryParameters['date'],
        roomId: state.uri.queryParameters['room'],
        view: state.uri.queryParameters['view'],
      ),
    ),
    GoRoute(
      path: '/schedule',
      builder: (context, state) => CalendarPage(
        pagePath: '/schedule',
        view: state.uri.queryParameters['view'],
        date: state.uri.queryParameters['date'],
        roomId: state.uri.queryParameters['room'],
      ),
    ),
    GoRoute(
      path: '/archive',
      builder: (context, state) => CalendarPage(
        pagePath: '/archive',
        view: state.uri.queryParameters['view'],
        date: state.uri.queryParameters['date'],
        roomId: state.uri.queryParameters['room'],
      ),
    ),
    GoRoute(path: '/rooms', builder: (context, state) => const RoomsPage()),
    GoRoute(path: '/help', builder: (context, state) => const HelpPage()),
    GoRoute(
      path: '/contacts',
      builder: (context, state) => const ContactsPage(),
    ),
    GoRoute(
      path: '/events/:id',
      builder: (context, state) => EventPage(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) =>
          LoginPage(returnTo: state.uri.queryParameters['returnTo']),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const LoginPage(registerInitially: true),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const LoginPage(resetOnly: true),
    ),
    GoRoute(path: '/verify-email', redirect: (context, state) => '/account'),
    GoRoute(path: '/account', builder: (context, state) => const AccountPage()),
    GoRoute(
      path: '/my-bookings',
      builder: (context, state) => const ProtectedPage(
        roles: [UserRole.organizer, UserRole.admin],
        child: BookingsPage(),
      ),
    ),
    GoRoute(
      path: '/bookings/new',
      builder: (context, state) => ProtectedPage(
        roles: const [UserRole.organizer, UserRole.admin],
        child: BookingFormPage(
          initialRoomId: state.uri.queryParameters['room'],
        ),
      ),
    ),
    GoRoute(
      path: '/bookings/:id/edit',
      builder: (context, state) => ProtectedPage(
        roles: const [UserRole.organizer, UserRole.admin],
        child: BookingFormPage(
          id: state.pathParameters['id'],
          editSeries: state.uri.queryParameters['series'] == '1',
        ),
      ),
    ),
    GoRoute(
      path: '/bookings/:id',
      builder: (context, state) => ProtectedPage(
        roles: const [UserRole.organizer, UserRole.admin],
        child: BookingDetailPage(id: state.pathParameters['id']!),
      ),
    ),
    GoRoute(path: '/my/bookings', redirect: (context, state) => '/my-bookings'),
    GoRoute(
      path: '/my/bookings/new',
      redirect: (context, state) => '/bookings/new',
    ),
    GoRoute(
      path: '/my/bookings/:id/edit',
      redirect: (context, state) =>
          '/bookings/${state.pathParameters['id']}/edit',
    ),
    GoRoute(
      path: '/my/bookings/:id',
      redirect: (context, state) => '/bookings/${state.pathParameters['id']}',
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const ProtectedPage(
        roles: [UserRole.admin],
        child: BookingsPage(forAdmin: true),
      ),
    ),
    GoRoute(path: '/admin/bookings', redirect: (context, state) => '/admin'),
    GoRoute(
      path: '/admin/bookings/:id',
      builder: (context, state) => ProtectedPage(
        roles: const [UserRole.admin],
        child: BookingDetailPage(id: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/admin/events/new',
      builder: (context, state) => ProtectedPage(
        roles: const [UserRole.admin],
        child: BookingFormPage(
          approved: true,
          initialRoomId: state.uri.queryParameters['room'],
        ),
      ),
    ),
    GoRoute(path: '/admin/calendar', redirect: (context, state) => '/admin'),
    GoRoute(
      path: '/admin/rooms',
      builder: (context, state) =>
          const ProtectedPage(roles: [UserRole.admin], child: AdminRoomsPage()),
    ),
    GoRoute(
      path: '/admin/users',
      builder: (context, state) =>
          const ProtectedPage(roles: [UserRole.admin], child: AdminUsersPage()),
    ),
    GoRoute(
      path: '/feedback',
      builder: (context, state) => const ProtectedPage(
        roles: [UserRole.organizer, UserRole.admin],
        child: FeedbackPage(),
      ),
    ),
    GoRoute(
      path: '/support',
      builder: (context, state) => const ProtectedPage(
        roles: [UserRole.admin, UserRole.developer],
        child: SupportPage(),
      ),
    ),
    GoRoute(
      path: '/support/new',
      builder: (context, state) =>
          const ProtectedPage(roles: [UserRole.admin], child: NewTicketPage()),
    ),
    GoRoute(
      path: '/support/:id',
      builder: (context, state) => ProtectedPage(
        roles: const [UserRole.admin, UserRole.developer],
        child: TicketPage(id: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/forbidden',
      builder: (context, state) => const AppFrame(
        title: 'Немає доступу',
        child: Text('Ця сторінка недоступна для вашої ролі.'),
      ),
    ),
  ],
  errorBuilder: (context, state) => StatusScreen(
    title: 'Сторінку не знайдено',
    message: 'Перевірте адресу або поверніться на головну.',
    action: FilledButton(
      onPressed: () => context.go('/'),
      child: const Text('На головну'),
    ),
  ),
);

class DachaApp extends StatelessWidget {
  const DachaApp({super.key, required this.router});
  final GoRouter router;
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Дача',
    debugShowCheckedModeBanner: false,
    theme: dachaTheme(),
    locale: const Locale('uk'),
    supportedLocales: dachaLocales,
    localizationsDelegates: dachaLocalizations,
    routerConfig: router,
  );
}

class StartupApp extends StatelessWidget {
  const StartupApp({super.key, this.error});
  final String? error;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Дача',
    debugShowCheckedModeBanner: false,
    theme: dachaTheme(),
    locale: const Locale('uk'),
    supportedLocales: dachaLocales,
    localizationsDelegates: dachaLocalizations,
    home: StatusScreen(
      title: error == null
          ? 'Відкриваємо Дачу'
          : 'Не вдалося запустити застосунок',
      message: error ?? 'Зачекайте, будь ласка.',
      loading: error == null,
    ),
  );
}
