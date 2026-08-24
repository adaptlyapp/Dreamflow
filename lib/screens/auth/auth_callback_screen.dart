import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

class AuthCallbackScreen extends StatefulWidget {
  final Uri uri;

  const AuthCallbackScreen({super.key, required this.uri});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  String _status = 'Processing authentication...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      debugPrint('[AuthCallback] Processing callback: ${widget.uri}');
      
      // Check for errors in query parameters
      final error = widget.uri.queryParameters['error'];
      final errorDescription = widget.uri.queryParameters['error_description'];
      
      if (error != null) {
        setState(() {
          _hasError = true;
          _status = errorDescription ?? 'Authentication failed: $error';
        });
        debugPrint('[AuthCallback] Error in callback: $error - $errorDescription');
        
        // Wait a bit then redirect to sign in
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          context.go('/auth');
        }
        return;
      }

      // Handle OAuth callback
      final code = widget.uri.queryParameters['code'];
      if (code != null) {
        setState(() => _status = 'Completing sign in...');
        
        // The auth state listener in main.dart will handle the redirect
        // once the session is established
        await Future.delayed(const Duration(milliseconds: 1500));
        
        if (mounted) {
          // Let the router's redirect logic handle the next step
          context.go('/');
        }
      } else {
        // No code and no error - invalid callback
        setState(() {
          _hasError = true;
          _status = 'Invalid authentication callback';
        });
        
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          context.go('/auth');
        }
      }
    } catch (e) {
      debugPrint('[AuthCallback] Error processing callback: $e');
      setState(() {
        _hasError = true;
        _status = 'Authentication failed. Please try again.';
      });
      
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        context.go('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_hasError)
              const CircularProgressIndicator()
            else
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
