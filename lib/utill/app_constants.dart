import 'package:flutter/material.dart';

abstract class AppConstants {
  static int minAppCapacity = 6;
  static int maxAppCapacity = 14;
  static int maxAppExtra = 6;

  // --- BRAND / PRIMARY COLORS ---
  static const Color primary = Color(0xFF388E3C);
  static const Color primaryHover = Color(0xFF32A169);
  static const Color primaryTint = Color(0xFF133E2B);

  static const Color lightBackground = Color(0xFFF9F8F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextMuted = Color(0xFF64748B);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // --- DARK MODE COLORS ---
  static const Color darkBackground = Color(0xFF0A0E18);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextMuted = Color(0xFF64748B);
  static const Color darkBorder = Color(0xFF334155);

  // --- ACCENTS & SYSTEM STATES ---
  static const Color secondary = Color(0xFF1E293B);
  static const Color tertiary = Color(0xFF0284C7);
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);

  //-------------- ROUTES ------------------------------------

  static const Duration animationDuration = Duration(milliseconds: 300);

  static const String appName = 'Qabso';
  static const String appVersion = 'V1.0';

  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String stadiumProfile = '/stadium-profile';
  static const String fields = '/fields';
  static const String workingDays = '/working-days';
  static const String merchants = '/merchants';
  static const String events = '/events';
  static const String expenses = '/expenses';
  static const String addExpense = '/expenses/add';
  static const String expensesList = '/expenses/list';


  //Reports path
  static const String reports = '/reports';
  static const String expansesReport = '/expanses_report';
  static const String eventsReport = '/events_report';
  static const String paymentsReport = '/payments_report';
}
