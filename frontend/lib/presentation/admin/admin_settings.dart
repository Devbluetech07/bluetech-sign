import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../widgets/glass_container.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _maintenanceMode = false;
  bool _useMocks = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Admin • Configurações',
                    style: TextStyle(
                      fontSize: 26,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TabBar(
                  controller: _tab,
                  tabs: const [
                    Tab(text: 'Geral'),
                    Tab(text: 'Microsserviços'),
                    Tab(text: 'Planos'),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      GlassContainer(
                        borderColor: Colors.white12,
                        padding: const EdgeInsets.all(16),
                        child: ListView(
                          children: [
                            const TextField(
                              decoration: InputDecoration(
                                labelText: 'Nome da plataforma',
                                hintText: 'SignProof',
                              ),
                            ),
                            const SizedBox(height: 10),
                            const TextField(
                              decoration: InputDecoration(
                                labelText: 'URL base da API',
                                hintText: 'http://localhost:3001/api/v1',
                              ),
                            ),
                            const SizedBox(height: 10),
                            SwitchListTile(
                              value: _maintenanceMode,
                              onChanged: (v) =>
                                  setState(() => _maintenanceMode = v),
                              title: const Text('Modo manutenção'),
                            ),
                          ],
                        ),
                      ),
                      GlassContainer(
                        borderColor: Colors.white12,
                        padding: const EdgeInsets.all(16),
                        child: ListView(
                          children: [
                            const TextField(
                              decoration: InputDecoration(
                                labelText: 'URL Assinatura',
                                hintText: 'https://sign.valeris.com',
                              ),
                            ),
                            const SizedBox(height: 10),
                            const TextField(
                              decoration: InputDecoration(
                                labelText: 'URL Coleta Documento',
                                hintText: 'https://doc.valeris.com',
                              ),
                            ),
                            const SizedBox(height: 10),
                            const TextField(
                              decoration: InputDecoration(
                                labelText: 'URL Selfie',
                                hintText: 'https://selfie.valeris.com',
                              ),
                            ),
                            const SizedBox(height: 10),
                            const TextField(
                              decoration: InputDecoration(
                                labelText: 'URL Selfie+Documento',
                                hintText: 'https://selfiedoc.valeris.com',
                              ),
                            ),
                            const SizedBox(height: 10),
                            SwitchListTile(
                              value: _useMocks,
                              onChanged: (v) => setState(() => _useMocks = v),
                              title: const Text('Usar mocks'),
                            ),
                          ],
                        ),
                      ),
                      GlassContainer(
                        borderColor: Colors.white12,
                        padding: const EdgeInsets.all(16),
                        child: ListView(
                          children: const [
                            ListTile(
                              title: Text('Starter'),
                              subtitle: Text(
                                'Até 5 usuários • 200 docs/mês • R\$ 99',
                              ),
                            ),
                            ListTile(
                              title: Text('Professional'),
                              subtitle: Text(
                                'Até 25 usuários • 2.000 docs/mês • R\$ 399',
                              ),
                            ),
                            ListTile(
                              title: Text('Enterprise'),
                              subtitle: Text(
                                'Usuários ilimitados • docs ilimitados • sob consulta',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
