import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'app_constants.dart';

/// Shared corner radius for every [Dialog] / [AlertDialog] shown through
/// this file, so dialogs read as one consistent system app-wide.
const double _kDialogRadius = 20;

/// Shared top corner radius for every modal bottom sheet shown through
/// this file.
const double _kSheetRadius = 24;

ShapeBorder _dialogShape([double radius = _kDialogRadius]) {
  return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
}

/// A circular icon badge used as the "hero" visual on icon-led dialogs
/// (information, error, destructive confirmation, ...).
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  static const double _size = 68;

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: _size * .53, color: color),
    );
  }
}

// -----------------------------------------------------------------------
// Confirmation dialog
// -----------------------------------------------------------------------

/// Shows a confirm/cancel dialog and returns `true` only when the user
/// confirms (dismissing the dialog any other way resolves to `false`).
///
/// Pass either [message] for simple text content or [content] for anything
/// custom; [content] wins if both are supplied.
///
/// If [onConfirm] is provided it is awaited *before* the dialog closes: the
/// confirm button shows a spinner and both buttons are disabled while it
/// runs, so a slow tap can't be fired twice. If it throws, the dialog stays
/// open and shows the error message so the user can retry or cancel — the
/// dialog is also forced non-dismissible (barrier + back button) for the
/// duration of the async call, regardless of [barrierDismissible].
///
/// Set [isDestructive] to `true` for actions like delete: the confirm
/// button turns error-colored to make the action visually distinct, unless
/// [confirmButtonColor] overrides it explicitly.
Future<bool> showAppConfirmationDialog({
  required BuildContext context,
  String title = "Are you sure?",
  String? message,
  Widget? content,
  String confirmText = "Confirm",
  String cancelText = "Cancel",
  Color? confirmButtonColor,
  bool isDestructive = false,
  IconData? icon,
  bool barrierDismissible = true,
  Future<void> Function()? onConfirm,
  Future<void> Function()? onCancel
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: onConfirm != null ? false : barrierDismissible,
    builder: (dialogContext) {
      return _ConfirmationDialog(
        title: title,
        message: message,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmButtonColor: confirmButtonColor,
        isDestructive: isDestructive,
        icon: icon,
        onConfirm: onConfirm,
      );
    },
  );

  return result ?? false;
}

class _ConfirmationDialog extends StatefulWidget {
  const _ConfirmationDialog({
    required this.title,
    required this.message,
    required this.content,
    required this.confirmText,
    required this.cancelText,
    required this.confirmButtonColor,
    required this.isDestructive,
    required this.icon,
    required this.onConfirm,
  });

  final String title;
  final String? message;
  final Widget? content;
  final String confirmText;
  final String cancelText;
  final Color? confirmButtonColor;
  final bool isDestructive;
  final IconData? icon;
  final Future<void> Function()? onConfirm;

