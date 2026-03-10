import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/core/auth_provider.dart';

class AppLayout extends StatelessWidget {
  final Widget child;

  const AppLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 250,
            color: Theme.of(context).colorScheme.surface,
            child: const AppSidebar(),
          ),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Column(
      children: [
        const SizedBox(height: 32),
        Text(
          'Valeris',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),
        _NavItem(icon: Icons.home, title: 'Início', path: '/'),
        _NavItem(icon: Icons.draw, title: 'Assinatura', path: '/assinatura'),
        _NavItem(icon: Icons.badge, title: 'Documento', path: '/documento'),
        _NavItem(icon: Icons.face, title: 'Selfie', path: '/selfie'),
        _NavItem(icon: Icons.how_to_reg, title: 'Selfie + Doc', path: '/selfie-doc'),
        _NavItem(icon: Icons.key, title: 'Chaves API', path: '/api-keys'),
        _NavItem(icon: Icons.history, title: 'Download Base', path: '/downloads'),
        const Spacer(),
        ListTile(
          leading: const Icon(Icons.person, color: Colors.grey),
          title: Text(auth.user?.nomeCompleto ?? auth.user?.email ?? '', style: const TextStyle(color: Colors.white70)),
          subtitle: Text(auth.user?.email ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Sair', style: TextStyle(color: Colors.grey)),
          onTap: () async {
            await auth.logout();
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String path;

  const _NavItem({required this.icon, required this.title, required this.path});

  @override
  Widget build(BuildContext context) {
    final routeMatch = GoRouterState.of(context).uri.toString();
    final isActive = routeMatch == path;

    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? Theme.of(context).colorScheme.secondary : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.grey,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        context.go(path);
      },
    );
  }
}
