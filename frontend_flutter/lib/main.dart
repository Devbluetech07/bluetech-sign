import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend_flutter/core/auth_provider.dart';
import 'package:frontend_flutter/router.dart';
import 'package:frontend_flutter/ui/theme.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const ValerisApp(),
    ),
  );
}

class ValerisApp extends StatefulWidget {
  const ValerisApp({super.key});

  @override
  State<ValerisApp> createState() => _ValerisAppState();
}

class _ValerisAppState extends State<ValerisApp> {
  late final _router = createRouter(context.read<AuthProvider>());

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthProvider>().isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Valeris Web',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
