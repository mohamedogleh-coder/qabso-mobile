import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/user/user_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utill/error_widget.dart';
import '../../../utill/loading_widget.dart';
import '../../manager/stadium/stadium_model.dart';
import 'favourite_notifier_provider.dart';
import 'favourite_stadium_card_widget.dart';

class FavStadiumsScreen extends ConsumerWidget {
  const FavStadiumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favouritesAsync = ref.watch(favouriteNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Text("Favourite stadiums"),
        actions: [
          TextButton.icon(
            onPressed: () {},
            label: Text("Clear all"),
            icon: Icon(Symbols.clear_all),
          ),
        ],
      ),
      body: favouritesAsync.when(
        skipLoadingOnRefresh: false,
        data: (stadiums) => stadiums.isEmpty
            ? _buildEmpty(context,ref)
            : _buildList(context, ref, stadiums),
        error: (error, stackTrace) => ErrorRetryWidget(
          errorMessage: error is PostgrestException
              ? error.message
              : error.toString(),
          onRetry: () => ref.read(favouriteNotifierProvider.notifier).refresh(),
        ),
        loading: () => const LoadingWidget(),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<StadiumModel> stadiums,
  ) {
    return RefreshIndicator(
      onRefresh: () => ref.read(favouriteNotifierProvider.notifier).refresh(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: stadiums.length,
            itemBuilder: (context, index) =>
                FavouriteStadiumCardWidget(stadium: stadiums[index]),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context,WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Symbols.book, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text("No saved stadiums yet", style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              "Explore garee kadibna save garayso garamooda aad macmiilka u tahay.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                ref.read(selectedIndexProvider.notifier).state=0;
              },
              icon: Icon(Symbols.search),
              label: Text("Explore now"),
            ),
          ],
        ),
      ),
    );
  }
}
