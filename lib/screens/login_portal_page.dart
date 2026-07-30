// Login portal screen.
//
// This is the first screen in the delivery app. It authenticates the delivery
// user against the backend, loads the signed-in user's display name, and then
// opens DeliveryDashboardPage with the JWT access token.
//
// Network flow:
// 1. POST email/password to /login.
// 2. Extract the returned access token from the response.
// 3. Call /user/personal-info with Authorization: Bearer <token>.
// 4. Navigate to the dashboard when both login and profile loading succeed.
//
// UI flow:
// - The login button shows a loading state while requests are in progress.
// - Errors are shown inside the page instead of navigating away.
// - When the user logs out/back-navigates from the dashboard, the form clears.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../orderx_logo.dart';
import 'delivery_dashboard_page.dart';

// LoginPortalPage is the first screen of the delivery app.
// Its responsibilities are:
// 1. Collect the user's email and password.
// 2. Send those details to the backend /login API.
// 3. Read the access token and user/profile name from the API response.
// 4. Open DeliveryDashboardPage with the user name and token.
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
    // This method is the full login workflow.
    // It starts with local validation, then calls /login, then calls
    // /user/personal-info if an access token is available.

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
        //lets the backend know we are sending JSON and expect JSON in return.
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      // Convert the API response body from JSON text into a Dart Map so we can
      // read fields like message, error, accessToken, refreshToken, and user.
      final responseBody = _decodeResponseBody(response.body);

      // Any 2xx status code means the request succeeded.
      // Later, this is also where you can save responseBody['accessToken'] for
      // customer API requests that require Authorization: Bearer <token>.
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Pull the JWT token out of the login response.
        // The token is needed for protected API calls, such as
        // /user/personal-info and later the customer API.
        final accessToken = _getAccessToken(responseBody);

        // Try to get a display name directly from /login first.
        // Some APIs return user details in the login response, while others
        // only return tokens and require a second profile request.
        final loginResponseName = _getUserDisplayName(responseBody);

        // If /login gives us a generic value like "User", use the email typed
        // into the login form as the fallback. Example:
        // safiya@techorin.net becomes safiya.
        final fallbackName = _isGenericDisplayName(loginResponseName)
            ? _firstNamePart(email)
            : loginResponseName;

        // If there is no token, the app cannot call /user/personal-info.
        // In that case, open the dashboard using the best fallback name.
        // If there is a token, fetch the profile and prefer that name.
        final userName = accessToken.isEmpty
            ? fallbackName
            : await _fetchPersonalInfoUserName(
                apiBaseUrl: apiBaseUrl,
                accessToken: accessToken,
                fallbackName: fallbackName,
              );

        _showMessage(responseBody['message'] as String? ?? 'Login successful.');
        _openDashboard(userName: userName, accessToken: accessToken);
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

  String _getAccessToken(Map<String, dynamic> responseBody) {
    // The live API may return the token directly or inside a data wrapper.
    // This helper checks several common response shapes so the app does not
    // break if the backend response is {token: ...} instead of {accessToken: ...}.
    return _firstStringFromPaths(responseBody, const [
      ['accessToken'],
      ['access_token'],
      ['token'],
      ['jwt'],
      ['data', 'accessToken'],
      ['data', 'access_token'],
      ['data', 'token'],
      ['data', 'jwt'],
      ['data', 'tokens', 'accessToken'],
      ['data', 'tokens', 'access_token'],
      ['result', 'accessToken'],
      ['result', 'access_token'],
      ['result', 'token'],
      ['result', 'jwt'],
      ['result', 'tokens', 'accessToken'],
      ['result', 'tokens', 'access_token'],
      ['tokens', 'accessToken'],
      ['tokens', 'access_token'],
      ['auth', 'accessToken'],
      ['auth', 'access_token'],
      ['session', 'accessToken'],
      ['session', 'access_token'],
    ]);
  }

  String _getUserDisplayName(Map<String, dynamic> responseBody) {
    // Try to read the name from the login response first.
    // If it is not there, the personal-info request can still provide it.
    final user =
        _firstNestedMapFromPaths(responseBody, const [
          ['user'],
          ['data', 'user'],
          ['data'],
        ]) ??
        responseBody;

    return _displayNameFromMap(user, fallback: 'User');
  }

  Future<String> _fetchPersonalInfoUserName({
    required String apiBaseUrl,
    required String accessToken,
    required String fallbackName,
  }) async {
    try {
      // Call the profile endpoint after login.
      // This is where we expect the user's saved name, such as "safiya sa".
      // The Authorization header sends the JWT token returned by /login.
      final response = await http.get(
        Uri.parse('$apiBaseUrl/user/personal-info'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // If the profile endpoint rejects the request, keep the fallback name.
        // This avoids blocking dashboard navigation just because profile fetch
        // failed.
        return fallbackName;
      }

      final personalInfo = _decodeResponseBody(response.body);

      // APIs often wrap the actual object. These are examples this handles:
      // { "data": { "full_name": "safiya sa" } }
      // { "user": { "name": "safiya sa" } }
      // { "result": { "firstName": "safiya" } }
      // Or simply: { "name": "safiya sa" }
      final profile =
          _firstNestedMapFromPaths(personalInfo, const [
            ['data'],
            ['result'],
            ['user'],
            ['profile'],
            ['personalInfo'],
          ]) ??
          personalInfo;

      final personalInfoName = _displayNameFromMap(profile, fallback: '');
      // If the profile endpoint returns a useless name like "User" or an empty
      // string, fall back to the login response/email-derived name instead.
      return _isGenericDisplayName(personalInfoName)
          ? fallbackName
          : personalInfoName;
    } catch (_) {
      return fallbackName;
    }
  }

  String _displayNameFromMap(
    Map<String, dynamic> source, {
    required String fallback,
  }) {
    // Reads a display name from one API object.
    // It checks full-name style fields first, then first-name fields, then email.
    // Every returned value is shortened by _firstNamePart before display.
    final fullName = _firstStringFromKeys(source, const [
      'name',
      'fullName',
      'full_name',
      'displayName',
      'display_name',
    ]);

    if (fullName.isNotEmpty) {
      final displayName = _firstNamePart(fullName);
      if (!_isGenericDisplayName(displayName)) return displayName;
    }

    final firstName = _firstStringFromKeys(source, const [
      'firstName',
      'first_name',
      'firstname',
    ]);
    if (firstName.isNotEmpty) {
      final displayName = _firstNamePart(firstName);
      if (!_isGenericDisplayName(displayName)) return displayName;
    }

    final email = _firstStringFromKeys(source, const ['email']);
    if (email.isNotEmpty) return _firstNamePart(email);

    return fallback;
  }

  String _firstNamePart(String value) {
    // "safiya sa" becomes "safiya", and "safiya@techorin.net" becomes
    // "safiya" for the dashboard greeting.
    final beforeEmailDomain = value.trim().split('@').first.trim();
    final firstWord = beforeEmailDomain.split(RegExp(r'\s+')).first.trim();
    return firstWord.isEmpty ? value.trim() : firstWord;
  }

  bool _isGenericDisplayName(String value) {
    // Treat blank values and "User" as not useful.
    // This prevents the dashboard from showing "Hello, User" when we can use
    // the email prefix instead.
    final normalizedValue = value.trim().toLowerCase();
    return normalizedValue.isEmpty || normalizedValue == 'user';
  }

  Map<String, dynamic>? _firstNestedMapFromPaths(
    Map<String, dynamic> source,
    List<List<String>> paths,
  ) {
    // Looks for the first Map object at one of the requested paths.
    // Example path ['data', 'user'] reads source['data']['user'].
    for (final path in paths) {
      final value = _valueAtPath(source, path);
      if (value is Map<String, dynamic>) return value;
    }

    return null;
  }

  String _firstStringFromKeys(Map<String, dynamic> source, List<String> keys) {
    // Reads the first non-empty string from a flat object.
    // Example: try name, then fullName, then full_name.
    for (final key in keys) {
      final value = (source[key] as String? ?? '').trim();
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  String _firstStringFromPaths(
    Map<String, dynamic> source,
    List<List<String>> paths,
  ) {
    // Reads the first non-empty string from nested paths.
    // This is mainly used for tokens that may be nested under data/auth/session.
    for (final path in paths) {
      final value = (_valueAtPath(source, path) as String? ?? '').trim();
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  Object? _valueAtPath(Map<String, dynamic> source, List<String> path) {
    // Walk through a nested JSON map safely.
    // If any part of the path is missing or is not a map, return null.
    Object? current = source;

    for (final key in path) {
      if (current is! Map<String, dynamic>) return null;
      current = current[key];
    }

    return current;
  }

  Future<void> _openDashboard({
    required String userName,
    required String accessToken,
  }) async {
    if (!mounted) return;
    final displayName = userName.trim().isEmpty ? 'User' : userName.trim();

    // Open the dashboard after successful login.
    // The dashboard logout icon pops this route and returns to the login page.
    // Because this await waits until the dashboard closes, we can clear the
    // login form immediately after logout/back navigation.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => DeliveryDashboardPage(
          userName: displayName,
          accessToken: accessToken,
        ),
      ),
    );

    _clearLoginForm();
  }

  void _clearLoginForm() {
    if (!mounted) return;

    // Clear login details after logout/back navigation so the next session
    // starts with a blank email and password form.
    setState(() {
      _emailController.clear();
      _passwordController.clear();
      _obscurePassword = true;
    });
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
