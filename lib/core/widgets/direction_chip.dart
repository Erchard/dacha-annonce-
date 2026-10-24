import 'package:flutter/material.dart';

const _directionColors = <String, (Color, Color)>{
  'Емоційна підтримка': (Color(0xFFECFDF5), Color(0xFF065F46)),
  'Екологія': (Color(0xFFF0FDF4), Color(0xFF166534)),
  'Культура': (Color(0xFFFFFBEB), Color(0xFF92400E)),
  'Громадська активність': (Color(0xFFEFF6FF), Color(0xFF1E40AF)),
  'Освіта, просвіта': (Color(0xFFEEF2FF), Color(0xFF3730A3)),
  'Толока': (Color(0xFFF7FEE7), Color(0xFF3F6212)),
  'Благоустрій Дачі': (Color(0xFFF0FDFA), Color(0xFF115E59)),
  'Психологічна допомога': (Color(0xFFFFF1F2), Color(0xFF9F1239)),
  'Майстер-клас': (Color(0xFFFFF7ED), Color(0xFF9A3412)),
  'Клуб': (Color(0xFFFAF5FF), Color(0xFF6B21A8)),
  'Для людей старшого віку': (Color(0xFFF0F9FF), Color(0xFF075985)),
  'Для дітей': (Color(0xFFFEFCE8), Color(0xFF854D0E)),
  'Для молоді': (Color(0xFFECFEFF), Color(0xFF155E75)),
  'Творчі зустрічі': (Color(0xFFFDF4FF), Color(0xFF86198F)),
  'Концерт': (Color(0xFFFDF2F8), Color(0xFF9D174D)),
};

(Color, Color) directionColors(String direction) =>
    _directionColors[direction] ??
    (const Color(0xFFF3F4F6), const Color(0xFF374151));

class DirectionChip extends StatelessWidget {
  const DirectionChip({
    super.key,
    required this.direction,
    this.selected = false,
    this.onTap,
  });

  final String direction;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = directionColors(direction);
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? fg : bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        direction,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: selected ? bg : fg,
        ),
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: child,
    );
  }
}

class DirectionChipWrap extends StatelessWidget {
  const DirectionChipWrap({
    super.key,
    required this.directions,
    this.selected,
    this.onToggle,
  });

  final Iterable<String> directions;
  final Set<String>? selected;
  final ValueChanged<String>? onToggle;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final direction in directions)
            DirectionChip(
              direction: direction,
              selected: selected?.contains(direction) ?? false,
              onTap: onToggle == null ? null : () => onToggle!(direction),
            ),
        ],
      );
}

