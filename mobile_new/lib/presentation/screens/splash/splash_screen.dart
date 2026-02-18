import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import '../../providers/auth_provider.dart';

/// Splash screen with Lottie animation and branding
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _textController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // Start text animation after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _textController.forward();
    });

    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // Wait for animations to complete
    await Future.delayed(const Duration(milliseconds: 5000));

    if (!mounted) return;

    // Initialize auth state - restores session from secure storage if exists
    await ref.read(authStateProvider.notifier).initialize();

    if (!mounted) return;

    // Mark app as initialized BEFORE navigating
    ref.read(appInitializedProvider.notifier).state = true;

    // Check auth state and navigate accordingly
    final authState = ref.read(authStateProvider);
    if (authState.isLoggedIn && authState.user != null) {
      context.go(authState.user!.role.homeRoute);
    } else {
      context.go(RoutePaths.login);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Lottie animation - takes upper portion
            Expanded(
              flex: 3,
              child: Center(
                child: Lottie.asset(
                  'assets/animations/maintenance.json',
                  width: MediaQuery.of(context).size.width * 0.85,
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
            ),
            // Text content - lower portion
            Expanded(
              flex: 2,
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Main title
                      Text(
                        'app.name'.tr(),
                        style: context.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Tagline
                      Text(
                        'splash.tagline'.tr(),
                        textAlign: TextAlign.center,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Subtitle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'splash.subtitle'.tr(),
                          textAlign: TextAlign.center,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Loading dots
                      _LoadingDots(color: context.colors.primary),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated loading dots
class _LoadingDots extends StatefulWidget {
  final Color color;

  const _LoadingDots({required this.color});

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final animation = Tween<double>(begin: 0.3, end: 1.0).animate(
              CurvedAnimation(
                parent: _controller,
                curve: Interval(
                  delay,
                  delay + 0.5,
                  curve: Curves.easeInOut,
                ),
              ),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: animation.value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
