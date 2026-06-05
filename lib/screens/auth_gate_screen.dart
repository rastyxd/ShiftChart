import 'package:flutter/material.dart';
import 'package:shiftchart/models/audit_entry.dart';
import 'package:shiftchart/screens/main_screen.dart';
import 'package:shiftchart/services/audit_service.dart';
import 'package:shiftchart/services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiftchart/theme/AppColors.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _isAuthenticating = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    setState(() {
      _isAuthenticating = true;
      _failed = false;
    });

    final bool authenticated = await AuthService().authenticate();

    if (authenticated) {
      AuditService.log(AuditAction.appUnlocked, {
        'method': 'Biometrics/Device'
      }, outcome: true);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } else {
      AuditService.log(AuditAction.appUnlocked, {
        'method': 'Biometrics/Device',
        'reason': 'Authentication failed or canceled'
      }, outcome: false);
      setState(() {
        _isAuthenticating = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Access Restricted',
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please authenticate to view sensitive patient records.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 48),
              if (_isAuthenticating)
                const CircularProgressIndicator()
              else if (_failed)
                PrimaryButton(
                  onTap: _checkAuth,
                  label: 'Unlock with Biometrics',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
