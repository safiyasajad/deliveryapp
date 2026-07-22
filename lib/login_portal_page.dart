import 'package:flutter/material.dart';

class LoginPortalPage extends StatefulWidget {
  const LoginPortalPage({super.key});

  @override
  State<LoginPortalPage> createState() => _LoginPortalPageState();
}

class _LoginPortalPageState extends State<LoginPortalPage> {
  bool _obscurePassword = true;

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF06376F);
    const labelColor = Color(0xFF3B4048);
    final topPadding = MediaQuery.sizeOf(context).height >= 760 ? 170.0 : 72.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(28, topPadding, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  const _FieldLabel('USERNAME'),
                  const SizedBox(height: 8),
                  const _PortalTextField(
                    hintText: 'Enter Username',
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 28),
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
    final center = Offset(size.width / 2, size.height / 2);
    final spokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;

    final spokeStart = size.width * .29;
    final spokeEnd = size.width * .71;

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
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
        suffixIcon: suffixIcon == null
            ? null
            : IconTheme(
                data: const IconThemeData(color: iconColor, size: 26),
                child: suffixIcon!,
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD5D9DF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0D427C), width: 1.4),
        ),
      ),
    );
  }
}
