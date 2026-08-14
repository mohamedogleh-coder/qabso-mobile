import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qabso_mobile/features/manager/expanses/expanses_screen.dart';
import 'package:qabso_mobile/features/manager/reports/screens/events_summery_screen.dart';
import 'package:qabso_mobile/features/manager/reports/screens/payments_summery_screen.dart';
import 'package:qabso_mobile/features/manager/reports/screens/reports_screen.dart';
import 'package:qabso_mobile/themes/dark_theme.dart';
import 'package:qabso_mobile/themes/light_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/app_user_model.dart';
import 'features/auth/app_user_notifer.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/registration_screen.dart';
import 'features/manager/fields/fields_screen.dart';
import 'features/manager/manager_shell.dart';
import 'features/manager/merchants/stadium_merchants_screen.dart';
import 'features/manager/stadium/stadium_settings_screen.dart';
import 'features/manager/working_days/working_days_screen.dart';
import 'features/user/user_shell.dart';
import 'utill/app_constants.dart';
import 'utill/app_utility_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
  );

  try {
    await AppUtilityService.getCurrentLocation();
  } catch (e) {
    print(e);
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
      routes: {
        AppConstants.fields: (_) => const FieldsScreen(),
        AppConstants.workingDays: (_) => const WorkingDaysScreen(),
        AppConstants.merchants: (_) => const StadiumMerchantsScreen(),
        AppConstants.stadiumProfile: (_) => const StadiumSettingsScreen(),
        AppConstants.reports: (_) => const ReportsScreen(),
        AppConstants.eventsReport: (_) => const EventsSummeryScreen(),
        AppConstants.paymentsReport: (_) => const PaymentsSummeryScreen(),
        AppConstants.expenses: (_) => const ExpansesScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text("Coming soon")),
        ),
      ),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUserAsync = ref.watch(appUserNotifierProvider);
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) {
      return const LoginScreen();
    }
    return appUserAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Something went wrong. Please try again.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.read(appUserNotifierProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (appUser) {
        if (appUser == null) {
          return const RegistrationScreen();
        }
        return switch (appUser.role) {
          AppUserRole.manager => const ManagerShell(),
          AppUserRole.user => const UserShell(),
          AppUserRole.referee => const Scaffold(
            body: Center(child: Text('Referee experience is coming soon.')),
          ),
        };
      },
    );
  }
}
