import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/fields/field_model.dart';

import '../../../utill/app_constants.dart';
import 'add_new_field_screen.dart';

class FieldCardWidget extends StatefulWidget {
  final FieldModel model;

  const FieldCardWidget({super.key, required this.model});

  @override
  State<FieldCardWidget> createState() => _FieldCardWidgetState();
}

class _FieldCardWidgetState extends State<FieldCardWidget> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: expanded ? 1 : 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddNewFieldScreen(fieldModel: widget.model),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Symbols.grass,
                        size: 24,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: .spaceBetween,
                            children: [
                              Text(
                                "Field #${widget.model.id}",
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '\$${widget.model.cost}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: AppConstants.success,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: .spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Symbols.people, size: 16),
                                  Text(
                                    " ${widget.model.capacity} players",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Symbols.wallpaper, size: 16),
                                  Text(
                                    widget.model.fieldImages.isEmpty
                                        ? " No Photos"
                                        : " ${widget.model.fieldImages.length} Photos",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 24),
            Row(
              mainAxisAlignment: .spaceAround,
              children: [
                TextButton.icon(
                  onPressed: () {},
                  icon: Icon(Symbols.image, fill: 1),
                  label: Text("View Images"),
                ),
                VerticalDivider(thickness: 1, width: 10, color: Colors.black),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      expanded = !expanded;
                    });
                  },
                  icon: Icon(
                    expanded ? Symbols.arrow_drop_up : Symbols.arrow_drop_down,
                  ),
                  label: Text(expanded ? "Hide events" : "Show events"),
                ),
              ],
            ),
            AnimatedSize(
              duration: AppConstants.animationDuration,
              child: !expanded
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildEventsPlaceholder(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).highlightColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          "Events coming soon",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