  @override
  State<_ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<_ConfirmationDialog> {
  bool _isSubmitting = false;
  String? _errorText;

  Future<void> _handleConfirm() async {
    if (_isSubmitting) return;

    final onConfirm = widget.onConfirm;
    if (onConfirm == null) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await onConfirm();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final resolvedConfirmColor =
        widget.confirmButtonColor ??
        (widget.isDestructive ? colors.error : colors.primary);

    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        shape: _dialogShape(),
        title: widget.icon == null ? Text(widget.title) : null,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.icon != null) ...[
              Center(
                child: _IconBadge(
                  icon: widget.icon!,
                  color: resolvedConfirmColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (widget.content != null)
              widget.content!
            else if (widget.message != null)
              Text(
                widget.message!,
                textAlign: widget.icon == null
                    ? TextAlign.start
                    : TextAlign.start,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: TextStyle(color: colors.error, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting
                ? null
                : () => Navigator.pop(context, false),
            child: Text(
              widget.cancelText,
              style: TextStyle(color: colors.tertiary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: resolvedConfirmColor,
            ),
            onPressed: _isSubmitting ? null : _handleConfirm,
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(widget.confirmText),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Loading dialog
// -----------------------------------------------------------------------

/// Tracks whether the app-wide loading dialog is currently on screen so a
/// second call can't stack a duplicate spinner on top of the first.
bool _isLoadingDialogOpen = false;

/// Shows a non-interactive "please wait" dialog. Calling it again while one
/// is already open is a no-op, so rapid repeated taps on a submit button
/// can't stack multiple spinners. Always pair with [hideAppLoadingDialog].
void showAppLoadingDialog({
  required BuildContext context,
  String message = "Submitting...",
  bool dismissible = false,
}) {
  if (_isLoadingDialogOpen) return;
  _isLoadingDialogOpen = true;

  showDialog<void>(
    context: context,
    barrierDismissible: dismissible,
    builder: (_) {
      return PopScope(
        canPop: dismissible,
        child: AlertDialog(
          shape: _dialogShape(),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
    },
  ).whenComplete(() => _isLoadingDialogOpen = false);
}

/// Dismisses the loading dialog shown by [showAppLoadingDialog]. Safe to
/// call even if no loading dialog is currently open, or if [context] is no
/// longer mounted (e.g. called after an awaited network call) — both cases
/// are simply ignored.
void hideAppLoadingDialog(BuildContext context) {
  if (!_isLoadingDialogOpen) return;
  if (!context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  if (navigator.canPop()) {
    navigator.pop();
  }
}

// -----------------------------------------------------------------------
// Icon-led alert dialogs (information / error)
// -----------------------------------------------------------------------

Future<void> _showIconAlertDialog({
  required BuildContext context,
  required String title,
  required String message,
  required IconData icon,
  required Color iconColor,
  required String buttonText,
  VoidCallback? onButtonPressed,
  bool barrierDismissible = true,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final colors = theme.colorScheme;

      return AlertDialog(
        elevation: 0,
        backgroundColor: colors.surface,
        shape: _dialogShape(24),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconBadge(icon: icon, color: iconColor),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed:
                    onButtonPressed ?? () => Navigator.of(dialogContext).pop(),
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// A neutral, informational alert with a single dismiss button.
Future<void> showInformationDialog({
  required BuildContext context,
  required String message,
  String title = "Information",
  IconData icon = Symbols.info_rounded,
  String buttonText = "Got it",
  VoidCallback? onButtonPressed,
  bool barrierDismissible = true,
}) {
  return _showIconAlertDialog(
    context: context,
    title: title,
    message: message,
    icon: icon,
    iconColor: Theme.of(context).colorScheme.primary,
    buttonText: buttonText,
    onButtonPressed: onButtonPressed,
    barrierDismissible: barrierDismissible,
  );
}

/// The placeholder for a flow that is planned but not built yet, shared so
/// every unfinished action says the same thing the same way instead of each
/// screen inventing its own wording.
Future<void> showNotImplementedDialog({
  required BuildContext context,
  String title = "Weli lama dhisin",
  String message = "Qaybtan weli lama dhisin, waa la soo dari doonaa.",
  String buttonText = "Ok",
}) {
  return showInformationDialog(
    context: context,
    title: title,
    message: message,
    icon: Symbols.construction,
    buttonText: buttonText,
  );
}

/// An error alert with a single acknowledge button. [onTap] defaults to
/// simply closing the dialog.
Future<void> showAppErrorDialog({
  required BuildContext context,
  String title = "Something went wrong",
  required String message,
  String buttonText = "OK",
  VoidCallback? onTap,
  IconData icon = Icons.error_outline_rounded,
  bool barrierDismissible = true,
}) {
  return _showIconAlertDialog(
    context: context,
    title: title,
    message: message,
    icon: icon,
    iconColor: Theme.of(context).colorScheme.error,
    buttonText: buttonText,
    onButtonPressed: onTap,
    barrierDismissible: barrierDismissible,
  );
}

// -----------------------------------------------------------------------
// Bottom sheets
// -----------------------------------------------------------------------

/// The app-wide modal bottom sheet shell: rounded top corners, a drag
/// handle, and automatic padding so content never sits behind the on-screen
/// keyboard. Wrap arbitrary content — forms, lists, pickers — via [builder].
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  bool isScrollControlled = true,
  bool showDragHandle = true,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    showDragHandle: showDragHandle,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_kSheetRadius)),
    ),
    builder: (sheetContext) {
      final viewInsets = MediaQuery.of(sheetContext).viewInsets;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               if (title != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    showDragHandle ? 4 : 20,
                    20,
                    12,
                  ),
                  child: Text(
                    title,
                    style: Theme.of(sheetContext).textTheme.headlineMedium,
                  ),
                ),
              Flexible(child: builder(sheetContext)),
            ],
          ),
        ),
      );
    },
  );
}

/// One tappable row in [showAppActionSheet].
class AppBottomSheetAction<T> {
  const AppBottomSheetAction({
    required this.label,
    required this.value,
    this.icon,
    this.isDestructive = false,
  });

  final String label;
  final T value;
  final IconData? icon;
  final bool isDestructive;
}

/// A modal action sheet listing [actions]; resolves with the tapped
/// action's value, or `null` if dismissed/cancelled. Actions flagged
/// [AppBottomSheetAction.isDestructive] render in the error color so
/// destructive choices (e.g. "Delete") stand out from neutral ones.
Future<T?> showAppActionSheet<T>({
  required BuildContext context,
  required List<AppBottomSheetAction<T>> actions,
  String? title,
  bool showCancel = true,
  String cancelText = "Cancel",
}) {
  return showAppBottomSheet<T>(
    context: context,
    title: title,
    builder: (sheetContext) {
      final colors = Theme.of(sheetContext).colorScheme;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions)
            ListTile(
              leading: action.icon != null
                  ? Icon(
                      action.icon,
                      color: action.isDestructive ? colors.error : null,
                    )
                  : null,
              title: Text(
                action.label,
                style: action.isDestructive
                    ? TextStyle(color: colors.error)
                    : null,
              ),
              onTap: () => Navigator.of(sheetContext).pop(action.value),
            ),
          if (showCancel) ...[
            const Divider(height: 1),
            ListTile(
              title: Text(cancelText, textAlign: TextAlign.center),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
          const SizedBox(height: 8),
        ],
      );
    },
  );
}

// -----------------------------------------------------------------------
// Snack bars
// -----------------------------------------------------------------------

/// Shared shell behind [showSuccessSnackBar], [showErrorSnackBar], and
/// [showInfoSnackBar] so the three read as one consistent system: same
/// shape, duration, and an icon that matches the dialog styling above.
void _showAppSnackBar({
  required BuildContext context,
  required String message,
  required Color backgroundColor,
  required IconData icon,
  String? actionTitle,
  VoidCallback? onTap,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        action: actionTitle != null && onTap != null
            ? SnackBarAction(
                label: actionTitle,
                onPressed: onTap,
                textColor: Colors.white,
              )
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}

/// A brief, non-blocking confirmation that something succeeded.
void showSuccessSnackBar({
  required BuildContext context,
  required String message,
  String? actionTitle,
  VoidCallback? onTap,
}) {
  _showAppSnackBar(
    context: context,
    message: message,
    backgroundColor: AppConstants.success,
    icon: Symbols.check_circle_rounded,
    actionTitle: actionTitle,
    onTap: onTap,
  );
}

/// A brief, non-blocking error notice. For a failure the user needs to act
/// on (retry, open settings, ...), prefer [showAppErrorDialog] instead —
/// a snackbar can be missed or swiped away before it's read.
void showErrorSnackBar({
  required BuildContext context,
  required String message,
  String? actionTitle,
  VoidCallback? onTap,
}) {
  _showAppSnackBar(
    context: context,
    message: message,
    backgroundColor: Theme.of(context).colorScheme.error,
    icon: Symbols.error_rounded,
    actionTitle: actionTitle,
    onTap: onTap,
  );
}

/// A brief, non-blocking informational notice.
void showInfoSnackBar({
  required BuildContext context,
  required String message,
  String? actionTitle,
  VoidCallback? onTap,
}) {
  _showAppSnackBar(
    context: context,
    message: message,
    backgroundColor: Theme.of(context).colorScheme.tertiary,
    icon: Symbols.info_rounded,
    actionTitle: actionTitle,
    onTap: onTap,
  );
}
