import 'package:flutter/material.dart';

import '../app_theme.dart';

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
    final viewport = MediaQuery.sizeOf(context);
    final small = viewport.width < 360;
    final shortLandscape = viewport.width >= 480 && viewport.height <= 480;
    final tabs = Row(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (var index = 0; index < cmsDestinations.length; index++)
          if (compact)
            Expanded(child: _destination(index, small, cmsDestinations[index]))
          else
            _destination(index, false, cmsDestinations[index]),
      ],
    );
    return Material(
      color: compact ? accent : const Color(0xFF155571),
      borderRadius: compact ? BorderRadius.zero : BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: compact
          ? SafeArea(
              top: false,
              child: SizedBox(height: shortLandscape ? 60 : 72, child: tabs),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(padding: const EdgeInsets.all(4), child: tabs),
            ),
    );
  }

  Widget _destination(
    int index,
    bool small,
    ({String label, IconData icon}) destination,
  ) {
    final selected = selectedIndex == index;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => onSelect(index),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 2 : 16,
            vertical: compact ? 4 : 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (compact) ...[
                Container(
                  width: 52,
                  height: 28,
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
                const SizedBox(height: 2),
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
