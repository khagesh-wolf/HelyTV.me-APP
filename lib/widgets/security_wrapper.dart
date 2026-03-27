import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/security_service.dart';

class SecurityWrapper extends StatefulWidget {
  final Widget child;

  const SecurityWrapper({super.key, required this.child});

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper>
    with WidgetsBindingObserver {
  bool _isChecking = true;
  String? _securityViolationMessage;
  Timer? _periodicCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runSecurityCheck();

    // Continuously monitor for VPN/Proxy toggle while app is open
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _runSecurityCheck();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicCheckTimer?.cancel();
    super.dispose();
  }

  // Re-run checks when app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runSecurityCheck();
    }
  }

  Future<void> _runSecurityCheck() async {
    final violation = await SecurityService.checkNetworkSecurity();

    if (mounted) {
      setState(() {
        _securityViolationMessage = violation;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }

    if (_securityViolationMessage != null) {
      // Block the UI and show a warning
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security_update_warning_rounded,
                    color: Colors.redAccent, size: 80),
                const SizedBox(height: 24),
                const Text(
                  "Network Security Alert",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  _securityViolationMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                  onPressed: () {
                    setState(() => _isChecking = true);
                    _runSecurityCheck();
                  },
                  child: const Text('I have disabled it, Retry',
                      style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: const Text('Exit App',
                      style: TextStyle(color: Colors.grey)),
                )
              ],
            ),
          ),
        ),
      );
    }

    // If safe, show the normal app
    return widget.child;
  }
}
