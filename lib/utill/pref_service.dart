import 'package:shared_preferences/shared_preferences.dart';

/// What the app remembers on the phone between runs.
///
/// Opened once in main(), so every call below is plain and immediate and a
/// screen can ask what it needs while it is building.
///
/// A screen is named by its route — the same string it is pushed with — so
/// nothing here invents a second set of names.
abstract class PrefService {
  static late final SharedPreferences _prefs;

  static const _hiddenInfoKey = 'hidden_info';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Every screen whose information panel the user has closed.
  static List<String> list() =>
      _prefs.getStringList(_hiddenInfoKey) ?? const [];

  /// Whether this screen's information panel is closed.
  static bool get(String screen) => list().contains(screen);

  /// Closes this screen's information panel, and keeps it closed.
  static Future<void> put(String screen) async {
    final hidden = list();
    if (hidden.contains(screen)) return;

    await _prefs.setStringList(_hiddenInfoKey, [...hidden, screen]);
  }

  /// Opens it again.
  static Future<void> delete(String screen) async {
    final hidden = list();
    if (!hidden.contains(screen)) return;

    await _prefs.setStringList(
      _hiddenInfoKey,
      hidden.where((name) => name != screen).toList(),
    );
  }
}
