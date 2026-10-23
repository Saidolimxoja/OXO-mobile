import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// UNICON SOFT uslubidagi ranglar
class Brand {
  static const navy = Color(0xFF141B4D);
  static const navySoft = Color(0xFF2A3480);
  static const indigo = Color(0xFF3B49B5);
  static const red = Color(0xFFE1141E);

  static const green = Color(0xFF12A05C);
  static const amber = Color(0xFFB45309);

  // yorug'
  static const bgLight = Color(0xFFF5F6FB);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const textLight = Color(0xFF0F1535);
  static const mutedLight = Color(0xFF6B7391);
  static const borderLight = Color(0xFFE7E9F3);

  // qorong'i
  static const bgDark = Color(0xFF0B1020);
  static const surfaceDark = Color(0xFF161C33);
  static const textDark = Color(0xFFEDEFF7);
  static const mutedDark = Color(0xFF99A1C2);
  static const borderDark = Color(0xFF273052);

  static const brandGradient = LinearGradient(
    colors: [navy, indigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Joriy mavzuga mos ranglarni beradi
class Tone {
  final bool dark;
  const Tone(this.dark);

  factory Tone.of(BuildContext context) =>
      Tone(Theme.of(context).brightness == Brightness.dark);

  Color get bg => dark ? Brand.bgDark : Brand.bgLight;
  Color get surface => dark ? Brand.surfaceDark : Brand.surfaceLight;
  Color get text => dark ? Brand.textDark : Brand.textLight;
  Color get muted => dark ? Brand.mutedDark : Brand.mutedLight;
  Color get border => dark ? Brand.borderDark : Brand.borderLight;
  Color get sunken => dark ? const Color(0xFF0F1428) : const Color(0xFFF7F8FC);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final tone = Tone(dark);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Brand.indigo,
      brightness: brightness,
      primary: dark ? const Color(0xFF7C8AF0) : Brand.navy,
      error: Brand.red,
    ),
    scaffoldBackgroundColor: tone.bg,
    cardColor: tone.surface,
    dividerColor: tone.border,
    textTheme: Typography.material2021(platform: TargetPlatform.android)
        .black
        .apply(bodyColor: tone.text, displayColor: tone.text),
    appBarTheme: AppBarTheme(
      backgroundColor: tone.surface,
      foregroundColor: tone.text,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: tone.text,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tone.sunken,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      hintStyle: TextStyle(color: tone.muted, fontSize: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: tone.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: tone.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: dark ? const Color(0xFF7C8AF0) : Brand.indigo, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.4),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: tone.border, width: 1.4),
        foregroundColor: tone.text,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: tone.surface,
      selectedItemColor: dark ? const Color(0xFF8E9AF5) : Brand.navy,
      unselectedItemColor: tone.muted,
      selectedLabelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentTextStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: tone.surface,
    ),
  );
}

// ============ umumiy qismlar ============

/// Yumshoq soyali karta
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(18),
        border: tone.dark ? Border.all(color: tone.border) : null,
        boxShadow: tone.dark
            ? null
            : [
                BoxShadow(
                  color: Brand.navy.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: child,
    );

    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: card,
    );
  }
}

/// Bo'lim sarlavhasi
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Rangli fonli belgi (ikonka uchun)
class IconChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconChip(this.icon, {super.key, this.color = Brand.indigo, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Kompaniya logotipi (haqiqiy SVG shakli)
String brandLogoSvg({required String shapeColor}) => '''
<svg viewBox="-2 0 70 52" xmlns="http://www.w3.org/2000/svg">
  <path fill-rule="evenodd" clip-rule="evenodd" fill="$shapeColor"
    d="M14.402 27.3407L22.2763 39.4656C22.5496 39.9084 22.9081 40.2925 23.3311 40.5957C23.7541 40.8988 24.233 41.1149 24.7402 41.2315C25.2473 41.3481 25.7726 41.3627 26.2855 41.2747C26.7983 41.1866 27.2886 40.9976 27.7279 40.7185C28.1671 40.4395 28.5465 40.076 28.8441 39.6491C29.1418 39.2222 29.3517 38.7405 29.4616 38.2319C29.5716 37.7233 29.5794 37.1979 29.4847 36.6862C29.39 36.1745 29.1946 35.6867 28.9099 35.2511L19.444 20.6753C19.3136 20.4741 19.1652 20.2851 19.0006 20.1106L28.4535 5.23438L51.7153 41.8342C52.2068 42.5754 52.505 43.4279 52.5827 44.3138C52.6604 45.1998 52.5151 46.0911 52.1602 46.9066C51.743 47.8277 51.0696 48.6092 50.2204 49.1581C49.3712 49.7069 48.382 49.9997 47.3709 50.0017H-0.00195312L14.402 27.3407Z"/>
  <path d="M38 4 L61.6 47.9" stroke="#E1141E" stroke-width="7.4" stroke-linecap="round" fill="none"/>
</svg>
''';

class BrandMark extends StatelessWidget {
  final double size;

  /// Qorong'i fonda oq, yorug' fonda to'q ko'k shakl
  final bool onDark;
  const BrandMark({super.key, this.size = 56, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final dark = onDark || Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.string(
      brandLogoSvg(shapeColor: dark ? '#FFFFFF' : '#141B4D'),
      width: size,
      height: size * 0.74,
      fit: BoxFit.contain,
    );
  }
}

/// Brend rangidagi gradientli sarlavha maydoni
class BrandPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const BrandPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 20, 18, 20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: Brand.brandGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Brand.navy.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Brend gradientli asosiy tugma
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool done;
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    final disabled = onPressed == null;

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Ink(
            height: 58,
            decoration: BoxDecoration(
              gradient: done ? null : Brand.brandGradient,
              color: done ? tone.sunken : null,
              borderRadius: BorderRadius.circular(16),
              border: done ? Border.all(color: tone.border, width: 1.4) : null,
              boxShadow: (disabled || done)
                  ? null
                  : [
                      BoxShadow(
                        color: Brand.navy.withValues(alpha: 0.30),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ],
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (done)
                    const Icon(Icons.check_circle, color: Brand.green, size: 20)
                  else if (icon != null)
                    Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 9),
                  Text(
                    label,
                    style: TextStyle(
                      color: done ? tone.muted : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Holat belgisi
class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const StatusPill(this.text, {super.key, this.color = Brand.green, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(text,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
