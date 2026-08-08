import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppInputTextWidget extends StatefulWidget {
  final TextEditingController? controller;
  final Color? filledColor;
  final String? label;
  final String? hintText;
  final TextInputType keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? maxLength;
  final double? errorFontSize;
  final String? counterText;
  final String? helperText;
  final String? value;
  final bool capitalize;
  final double verticalPadding;
  final TextAlign? textAlign;
  final List<TextInputFormatter>? inputFormatters;

  const AppInputTextWidget({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
    this.maxLength,
    this.helperText,
    this.maxLines,
    this.counterText,
    this.inputFormatters,
    this.value,
    this.verticalPadding = 16,
    this.filledColor,
    this.textAlign,
    this.errorFontSize,
    this.capitalize = true,
  });

  @override
  State<AppInputTextWidget> createState() => _AppInputTextWidgetState();
}

class _AppInputTextWidgetState extends State<AppInputTextWidget> {
  bool showHideToggle = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        initialValue: widget.value,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        controller: widget.controller,
        keyboardType: widget.keyboardType,
        textAlign: widget.textAlign ?? TextAlign.start,
        textCapitalization: widget.capitalize?
             TextCapitalization.sentences
            : TextCapitalization.none,
        obscureText: widget.obscureText && !showHideToggle,
        enabled: widget.enabled,
        focusNode: widget.focusNode,
        textInputAction: widget.textInputAction,
        validator: widget.validator,
        onChanged: widget.onChanged,
        maxLength: widget.maxLength,
        maxLines: widget.obscureText ? 1 : widget.maxLines,
        inputFormatters: widget.inputFormatters,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          errorStyle: TextStyle(fontSize: widget.errorFontSize ?? 14),
          fillColor: widget.filledColor,
          contentPadding: EdgeInsets.symmetric(
            vertical: widget.verticalPadding,
            horizontal: 12,
          ),
          labelText: widget.label,
          hintText: widget.hintText,
          counterText: widget.counterText,
          helperText: widget.helperText,
          prefixIcon: widget.prefixIcon != null
              ? Icon(
                  fill: 1,
                  widget.prefixIcon,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,

          suffixIcon: widget.obscureText
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      showHideToggle = !showHideToggle;
                    });
                  },
                  icon: Icon(
                    showHideToggle
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : widget.suffixIcon != null
              ? IconButton(
                  onPressed: widget.onSuffixIconTap,
                  icon: Icon(widget.suffixIcon),
                )
              : null,
        ),
      ),
    );
  }
}
