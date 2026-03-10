import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações', style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Perfil'),
                  Tab(text: 'Conta'),
                  Tab(text: 'Notificações'),
                  Tab(text: 'API'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProfileTab(),
                  _buildAccountTab(),
                  _buildNotificationsTab(),
                  _buildAPITab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informações pessoais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Text('US', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 16),
                OutlinedButton(onPressed: () {}, child: const Text('Alterar foto')),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white12),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 5,
                children: [
                  _buildTextField('Nome', 'Usuário'),
                  _buildTextField('Sobrenome', 'Silva'),
                  _buildTextField('Email', 'usuario@empresa.com'),
                  _buildTextField('Telefone', '(11) 99999-0000'),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
                onPressed: () {},
                child: const Text('Salvar alterações'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAccountTab() {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Configurações da conta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildTextField('Nome da empresa', 'Minha Empresa LTDA'),
            const SizedBox(height: 16),
            _buildTextField('CNPJ', '12.345.678/0001-90'),
            const Spacer(),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
                onPressed: () {},
                child: const Text('Salvar'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Preferências de notificação', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildSwitchItem('Documento assinado por todos os signatários'),
            _buildSwitchItem('Signatário visualizou o documento'),
            _buildSwitchItem('Signatário recusou assinar'),
            _buildSwitchItem('Documento próximo do prazo'),
            _buildSwitchItem('Documento expirado'),
          ],
        ),
      ),
    );
  }

  Widget _buildAPITab() {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chaves de API', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Use sua chave de API para integrar com outros sistemas.', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            const Text('Chave de acesso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(readOnly: true, controller: TextEditingController(text: 'sk-live-••••••••••••••••'), decoration: _inputDecoration())),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () {}, child: const Text('Copiar')),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField('Webhook URL', 'https://seusite.com/webhook'),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
                onPressed: () {},
                child: const Text('Salvar'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: value),
          decoration: _inputDecoration(),
        )
      ],
    );
  }

  Widget _buildSwitchItem(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Switch(value: true, onChanged: (v) {}, activeColor: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
