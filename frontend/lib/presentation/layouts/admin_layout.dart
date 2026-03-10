import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';

class AdminLayout extends StatefulWidget {
  final Widget child;

  const AdminLayout({super.key, required this.child});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  bool _isCollapsed = false;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _mainNav = [
    {
      'to': '/admin/dashboard',
      'label': 'Painel Admin',
      'icon': LucideIcons.layoutDashboard,
    },
    {
      'to': '/admin/companies',
      'label': 'Empresas',
      'icon': LucideIcons.building2,
    },
    {
      'to': '/admin/settings',
      'label': 'Configurações',
      'icon': LucideIcons.settings,
    },
  ];

  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _searchController.dispose();
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
                'SignProof Admin',
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
              child: SafeArea(
                child: Column(
                  children: [
                    if (!isMobile) _topBar(),
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          const Text(
            'ADMIN',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.bold,
              color: AppTheme.goldSoft,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 340,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar empresa, usuário...',
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
                  borderSide: const BorderSide(color: AppTheme.goldSoft),
                ),
              ),
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
          colors: [Color(0xFF2D2412), Color(0xFF20190A)],
        ),
        border: Border(
          right: BorderSide(color: AppTheme.goldSoft.withValues(alpha: 0.25)),
        ),
      ),
      child: Column(
        children: [
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
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _mainNav.map((item) {
                final isActive =
                    currentPath == item['to'] ||
                    currentPath.startsWith(item['to'] + '/');
                return _buildNavItem(item, isActive, currentPath, isMobile);
              }).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Divider(color: Colors.white12),
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
                          color: Colors.redAccent,
                        ),
                        if (!_isCollapsed || isMobile) ...[
                          const SizedBox(width: 12),
                          const Text(
                            'Sair do Admin',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
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
              ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15)
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
                  ? Theme.of(context).colorScheme.secondary
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
