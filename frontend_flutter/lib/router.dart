import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Screens
import 'package:frontend_flutter/ui/pages/login_page.dart';
import 'package:frontend_flutter/ui/pages/home_page.dart';
import 'package:frontend_flutter/ui/components/app_layout.dart';
import 'package:frontend_flutter/core/auth_provider.dart';

import 'package:frontend_flutter/ui/pages/assinatura_page.dart';
import 'package:frontend_flutter/ui/pages/documento_page.dart';
import 'package:frontend_flutter/ui/pages/selfie_page.dart';
import 'package:frontend_flutter/ui/pages/selfie_doc_page.dart';
import 'package:frontend_flutter/ui/pages/api_keys_page.dart';
import 'package:frontend_flutter/ui/pages/docs_page.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isLoggedIn = authProvider.isAuthenticated;
      final isGoingToLogin = state.uri.toString() == '/login';

      if (!isLoggedIn && !isGoingToLogin) {
        return '/login';
      }

      if (isLoggedIn && isGoingToLogin) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/assinatura',
            builder: (context, state) => const AssinaturaPage(),
          ),
          GoRoute(
            path: '/documento',
            builder: (context, state) => const DocumentoPage(),
          ),
          GoRoute(
            path: '/selfie',
            builder: (context, state) => const SelfiePage(),
          ),
          GoRoute(
            path: '/selfie-doc',
            builder: (context, state) => const SelfieDocPage(),
          ),
          GoRoute(
            path: '/api-keys',
            builder: (context, state) => const ApiKeysPage(),
          ),
          GoRoute(
            path: '/downloads',
            builder: (context, state) => const DownloadsPage(),
          ),
          GoRoute(
            path: '/docs',
            builder: (context, state) => const DocsPage(),
          ),
        ],
      )
    ],
  );
}
