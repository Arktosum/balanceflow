import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models.dart';

class CategoryPicker extends StatefulWidget {
  final List<Category> categories;
  final String? selectedId;
  final void Function(String?) onSelect;

  const CategoryPicker({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Category> categories,
    required String? selectedId,
    required void Function(String?) onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CategoryPicker(
        categories: categories,
        selectedId: selectedId,
        onSelect: onSelect,
      ),
    );
  }

  @override
  State<CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<CategoryPicker> {
  String _search = '';

  List<Category> get _filtered => _search.isEmpty
      ? widget.categories
      : widget.categories
          .where((c) =>
              c.name.toLowerCase().contains(_search.toLowerCase()))
          .toList();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Select Category',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          // Search
          TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Search categories...',
              prefixIcon: Icon(Icons.search_rounded,
                  size: 18, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 10),
          // None option
          _CategoryTile(
            icon: '—',
            name: 'None',
            color: null,
            selected: widget.selectedId == null,
            onTap: () {
              widget.onSelect(null);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                final c = _filtered[i];
                return _CategoryTile(
                  icon: c.icon ?? '📁',
                  name: c.name,
                  color: c.color,
                  selected: widget.selectedId == c.id,
                  onTap: () {
                    widget.onSelect(c.id);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String icon;
  final String name;
  final String? color;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.icon,
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  Color get _parsed => parseHexColor(color);

  @override
  Widget build(BuildContext context) {
    final c = _parsed;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? c.withOpacity(0.1)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                selected ? c.withOpacity(0.4) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: selected ? c : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: c, size: 18),
          ],
        ),
      ),
    );
  }
}