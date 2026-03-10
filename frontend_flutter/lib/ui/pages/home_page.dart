import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Central de Microserviços API',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bem-vindo ao Valeris. Selecione um serviço ao lado para testar a integração ou acesse a documentação.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _FeatureCard(
                 title: 'Assinatura', 
                 desc: 'Captura de canvas em base64', 
                 icon: Icons.draw,
                 onTap: () => context.go('/assinatura'),
                 color: Theme.of(context).colorScheme.primary,
              ),
              _FeatureCard(
                 title: 'Documento', 
                 desc: 'Smart crop e OCR de CNH/RG', 
                 icon: Icons.badge,
                 onTap: () => context.go('/documento'),
                 color: Theme.of(context).colorScheme.primary,
              ),
              _FeatureCard(
                 title: 'Selfie', 
                 desc: 'Verificação facial (liveness em breve)', 
                 icon: Icons.face,
                 onTap: () => context.go('/selfie'),
                 color: Theme.of(context).colorScheme.primary,
              ),
            ]
          )
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _FeatureCard({required this.title, required this.desc, required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
          boxShadow: [
             BoxShadow(
               color: color.withOpacity(0.05),
               blurRadius: 20,
               spreadRadius: -5,
             )
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(desc, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
