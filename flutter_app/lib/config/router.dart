import '../models/document.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/home_screen.dart';
import '../screens/records_screen.dart';
import '../screens/upload_screen.dart';
import '../screens/search_screen.dart';
import '../screens/document_detail_screen.dart';
import '../screens/health_params_screen.dart';
import '../screens/health_trends_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/main_shell.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoading = authProvider.loading;
      final isAuthenticated = authProvider.isAuthenticated;
      final isAuthRoute = state.uri.toString() == '/login' ||
          state.uri.toString() == '/signup';

      if (isLoading) return '/';
      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/home';
      if (isAuthenticated && state.uri.toString() == '/') return '/home';

      return null;
    },
    refreshListenable: authProvider,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),

      // Main shell routes
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/records',
            builder: (context, state) => const RecordsScreen(),
          ),
          GoRoute(
            path: '/health',
            builder: (context, state) => const HealthParamsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),

      // Standalone routes (no bottom nav)
      GoRoute(
        path: '/upload',
        builder: (context, state) => const UploadScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/documents/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final doc = state.extra is MedicalDocument
              ? state.extra as MedicalDocument
              : null;
          return DocumentDetailScreen(
            documentId: id,
            initialDocument: doc,
          );
        },
      ),
      GoRoute(
        path: '/trends/:parameter',
        builder: (context, state) {
          final parameter = state.pathParameters['parameter']!;
          return HealthTrendsScreen(parameter: parameter);
        },
      ),
    ],
  );
}
