import 'package:flutter/material.dart';

class ErrorRetryWidget extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;
  final String? actionTitle;

  const ErrorRetryWidget({
    super.key,
    required this.errorMessage,
    this.onRetry,
    this.actionTitle,
  });

  @override
  Widget build(BuildContext context) {
    return onErrorTryAgain(
      context: context,
      errorMessage: errorMessage,
      onRetry: onRetry,
    );
  }

  Widget onErrorTryAgain({
    String? title,
    required BuildContext context,
    required String errorMessage,
    VoidCallback? onRetry,
    String? actionTitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 50,
          ),
          SizedBox(height: 8),
          Text(
            title ?? "Something went wrong",
            style: Theme.of(
              context,
            ).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            errorMessage,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            label: Text(actionTitle ?? "Try again"),
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}