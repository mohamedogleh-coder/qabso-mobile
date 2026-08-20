import 'history_model.dart';

/// The groups a booking falls into, by the day its game is on.
///
/// A game that has not been played yet is always Upcoming, even when it is
/// on today, so everything below Upcoming is history the user cannot change.
enum HistoryGroup {
  upcoming("Upcoming"),
  today("Maanta"),
  yesterday("Shalay"),
  earlier("Earlier");

  const HistoryGroup(this.label);

  final String label;
}

/// Splits the history into its groups.
///
/// The list arrives newest game first, so the groups come out in the order
/// they are shown and nothing is sorted again here. A group with no bookings
/// in it is left out, so the screen never draws an empty heading.
Map<HistoryGroup, List<HistoryModel>> groupHistory(List<HistoryModel> history) {
  final now = DateTime.now();
  final grouped = <HistoryGroup, List<HistoryModel>>{};

  for (final booking in history) {
    final group = _groupOf(booking.eventStart, now);
    grouped.putIfAbsent(group, () => []).add(booking);
  }

  return grouped;
}

HistoryGroup _groupOf(DateTime eventStart, DateTime now) {
  if (eventStart.isAfter(now)) return HistoryGroup.upcoming;

  final day = DateTime(eventStart.year, eventStart.month, eventStart.day);
  final today = DateTime(now.year, now.month, now.day);

  if (day == today) return HistoryGroup.today;
  if (day == today.subtract(const Duration(days: 1))) {
    return HistoryGroup.yesterday;
  }

  return HistoryGroup.earlier;
}
