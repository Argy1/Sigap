import 'package:flutter/material.dart';

import '../theme/dispatch_colors.dart';
import '../theme/dispatch_theme.dart';
import '../theme/dispatch_typography.dart';

class NavDestination {
  const NavDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Bilah navigasi bawah — kartu melayang, bukan BottomNavigationBar Material.
///
/// Mockup menggambarkannya sebagai panel dengan radius 16 yang mengambang di
/// atas latar, dengan margin 14 di ketiga sisinya. BottomNavigationBar bawaan
/// menempel penuh ke tepi layar dan tidak bisa dibuat seperti ini tanpa
/// melawan komponennya.
class DispatchNavBar extends StatelessWidget {
  const DispatchNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      decoration: BoxDecoration(
        color: c.isDark ? c.surface : Colors.white,
        borderRadius: BorderRadius.circular(DispatchRadii.navbar),
        border: Border.all(color: c.surfaceBorder),
        boxShadow: c.isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0x0D0A140F),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < destinations.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        destinations[i].icon,
                        size: 16,
                        color: i == currentIndex ? c.vital : c.textTertiary,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        destinations[i].label.toUpperCase(),
                        style: DispatchType.monoStyle(
                          size: 7,
                          weight: 700,
                          tracking: 0.02,
                          color: i == currentIndex ? c.vital : c.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Latar layar bergaya konsol: warna dasar + dua sorotan radial + garis pindai.
/// Ini yang memberi kedalaman pada setiap layar di mockup.
class ConsoleBackground extends StatelessWidget {
  const ConsoleBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.ink,
        gradient: RadialGradient(
          center: const Alignment(-0.5, -1.2),
          radius: 1.1,
          colors: [
            c.vital.withValues(alpha: c.isDark ? 0.09 : 0.06),
            c.ink.withValues(alpha: 0),
          ],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(1.2, -1.0),
            radius: 0.9,
            colors: [
              DispatchColors.sirenRaw.withValues(alpha: c.isDark ? 0.07 : 0.05),
              c.ink.withValues(alpha: 0),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}
