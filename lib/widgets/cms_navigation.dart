import 'package:flutter/material.dart';

/// Keep the order, labels, colors and 768px breakpoint in sync with the CMS.
const cmsDestinations = [
  (label: 'Home', icon: Icons.home_outlined),
  (label: 'Discover', icon: Icons.explore_outlined),
  (label: 'Transparency', icon: Icons.receipt_long_outlined),
  (label: 'Documents', icon: Icons.folder_outlined),
  (label: 'About us', icon: Icons.info_outline),
];

class CmsNavigation extends StatelessWidget {
  const CmsNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    this.compact = true,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final small = MediaQuery.sizeOf(context).width < 360;
    final tabs = Row(
      mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (var index = 0; index < cmsDestinations.length; index++)
          if (compact)
            Expanded(child: _destination(index, small))
          else
            _destination(index, false),
      ],
    );
    return Material(
      color: compact ? const Color(0xFF7BD0ED) : const Color(0xFF155571),
      borderRadius: compact ? BorderRadius.zero : BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: compact
          ? SafeArea(top: false, child: tabs)
          : Padding(padding: const EdgeInsets.all(4), child: tabs),
    );
  }

  Widget _destination(int index, bool small) {
    final destination = cmsDestinations[index];
    final selected = selectedIndex == index;
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: () => onSelect(index),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 2 : 16,
            vertical: compact ? 10 : 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (compact) ...[
                Container(
                  width: 52,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFB9E8F7)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    destination.icon,
                    color: const Color(0xFF063847),
                    size: 22,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Container(
                decoration: !compact && selected
                    ? BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white, width: 2),
                        ),
                      )
                    : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    destination.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: compact ? const Color(0xFF063847) : Colors.white,
                      fontFamily: 'Poppins',
                      height: 1.4,
                      fontSize: compact ? (small ? 10 : 11) : 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
