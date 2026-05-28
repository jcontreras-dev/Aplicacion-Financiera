import 'package:go_router/go_router.dart';
import 'package:finance_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:finance_app/features/transactions/presentation/add_transaction_screen.dart';
import 'package:finance_app/features/transactions/presentation/transaction_history_screen.dart';

final goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/add',
      builder: (context, state) {
        final autoOcr = state.extra as bool? ?? false;
        return AddTransactionScreen(autoOpenOcr: autoOcr);
      },
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const TransactionHistoryScreen(),
    ),
  ],
);
