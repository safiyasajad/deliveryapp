import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class LoginPortalPage extends StatefulWidget {
  const LoginPortalPage({super.key});

  @override
  State<LoginPortalPage> createState() => _LoginPortalPageState();
}

class _LoginPortalPageState extends State<LoginPortalPage> {
  // These controllers let us read what the user typed in the email and
  // password text fields when the LOGIN button is pressed.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // UI state for the password field and login button.
  // _obscurePassword controls whether the password is hidden.
  // _isLoggingIn prevents duplicate requests while one login request is active.
  bool _obscurePassword = true;
  bool _isLoggingIn = false;

  @override
  void dispose() {
    // Controllers hold resources, so dispose them when this page is removed
    // from the widget tree.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    // Rebuild the page after changing the value so the password field and eye
    // icon update immediately.
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _login() async {
    // Read the user's input. Email is trimmed because accidental spaces before
    // or after an email address should not affect login.
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Basic frontend validation before sending anything to the API.
    // The backend will still validate again, but this gives faster feedback.
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.');
      return;
    }

    // Read the public backend base URL from .env.
    // Current value: https://qa-api.orderx.online
    // The full login endpoint becomes: {API_BASE_URL}/login.
    final apiBaseUrl = dotenv.env['API_BASE_URL'];
    if (apiBaseUrl == null || apiBaseUrl.isEmpty) {
      _showMessage('API base URL is missing from .env.');
      return;
    }

    // Show a loading spinner and disable the button while the request is being
    // processed, so the user cannot submit multiple login attempts at once.
    setState(() {
      _isLoggingIn = true;
    });

    try {
      // Send the login request to the backend API.
      // The backend expects a JSON body with email and password fields.
      final response = await http.post(
        Uri.parse('$apiBaseUrl/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      // Convert the API response body from JSON text into a Dart Map so we can
      // read fields like message, error, accessToken, refreshToken, and user.
      final responseBody = _decodeResponseBody(response.body);

      // Any 2xx status code means the request succeeded.
      // Right now we show a message only. Later, this is where you can save
      // responseBody['accessToken'] and navigate to the delivery dashboard.
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showMessage(responseBody['message'] as String? ?? 'Login successful.');
        return;
      }

      // If the backend rejects the login, show the backend's message when it is
      // available. Otherwise show a general login failure message.
      _showMessage(
        responseBody['message'] as String? ??
            responseBody['error'] as String? ??
            'Login failed. Please check your details.',
      );
    } catch (_) {
      // This catches network problems, invalid JSON responses, or unreachable
      // API server errors and keeps the app from crashing.
      _showMessage('Could not connect to the OrderX API.');
    } finally {
      // Turn off the loading state after the request finishes.
      // mounted protects against updating UI after the page has been removed.
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    // Do nothing if the page is no longer visible.
    if (!mounted) return;

    // SnackBar is used for short feedback messages such as login success,
    // missing fields, invalid credentials, or connection errors.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, dynamic> _decodeResponseBody(String body) {
    // Some server errors can return an empty body. Returning an empty map lets
    // the login code fall back to a friendly default message.
    if (body.isEmpty) return const {};

    // Login APIs normally return a JSON object. If the response is valid JSON
    // but not an object, return an empty map to keep response handling simple.
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }

  @override
  Widget build(BuildContext context) {
    // Colors used by this screen. Keeping them here makes the design easy to
    // adjust later without hunting through every widget.
    const navy = Color(0xFF06376F);
    const labelColor = Color(0xFF3B4048);

    // Gives the logo more breathing room on taller screens, but keeps the form
    // reachable on shorter screens or when the keyboard is open.
    final topPadding = MediaQuery.sizeOf(context).height >= 760 ? 170.0 : 72.0;

    return Scaffold(
      // Full page background color for the login screen.
      backgroundColor: const Color(0xFFFDFCFB),
      body: SafeArea(
        // SafeArea keeps the content away from the status bar, notches,
        // and bottom system gesture areas.
        child: Center(
          // Prevents the form from becoming too wide on tablets or desktop.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              // Allows the content to scroll instead of overflowing on smaller
              // screens or when the keyboard opens.
              padding: EdgeInsets.fromLTRB(28, topPadding, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top brand area: logo, app name, and portal subtitle.
                  const Center(child: OrderXLogo()),
                  const SizedBox(height: 22),
                  const Text(
                    'OrderX',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: navy,
                      fontSize: 31,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'DELIVERY TEAM PORTAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Email input section. The controller is connected to the
                  // TextField so _login() can read the typed email.
                  const _FieldLabel('EMAIL'),
                  const SizedBox(height: 8),
                  _PortalTextField(
                    controller: _emailController,
                    hintText: 'Enter email',
                    prefixIcon: Icons.person_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 28),

                  // Password input section. The suffix eye icon toggles between
                  // hidden and visible password text.
                  const _FieldLabel('PASSWORD'),
                  const SizedBox(height: 8),
                  _PortalTextField(
                    controller: _passwordController,
                    hintText: 'Password',
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      onPressed: _togglePasswordVisibility,
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 46),

                  // Login action section. When _isLoggingIn is true, the button
                  // is disabled and shows a loading spinner.
                  SizedBox(
                    height: 58,
                    child: FilledButton(
                      onPressed: _isLoggingIn ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoggingIn
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.6,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .8,
                                  ),
                                ),
                                SizedBox(width: 14),
                                Icon(Icons.arrow_forward, size: 30),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OrderXLogo extends StatelessWidget {
  const OrderXLogo({super.key});

  @override
  Widget build(BuildContext context) {
    // The logo is drawn in Flutter instead of loaded as an image asset.
    // The container creates the blue rounded square background.
    return Container(
      width: 145,
      height: 145,
      decoration: BoxDecoration(
        color: const Color(0xFF0D427C),
        borderRadius: BorderRadius.circular(26),
      ),
      // CustomPaint draws the white mark inside the square.
      child: CustomPaint(painter: _OrderMarkPainter()),
    );
  }
}

class _OrderMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Canvas uses the current logo size, so these calculations keep the mark
    // proportional if the logo dimensions change later.
    final center = Offset(size.width / 2, size.height / 2);

    // Paint used for the two diagonal strokes that create the X shape.
    final spokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;

    // Paint used for the small center ring.
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;

    // Start and end points are percentages of the box width, keeping the mark
    // padded inside the rounded square.
    final spokeStart = size.width * .29;
    final spokeEnd = size.width * .71;

    // Draw the two diagonal strokes first, then draw the ring on top.
    canvas
      ..drawLine(
        Offset(spokeStart, spokeStart),
        Offset(spokeEnd, spokeEnd),
        spokePaint,
      )
      ..drawLine(
        Offset(spokeEnd, spokeStart),
        Offset(spokeStart, spokeEnd),
        spokePaint,
      )
      ..drawCircle(center, size.width * .19, ringPaint);
  }

  @override
  // The logo geometry and colors are fixed, so Flutter does not need to repaint
  // this custom painter unless the painter object itself changes.
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    // Shared label styling for EMAIL and PASSWORD.
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF3B4048),
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    );
  }
}

class _PortalTextField extends StatelessWidget {
  const _PortalTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    const iconColor = Color(0xFF7D848C);

    // Reusable text field for both email and password.
    // The passed-in controller connects the field to the page state.
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(
        color: Color(0xFF4F5660),
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFF727982),
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(prefixIcon, color: iconColor, size: 28),
        // The password field passes an eye IconButton here. The email field
        // passes null, so no suffix icon is shown there.
        suffixIcon: suffixIcon == null
            ? null
            : IconTheme(
                data: const IconThemeData(color: iconColor, size: 26),
                child: suffixIcon!,
              ),
        filled: true,
        fillColor: Colors.white,
        // Padding controls the field height and keeps text/icons aligned.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        // Border used when the field is not focused.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD5D9DF)),
        ),
        // Border used when the user taps into the field.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0D427C), width: 1.4),
        ),
      ),
    );
  }
}
