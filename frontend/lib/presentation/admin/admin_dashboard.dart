import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel Administrativo', style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Visão geral da plataforma Valeris', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildKpiCard(context, 'Empresas ativas', '12', LucideIcons.building2, Theme.of(context).colorScheme.primary)),
                const SizedBox(width: 16),
                Expanded(child: _buildKpiCard(context, 'Usuários', '1,245', LucideIcons.users, Theme.of(context).colorScheme.secondary)),
                const SizedBox(width: 16),
                Expanded(child: _buildKpiCard(context, 'Documentos (mês)', '10,482', LucideIcons.fileText, Colors.blueAccent)),
                const SizedBox(width: 16),
                Expanded(child: _buildKpiCard(context, 'Receita (MRR)', 'R\$ 42.000', LucideIcons.dollarSign, Colors.orangeAccent)),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Expanded(
                   flex: 2,
                   child: _buildAlertsCard(context)
                 ),
                 const SizedBox(width: 24),
                 Expanded(
                    flex: 1,
                    child: _buildRecentActivityCard(context)
                 ),
              ]
            )
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsCard(BuildContext context) {
      return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                 const Icon(LucideIcons.alertTriangle, size: 18, color: Colors.orangeAccent),
                 const SizedBox(width: 8),
                 const Text('Alertas de Consumo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            _buildAlertItem('TechCorp SA', 'Atingiu 90% do limite de documentos', Colors.orangeAccent),
            _buildAlertItem('Logistics BR', 'Plano expirando em 2 dias', Colors.redAccent),
          ]
        )
      )
      );
  }

  Widget _buildAlertItem(String company, String message, Color color) {
     return Container(
       margin: const EdgeInsets.only(bottom: 12),
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
       child: Row(
          children: [
            Icon(LucideIcons.bell, size: 16, color: color),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(company, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(message, style: TextStyle(color: color, fontSize: 12)),
              ],
            )
          ]
       )
     );
  }

  Widget _buildRecentActivityCard(BuildContext context) {
       return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Atividade Recente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            _buildActivityItem('Nova empresa registrada', 'Construtora Silva', 'Há 5 min'),
            _buildActivityItem('Fatura paga', 'Agência XYZ', 'Há 2 horas'),
          ]
        )
      )
      );
  }

   Widget _buildActivityItem(String action, String target, String time) {
     return Padding(
       padding: const EdgeInsets.only(bottom: 16),
       child: Row(
          children: [
             Container(
               width: 32, height: 32,
               decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
               child: const Icon(LucideIcons.activity, size: 14, color: Colors.white54),
             ),
             const SizedBox(width: 12),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(action, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                   Text(target, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                 ],
               ),
             ),
             Text(time, style: const TextStyle(fontSize: 10, color: Colors.white38)),
          ]
       ),
     );
  }
}
