import 'package:flutter/material.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_background.dart';
import 'widgets/auth_slide_route.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeSelectionScreen extends StatefulWidget {
  const WelcomeSelectionScreen({super.key});

  @override
  State<WelcomeSelectionScreen> createState() => _WelcomeSelectionScreenState();
}

class _WelcomeSelectionScreenState extends State<WelcomeSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _entranceAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    Navigator.push(
      context,
      createAuthSlideRoute(const CitizenLoginScreen()),
    );
  }

  void _onSignupPressed() {
    Navigator.push(
      context,
      createAuthSlideRoute(const CitizenSignupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF133838), // Dark Forest Teal
      body: Stack(
        children: [
          // Full-screen continuous green doodle background
          const AuthBackground(),

          SafeArea(
            child: Column(
              children: [
                // Teal Top Area with centered UNISAFE
            const Expanded(
              child: AuthHeader(
                title: 'UNISAFE',
                isCentered: true,
                showBackButton: false,
              ),
            ),

            // White Card Content Area:
            // Animates up into view upon arrival, and moves up when Login/Signup is clicked!
            AnimatedBuilder(
              animation: Listenable.merge([
                _entranceAnimation,
                ModalRoute.of(context)?.secondaryAnimation ?? const AlwaysStoppedAnimation(0.0),
              ]),
              builder: (context, child) {
                // Entrance progress: 0 -> 1
                final double entranceVal = _entranceAnimation.value;
                final double entranceDy = (1.0 - entranceVal) * 160.0;

                // Secondary animation (when Login/Signup route is pushed on top): 0 -> 1
                final secAnim = ModalRoute.of(context)?.secondaryAnimation;
                final double secVal = secAnim != null
                    ? Curves.easeOutCubic.transform(secAnim.value)
                    : 0.0;
                final double secDy = -secVal * 50.0; // Moves upward gently as route opens
                final double secOpacity = (1.0 - secVal * 1.5).clamp(0.0, 1.0);

                return Transform.translate(
                  offset: Offset(0, entranceDy + secDy),
                  child: Opacity(
                    opacity: (entranceVal * secOpacity).clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Log In Button
                            Container(
                              width: double.infinity,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF133838), Color(0xFF1C4D4D)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(27),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF133838).withValues(alpha: 0.28),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(27),
                                  onTap: _onLoginPressed,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 20),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.login_rounded, color: Colors.white, size: 21),
                                        SizedBox(width: 10),
                                        Text(
                                          'Log In',
                                          style: TextStyle(
                                            fontSize: 17.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Create Account Button
                            Container(
                              width: double.infinity,
                              height: 54,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(27),
                                border: Border.all(
                                  color: const Color(0xFF133838),
                                  width: 1.6,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(27),
                                  onTap: _onSignupPressed,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 20),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.person_add_outlined, color: Color(0xFF133838), size: 21),
                                        SizedBox(width: 10),
                                        Text(
                                          'Create Account',
                                          style: TextStyle(
                                            fontSize: 17.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF133838),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
