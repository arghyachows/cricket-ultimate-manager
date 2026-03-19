import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/theme.dart';

class ShellScreen extends StatefulWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _currentIndex = 0;

  static const _routes = [
    AppConstants.dashboardRoute,
    AppConstants.collectionRoute,
    AppConstants.squadBuilderRoute,
    AppConstants.matchRoute,
    AppConstants.marketRoute,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.5),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              selectedItemColor: AppTheme.accent,
              unselectedItemColor: Colors.white54,
              selectedFontSize: 12,
              unselectedFontSize: 11,
              elevation: 0,
              onTap: (index) {
                setState(() => _currentIndex = index);
                context.go(_routes[index]);
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.style_rounded),
                  label: 'Cards',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.groups_rounded),
                  label: 'Squad',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.sports_cricket_rounded),
                  label: 'Play',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.storefront_rounded),
                  label: 'Market',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
