import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/router/app_router.dart';
import '../../features/home/home_screen.dart';
import '../../features/focus/focus_screen.dart';
import '../../features/limits/limits_screen.dart';
import '../../features/bedtime/bedtime_screen.dart';
import '../../features/settings/settings_screen.dart';

class NavShell extends StatefulWidget {
  const NavShell({super.key});

  static const _tabs = [
    (Routes.home, Icons.home_rounded, 'Home'),
    (Routes.focus, Icons.track_changes_rounded, 'Focus'),
    (Routes.limits, Icons.grid_view_rounded, 'Limits'),
    (Routes.bedtime, Icons.dark_mode_rounded, 'Bedtime'),
    (Routes.settings, Icons.settings_rounded, 'Settings'),
  ];

  // Exposed so the router can jump pages without an animation (deep links,
  // permission re-checks, etc.).
  static PageController? _pageController;
  static void jumpToPage(int page) {
    _pageController?.jumpToPage(page);
  }

  @override
  State<NavShell> createState() => _NavShellState();
}

class _NavShellState extends State<NavShell> {
  late final PageController _controller;
  double _page = 0;

  static const _screens = [
    HomeScreen(),
    FocusScreen(),
    LimitsScreen(),
    BedtimeScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    NavShell._pageController = _controller;
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    setState(() => _page = _controller.page ?? 0);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    NavShell._pageController = null;
    super.dispose();
  }

  void _goToTab(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final activeIndex = NavShell._tabs.indexWhere((t) => t.$1 == location).clamp(0, 4);

    // Keep the PageView in sync with route changes that didn't come from
    // swiping (e.g. a control tile pushing a detail then coming back).
    if (_controller.hasClients && (_controller.page?.round() ?? 0) != activeIndex) {
      _controller.jumpToPage(activeIndex);
      _page = activeIndex.toDouble();
    }

    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              final route = NavShell._tabs[index].$1;
              if (route != location) context.go(route);
            },
            children: _screens,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _FloatingNavBar(
              tabs: NavShell._tabs,
              page: _page,
              activeIndex: activeIndex,
              onTap: _goToTab,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.tabs,
    required this.page,
    required this.activeIndex,
    required this.onTap,
  });

  final List<(String, IconData, String)> tabs;
  final double page;
  final int activeIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: SizedBox(
        height: 38,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotWidth = constraints.maxWidth / tabs.length;
            // Indicator center tracks the fractional page position — as
            // the user drags, this slides continuously between tabs rather
            // than snapping only on page settle.
            final indicatorCenter = (page + 0.5) * slotWidth;

            return Stack(
              children: [
                // Sliding highlight — positioned by left offset, not
                // aligned to a slot, so it visibly tracks the drag.
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 90),
                  curve: Curves.easeOut,
                  left: indicatorCenter - 32,
                  top: 0,
                  bottom: 0,
                  width: 64,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.homeLime,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(tabs.length, (i) {
                    final (_, icon, label) = tabs[i];
                    final isActive = i == activeIndex;
                    return Expanded(
                      child: _NavItem(
                        icon: icon,
                        label: label,
                        isActive: isActive,
                        onTap: () => onTap(i),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 38,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isActive ? AppColors.bg : AppColors.inkFaint,
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bg,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
