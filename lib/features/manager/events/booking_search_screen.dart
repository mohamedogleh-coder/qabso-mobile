import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utill/error_widget.dart';
import '../../../utill/loading_widget.dart';
import 'event_repository.dart';
import 'models/booking_search_result_model.dart';
import 'widgets/booking_search_card_widget.dart';

/// Finds a booking by the customer's phone number.
///
/// The one thing a manager does at the desk when somebody says "I booked
/// already" and cannot remember the code. It searches while they type and
/// opens the whole booking on a tap.
class BookingSearchScreen extends StatefulWidget {
  final String stadiumId;

  const BookingSearchScreen({super.key, required this.stadiumId});

  @override
  State<BookingSearchScreen> createState() => _BookingSearchScreenState();
}

class _BookingSearchScreenState extends State<BookingSearchScreen> {
  /// The database refuses a shorter search, and rightly: three digits would
  /// match most of the stadium.
  static const _fewestDigits = 4;

  /// Long enough that a number is not searched digit by digit, short enough
  /// that the results feel like they are keeping up.
  static const _waitBeforeSearching = Duration(milliseconds: 400);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _debounce;

  /// Null until the first real search. That is what tells the screen to show
  /// its opening advice rather than an empty result.
  Future<List<BookingSearchResultModel>>? _resultsFuture;

  String _typed = '';

  @override
  void initState() {
    super.initState();

    // The manager came here to type, so the keyboard is already up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _digits => _typed.replaceAll(RegExp(r'[^0-9]'), '');

  bool get _isLongEnough => _digits.length >= _fewestDigits;

  /// Waits for the typing to settle before asking the database, so a ten digit
  /// number costs one search rather than ten.
  void _onChanged(String value) {
    setState(() => _typed = value);

    _debounce?.cancel();

    if (!_isLongEnough) {
      setState(() => _resultsFuture = null);
      return;
    }

    _debounce = Timer(_waitBeforeSearching, _search);
  }

  void _search() {
    if (!_isLongEnough) return;

    setState(() {
      _resultsFuture = EventRepository.searchBookingsByPhone(
        stadiumId: widget.stadiumId,
        phone: _typed,
      );
    });
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();

    setState(() {
      _typed = '';
      _resultsFuture = null;
    });

    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(titleSpacing: 8, title: _buildSearchField()),
      body: SafeArea(child: _buildBody()),
    );
  }

  /// The box itself, in the app bar where a search box belongs.
  Widget _buildSearchField() {
    final theme = Theme.of(context);

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
        LengthLimitingTextInputFormatter(20),
      ],
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: "Search by phone number",
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        suffixIcon: _typed.isEmpty
            ? null
            : IconButton(
                onPressed: _clear,
                tooltip: "Clear",
                icon: const Icon(Symbols.close),
              ),
      ),
      onChanged: _onChanged,
      onSubmitted: (_) => _search(),
    );
  }

  Widget _buildBody() {
    // Nothing has been asked for yet, or not enough of it.
    if (_resultsFuture == null) return _buildAdvice();

    return FutureBuilder<List<BookingSearchResultModel>>(
      future: _resultsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }

        if (snapshot.hasError) {
          final error = snapshot.error;

          return ErrorRetryWidget(
            errorMessage: error is PostgrestException
                ? error.message
                : error.toString(),
            onRetry: _search,
          );
        }

        final results = snapshot.data ?? const <BookingSearchResultModel>[];

        if (results.isEmpty) return _buildNothingFound();

        return _buildResults(results);
      },
    );
  }

  Widget _buildResults(List<BookingSearchResultModel> results) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            results.length == 1
                ? "1 booking found"
                : "${results.length} bookings found",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            itemCount: results.length,
            itemBuilder: (context, index) => BookingSearchCardWidget(
              key: ValueKey(results[index].eventId),
              result: results[index],
            ),
          ),
        ),
      ],
    );
  }

  /// What the screen says before it has been given enough to go on. It says
  /// what can be typed rather than sitting blank.
  Widget _buildAdvice() {
    final theme = Theme.of(context);
    final isTooShort = _typed.isNotEmpty && !_isLongEnough;

    return _buildMessage(
      icon: Symbols.call,
      title: isTooShort ? "Keep typing" : "Find a booking",
      message: isTooShort
          ? "At least $_fewestDigits digits are needed to search."
          : "Type any part of the customer's number — the last few digits "
                "are enough.",
      theme: theme,
    );
  }

  Widget _buildNothingFound() {
    return _buildMessage(
      icon: Symbols.search_off,
      title: "No booking found",
      message: "No booking at this stadium was paid for with that number.",
      theme: Theme.of(context),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
    required ThemeData theme,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 34,
                fill: 1,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
