import 'package:flutter/material.dart';

class LoginPortalPage extends StatefulWidget {
  const LoginPortalPage({super.key});

  @override
  State<LoginPortalPage> createState() => _LoginPortalPageState();
}

class _LoginPortalPageState extends State<LoginPortalPage> {
  // Controls whether the password field shows real text or hidden dots.
  // This value changes when the eye icon is pressed.
  bool _obscurePassword = true;

  void _togglePasswordVisibility() {
    // setState tells Flutter to rebuild this widget after changing the value,
    // so the password field and eye icon update immediately on the screen.
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Colors are kept as constants here so the full screen uses the same
    // navy/gray palette as the reference design.
    const navy = Color(0xFF06376F);
    const labelColor = Color(0xFF3B4048);

    // The screenshot has a large top gap on a tall phone screen. On shorter
    // screens, this gap is reduced so the fields and button stay reachable.
    final topPadding = MediaQuery.sizeOf(context).height >= 760 ? 170.0 : 72.0;

    return Scaffold(
      // This is the page background. The earlier version used an outer rounded
      // container, which made the login form look like a separate window.
      backgroundColor: const Color(0xFFFDFCFB),
      body: SafeArea(
        // SafeArea keeps the content away from system UI like the status bar,
        // camera notch, and bottom gesture area.
        child: Center(
          // Keeps the form from becoming too wide on tablets/desktops while
          // still filling normal phone screens.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              // SingleChildScrollView prevents overflow if the keyboard opens
              // or the screen height is smaller than expected.
              padding: EdgeInsets.fromLTRB(28, topPadding, 28, 28),
              child: Column(
                // Stretch makes the input fields and button take the full
                // available width inside the form area.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // This is not an asset image. OrderXLogo draws the blue
                  // rounded square and white symbol using Flutter canvas code.
                  const Center(child: OrderXLogo()),
                  const SizedBox(height: 22),
                  const Text(
                    'OrderX',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: navy,
                      fontSize: 31,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.1,
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

                  // Username input block.
                  const _FieldLabel('USERNAME'),
                  const SizedBox(height: 8),
                  const _PortalTextField(
                    hintText: 'Enter Username',
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 28),

                  // Password input block. The suffix icon calls
                  // _togglePasswordVisibility when tapped.
                  const _FieldLabel('PASSWORD'),
                  const SizedBox(height: 8),
                  _PortalTextField(
                    hintText: '••••••••',
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

                  // Main action button. It is currently visual only; add login
                  // validation or navigation inside onPressed when needed.
                  SizedBox(
                    height: 58,
                    child: FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Row(
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
    // The logo is built with Flutter widgets instead of an image asset:
    // 1. Container creates the navy rounded square.
    // 2. CustomPaint draws the white OrderX-like mark inside the square.
    return Container(
      width: 145,
      height: 145,
      decoration: BoxDecoration(
        color: const Color(0xFF0D427C),
        borderRadius: BorderRadius.circular(26),
      ),
      child: CustomPaint(painter: _OrderMarkPainter()),
    );
  }
}

class _OrderMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Canvas coordinates are based on the size of the logo box. Using
    // percentages keeps the symbol proportional if the logo size changes.
    final center = Offset(size.width / 2, size.height / 2);

    // Paint for the two diagonal white strokes. round caps make the stroke
    // ends look soft like the reference logo.
    final spokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;

    // Paint for the center white ring. PaintingStyle.stroke means only the
    // outline of the circle is drawn, leaving the center blue.
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;

    // Start and end positions for the diagonal strokes. These numbers place
    // the strokes inside the blue square with padding on all sides.
    final spokeStart = size.width * .29;
    final spokeEnd = size.width * .71;

    // Draw the X shape first, then draw the center ring on top of it.
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
  // The mark uses fixed colors and geometry, so Flutter does not need to
  // repaint it unless this painter is replaced with different behavior.
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    // Shared label styling keeps USERNAME and PASSWORD visually consistent.
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
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
  });

  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    const iconColor = Color(0xFF7D848C);

    // Reusable text field used by both username and password. Passing the hint,
    // prefix icon, obscureText, and optional suffix icon lets one widget cover
    // both input styles without duplicating decoration code.
    return TextField(
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
        // The username field has no suffix icon. The password field passes an
        // IconButton here for the show/hide password action.
        suffixIcon: suffixIcon == null
            ? null
            : IconTheme(
                data: const IconThemeData(color: iconColor, size: 26),
                child: suffixIcon!,
              ),
        filled: true,
        fillColor: Colors.white,
        // Padding controls the input height and keeps text/icons vertically
        // aligned like the screenshot.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        // Default border when the input is not focused.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD5D9DF)),
        ),
        // Navy border when the user taps into the field.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0D427C), width: 1.4),
        ),
      ),
    );
  }
}
