import 'package:flutter/material.dart';

/// Цветовая палитра VPN App
/// Темная тема с технологичным стилем
class AppColors {
  // Основные цвета фона - Тёмно-синий/серый
  static const Color darkBg = Color(0xFF0F1419); // Основной фон (очень тёмный)
  static const Color darkBgSecondary = Color(0xFF1A1F2E); // Вторичный фон для карточек
  static const Color darkBgTertiary = Color(0xFF252D3D); // Третичный фон для элементов

  // Основной цвет - Глубокий синий/фиолетовый
  static const Color primaryDeep = Color(0xFF1E3A8A); // Глубокий синий
  static const Color primaryDeepLight = Color(0xFF2563EB); // Более светлый глубокий синий

  // Вторичный цвет - Яркий голубой (для активных состояний, иконок)
  static const Color accentCyan = Color(0xFF06B6D4); // Яркий голубой/циан
  static const Color accentCyanLight = Color(0xFF22D3EE); // Более светлый голубой

  // Третичный цвет - Жёлтый/Золотистый (для CTA, премиум-статуса)
  static const Color accentGold = Color(0xFFFCD34D); // Ярко-жёлтый/золотистый
  static const Color accentGoldDark = Color(0xFFF59E0B); // Более тёмный золотистый

  // Нейтральные цвета
  static const Color white = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFFE8E8E8); // Основной текст (светлый)
  static const Color textSecondary = Color(0xFFB0B0B0); // Вторичный текст (серый)
  static const Color textTertiary = Color(0xFF787878); // Третичный текст (тёмный серый)

  // Цвета статусов
  static const Color success = Color(0xFF10B981); // Зелёный - успех
  static const Color error = Color(0xFFEF4444); // Красный - ошибка
  static const Color warning = Color(0xFFF59E0B); // Оранжевый - предупреждение
  static const Color info = Color(0xFF3B82F6); // Голубой - информация

  // Границы и разделители
  static const Color borderLight = Color(0xFF404860); // Светлая граница
  static const Color borderDark = Color(0xFF2A3142); // Тёмная граница
  static const Color divider = Color(0xFF1F2937); // Разделитель

  // Свечение (для эффектов свечения и теней)
  static const Color glowCyan = Color(0xFF06B6D4); // Свечение голубое
  static const Color glowGold = Color(0xFFFCD34D); // Свечение золотое
  static const Color glowPurple = Color(0xFF8B5CF6); // Свечение фиолетовое

  // Прозрачные версии для наложений
  static const Color cyanOverlay = Color(0x1A06B6D4); // Голубой оверлей 10%
  static const Color goldOverlay = Color(0x1AFCD34D); // Золотой оверлей 10%
  static const Color darkOverlay = Color(0x80000000); // Тёмный оверлей 50%
}
