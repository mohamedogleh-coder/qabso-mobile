import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../utill/app_constants.dart';

/// How long until the dashboard reads itself again.
///
/// The numbers on this screen go out of date just by being looked at, so this
/// says when they will next be checked. It counts on its own and starts over
/// whenever [restartOn] changes — that is, whenever fresh data lands.
class HomeRefreshCountdownWidget extends StatefulWidget {
  /// Anything that means the data was just read. A new value starts the count
  /// again from the top.
  final Object? restartOn;

  const HomeRefreshCountdownWidget({super.key, this.restartOn});

  @override
  State<HomeRefreshCountdownWidget> createState() =>
      _HomeRefreshCountdownWidgetState();
}

class _HomeRefreshCountdownWidgetState
    extends State<HomeRefreshCountdownWidget> {
  Timer? _ticker;
  late Duration _left;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(HomeRefreshCountdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Fresh data landed, so the wait begins again.
    if (oldWidget.restartOn != widget.restartOn) _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    _ticker?.cancel();

    // The same wait the notifier's own timer uses, so what this counts down to
    // is the read that actually happens.
    _left = AppConstants.dashboardRefreshInterval;

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        final left = _left - const Duration(seconds: 1);

        // Sitting at zero rather than going negative: the read is due, and
        // the answer landing is what starts the count again.
        _left = left.isNegative ? Duration.zero : left;
      });
    });
  }

  /// How full the ring is: full at the moment of a read, empty when the next
  /// one is due.
  double get _progress {
    final whole = AppConstants.dashboardRefreshInterval.inSeconds;

    if (whole == 0) return 0;

    return _left.inSeconds / whole;
  }

  String get _clock {
    final minutes = _left.inMinutes;
    final seconds = (_left.inSeconds % 60).toString().padLeft(2, '0');

    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDue = _left == Duration.zero;
    final color = isDue ? AppConstants.warning : AppConstants.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The ring empties as the wait runs down, so the countdown reads at
          // a glance without the numbers being read at all.
          SizedBox(
            height: 16,
            width: 16,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: isDue ? null : _progress,
                  strokeWidth: 2,
                  backgroundColor: color.withValues(alpha: 0.20),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Icon(Symbols.autorenew, size: 9, color: color),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isDue ? "Checking now" : "Next check in $_clock",
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 1),

              // Waiting is never the only option: the manager can have the
              // numbers now, and this is where they find that out.
              Text(
                "Pull down to check now",
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
