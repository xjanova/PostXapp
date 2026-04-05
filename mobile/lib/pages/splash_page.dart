import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';

class SplashPage extends StatefulWidget {
  final VoidCallback onDone;

  const SplashPage({super.key, required this.onDone});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _init();
  }

  Future<void> _init() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = 'v${info.version}');

    // Show splash for at least 2 seconds
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface950,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.surface800,
                    child: const Icon(Icons.bolt, size: 48, color: AppColors.red),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // App name
              const Text(
                'PostX App',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),

              // Tagline
              Text(
                'Creation & Posting Efficiency',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.surface400,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 20),

              // Version
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _version.isEmpty ? '...' : _version,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.red,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Loading indicator
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.red.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom credit
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'xman studio',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.surface500,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
