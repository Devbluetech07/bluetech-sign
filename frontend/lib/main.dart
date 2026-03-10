import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/app_theme.dart';

import 'presentation/auth/login_page.dart';
import 'presentation/layouts/main_layout.dart';
import 'presentation/layouts/admin_layout.dart';
import 'presentation/dashboard/dashboard_page.dart';
import 'presentation/document_flow/document_flow_page.dart';
import 'presentation/signing/public_signing_page.dart';

import 'presentation/admin/admin_dashboard.dart';
import 'presentation/admin/admin_companies.dart';
import 'presentation/admin/admin_company_details.dart';
import 'presentation/admin/admin_settings.dart';

// Import de Placeholder Pages (serão criadas a seguir)
import 'presentation/documents/documents_page.dart';
import 'presentation/documents/document_detail_page.dart';
import 'presentation/integrations/integrations_page.dart';
import 'presentation/folders/folders_page.dart';
import 'presentation/templates/templates_page.dart';
import 'presentation/contacts/contacts_page.dart';
import 'presentation/bulk_send/bulk_send_page.dart';
import 'presentation/analytics/analytics_page.dart';
import 'presentation/team/team_page.dart';
import 'presentation/departments/departments_page.dart';
import 'presentation/api_docs/api_docs_page.dart';
import 'presentation/settings/settings_page.dart';

void main() {
  usePathUrlStrategy();
  runApp(const SingproofApp());
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

final GoRouter _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/documents/new',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DocumentFlowPage(),
    ),
    // Public Signer Route (No Sidebar, standalone)
    GoRoute(
      path: '/sign/:token',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final token = state.pathParameters['token']!;
        return PublicSigningPage(token: token);
      },
    ),
    ShellRoute(
      navigatorKey: GlobalKey<NavigatorState>(),
      builder: (context, state, child) {
        return AdminLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const AdminDashboardPage(),
        ),
        GoRoute(
          path: '/admin/companies',
          builder: (context, state) => const AdminCompaniesPage(),
        ),
        GoRoute(
          path: '/admin/companies/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return AdminCompanyDetailsPage(companyId: id);
          },
        ),
        GoRoute(
          path: '/admin/settings',
          builder: (context, state) => const AdminSettingsPage(),
        ),
      ],
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          redirect: (context, state) => '/documents',
        ),
        GoRoute(
          path: '/documents',
          builder: (context, state) => const DocumentsPage(),
        ),
        GoRoute(
          path: '/documents/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return DocumentDetailPage(documentId: id);
          },
        ),
        GoRoute(
          path: '/integrations',
          builder: (context, state) => const IntegrationsPage(),
        ),
        GoRoute(
          path: '/folders',
          builder: (context, state) => const FoldersPage(),
        ),
        GoRoute(
          path: '/templates',
          builder: (context, state) => const TemplatesPage(),
        ),
        GoRoute(
          path: '/contacts',
          builder: (context, state) => const ContactsPage(),
        ),
        GoRoute(
          path: '/bulk-send',
          builder: (context, state) => const BulkSendPage(),
        ),
        GoRoute(
          path: '/analytics',
          builder: (context, state) => const AnalyticsPage(),
        ),
        GoRoute(path: '/team', builder: (context, state) => const TeamPage()),
        GoRoute(
          path: '/departments',
          builder: (context, state) => const DepartmentsPage(),
        ),
        GoRoute(
          path: '/api-docs',
          builder: (context, state) => const ApiDocsPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);

class SingproofApp extends StatelessWidget {
  const SingproofApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SignProof by Valeris',
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.themeData,
      routerConfig: _router,
    );
  }
}
