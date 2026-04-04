import 'package:flutter/material.dart';
import '../../../../../core/theme.dart';

class OverlayAutocomplete<T> extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final List<T> suggestions;
  final String Function(T) labelOf;
  final String? Function(T) subtitleOf;
  final void Function(T) onSelect;
  final void Function(String) onChanged;
  final VoidCallback? onSubmit;
  final String? createLabel;
  final VoidCallback? onCreate;
  final Widget? prefix;
  final bool autofocus;

  const OverlayAutocomplete({
    super.key,
    required this.controller,
    required this.hint,
    required this.suggestions,
    required this.labelOf,
    required this.onSelect,
    required this.onChanged,
    required this.subtitleOf,
    this.onSubmit,
    this.createLabel,
    this.onCreate,
    this.prefix,
    this.autofocus = false,
  });

  @override
  State<OverlayAutocomplete<T>> createState() =>
      _OverlayAutocompleteState<T>();
}

class _OverlayAutocompleteState<T>
    extends State<OverlayAutocomplete<T>> {
  final _key = GlobalKey();
  OverlayEntry? _entry;

  void _show() {
    _remove();
    if (widget.suggestions.isEmpty && widget.createLabel == null) return;

    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    // Snapshot data so overlay doesn't read mutable state
    final suggestions = List<T>.from(widget.suggestions);
    final createLabel = widget.createLabel;
    final onCreate = widget.onCreate;

    _entry = OverlayEntry(
      builder: (_) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 4,
        width: size.width,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(14),
          color: AppColors.surfaceHigh,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...suggestions.map((s) => InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        widget.onSelect(s);
                        _remove();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(widget.labelOf(s),
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13)),
                            ),
                            if (widget.subtitleOf != null &&
                                widget.subtitleOf!(s) != null)
                              Text(widget.subtitleOf!(s)!,
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12)),
                          ],
                        ),
                      ),
                    )),
                if (createLabel != null && onCreate != null) ...[
                  if (suggestions.isNotEmpty)
                    const Divider(height: 1, color: AppColors.border),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      onCreate();
                      _remove();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      child: Text(
                        createLabel,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _remove() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void didUpdateWidget(OverlayAutocomplete<T> old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _show());
  }

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _key,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.suggestions.isNotEmpty || widget.createLabel != null
              ? AppColors.primary.withOpacity(0.5)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          if (widget.prefix != null) ...[
            const SizedBox(width: 12),
            widget.prefix!,
          ],
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              autofocus: widget.autofocus,
              onChanged: (v) {
                widget.onChanged(v);
              },
              onSubmitted: (_) => widget.onSubmit?.call(),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: const TextStyle(
                    color: AppColors.textMuted, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
                filled: false,
              ),
            ),
          ),
          if (widget.controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                widget.controller.clear();
                widget.onChanged('');
                _remove();
              },
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.close_rounded,
                    size: 15, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}
