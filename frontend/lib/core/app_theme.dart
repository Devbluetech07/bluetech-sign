import 'package:flutter/material.dart';

class AppTheme {
  // Cores Principais
  static const Color tealDark = Color(0xFF0F2C36); // Azul Petróleo Profundo
  static const Color tealMedium = Color(0xFF1B4E5E); 
  static const Color tealNeon = Color(0xFF00FFCC); // Acentos de luz
  static const Color goldSoft = Color(0xFFD4AF37); // Dourado Brilhante
  static const Color goldDark = Color(0xFFB8860B);

  // Gradiente Radial de Fundo Principal
  static const RadialGradient backgroundGradient = RadialGradient(
    center: Alignment(-0.8, 1.0), // Canto inferior esquerdo
    radius: 2.0,
    colors: [tealDark, Color(0xFF163238), Color(0xFF283A30), goldDark], // Transição suave The Teal to Gold
    stops: [0.0, 0.4, 0.7, 1.0],
  );

  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: tealNeon,
      scaffoldBackgroundColor: Colors.transparent, // Transparente pq o scaffold vai usar Container com Gradiente
      colorScheme: const ColorScheme.dark(
        primary: tealNeon,
        secondary: goldSoft,
        surface: Colors.white12, // Base para glass
        background: Colors.transparent,
      ),
      fontFamily: 'Orbitron', // or 'Inter' based on the neat gamified feel. Let's use generic sans-serif for body and Orbitron for titles
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold, color: Colors.white),
        displayMedium: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold, color: Colors.white),
        bodyLarge: TextStyle(fontFamily: 'Inter', color: Colors.white),
        bodyMedium: TextStyle(fontFamily: 'Inter', color: Colors.white70),
      ),
    );
  }
}
