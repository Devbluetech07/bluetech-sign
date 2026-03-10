import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  bool _isCollapsed = false;
  final TextEditingController _globalSearchController = TextEditingController();

  final List<Map<String, dynamic>> _mainNav = [
    {'to': '/documents', 'label': 'Documentos', 'icon': LucideIcons.fileText},
    {'to': '/integrations', 'label': 'Integrações', 'icon': LucideIcons.zap},
    {'to': '/folders', 'label': 'Pastas', 'icon': LucideIcons.folderTree},
    {'to': '/templates', 'label': 'Modelos', 'icon': LucideIcons.layers},
    {'to': '/contacts', 'label': 'Contatos', 'icon': LucideIcons.users},
    {'to': '/bulk-send', 'label': 'Envio em massa', 'icon': LucideIcons.shield},
    {'to': '/analytics', 'label': 'Relatórios', 'icon': LucideIcons.barChart3},
    {'to': '/team', 'label': 'Equipe', 'icon': LucideIcons.users},
    {
      'to': '/departments',
      'label': 'Departamentos',
      'icon': LucideIcons.building2,
    },
  ];

  final List<Map<String, dynamic>> _bottomNav = [
    {'to': '/api-docs', 'label': 'API & Webhooks', 'icon': LucideIcons.code2},
    {'to': '/settings', 'label': 'Configurações', 'icon': LucideIcons.settings},
  ];

  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _globalSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return Scaffold(
      drawer: isMobile ? _buildSidebar(isMobile: true) : null,
      appBar: isMobile
          ? AppBar(
              title: const Text(
                'SignProof',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
            )
          : null,
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(isMobile: false),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.backgroundGradient,
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.tealNeon.withValues(alpha: 0.04),
                              Colors.transparent,
                              AppTheme.goldSoft.withValues(alpha: 0.04),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        if (!isMobile) _buildTopBar(),
                        Expanded(child: widget.child),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 360,
                child: TextField(
                  controller: _globalSearchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar documentos, contatos...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.tealNeon),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(LucideIcons.bell, color: Colors.white70),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('2', style: TextStyle(fontSize: 9)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.tealMedium,
            child: Text(
              'US',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar({required bool isMobile}) {
    final sidebarWidth = _isCollapsed && !isMobile ? 70.0 : 250.0;
    final currentPath = GoRouterState.of(context).uri.path;

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF122D36), Color(0xFF0B1F26)],
        ),
        border: Border(
          right: BorderSide(color: AppTheme.tealNeon.withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        children: [
          // Header / Logo
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: _isCollapsed && !isMobile
                ? Alignment.center
                : Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              mainAxisAlignment: _isCollapsed && !isMobile
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (_isCollapsed && !isMobile)
                  Image.asset('assets/images/logo.png', height: 32, fit: BoxFit.contain)
                else
                  Image.asset('assets/images/logo.png', height: 48, fit: BoxFit.contain),
              ],
            ),
          ),

          // New Document Button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: _isCollapsed && !isMobile ? 0 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 4,
              ),
              onPressed: () {
                if (isMobile) Navigator.pop(context);
                context.push('/documents/new');
              },
              child: _isCollapsed && !isMobile
                  ? const Icon(LucideIcons.plus, size: 20)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.plus, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Novo documento',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ),

          // Main menu text
          if (!_isCollapsed || isMobile)
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MENU',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),

          // Navigation list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _mainNav.map((item) {
                final isActive =
                    currentPath == item['to'] ||
                    (item['to'] != '/dashboard' &&
                        currentPath.startsWith(item['to']));
                return _buildNavItem(item, isActive, currentPath, isMobile);
              }).toList(),
            ),
          ),

          // Bottom Nav
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Divider(color: Colors.white12),
                ..._bottomNav.map((item) {
                  final isActive = currentPath.startsWith(item['to']);
                  return _buildNavItem(item, isActive, currentPath, isMobile);
                }),
                InkWell(
                  onTap: _handleLogout,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: _isCollapsed && !isMobile
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        const Icon(
                          LucideIcons.logOut,
                          size: 20,
                          color: Colors.white70,
                        ),
                        if (!_isCollapsed || isMobile) ...[
                          const SizedBox(width: 12),
                          const Text(
                            'Sair',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (!_isCollapsed || isMobile)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: AppTheme.goldSoft,
                          child: Text(
                            'DB',
                            style: TextStyle(fontSize: 10, color: Colors.black),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dev Bluetech',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'empresa@signproof.com',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                // Collapse toggle button
                if (!isMobile)
                  IconButton(
                    icon: Icon(
                      _isCollapsed
                          ? LucideIcons.chevronRight
                          : LucideIcons.chevronLeft,
                      color: Colors.white54,
                    ),
                    onPressed: () =>
                        setState(() => _isCollapsed = !_isCollapsed),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    Map<String, dynamic> item,
    bool isActive,
    String currentPath,
    bool isMobile,
  ) {
    return InkWell(
      onTap: () {
        if (isMobile) Navigator.pop(context);
        context.go(item['to']);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.symmetric(
          vertical: 12,
          horizontal: _isCollapsed && !isMobile ? 0 : 12,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: _isCollapsed && !isMobile
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(
              item['icon'],
              size: 20,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white70,
            ),
            if (!_isCollapsed || isMobile) ...[
              const SizedBox(width: 12),
              Text(
                item['label'],
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white70,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
