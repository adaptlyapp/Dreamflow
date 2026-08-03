import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:wellspring/models/user.dart';
import 'package:wellspring/services/user_service.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  Future<void> loadUser() async {
    if (_isLoading) return;
    _isLoading = true;
    // Avoid notifying during build; schedule the initial loading notify post-frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isLoading) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('UserProvider.loadUser initial notify error: $e');
        }
      }
    });

    try {
      final fetchedUser = await _userService.getCurrentUser();
      if (fetchedUser != null) {
        try {
          final isCompleted = await _userService.isOnboardingCompleted();
          if (isCompleted && !fetchedUser.onboardingCompleted) {
            final patched = fetchedUser.copyWith(onboardingCompleted: true);
            try {
              await _userService.saveUser(patched);
            } catch (saveError) {
              debugPrint('UserProvider.loadUser save sync error: $saveError');
            }
            _currentUser = patched;
          } else {
            _currentUser = fetchedUser;
          }
        } catch (e) {
          debugPrint('UserProvider.loadUser onboarding sync error: $e');
          _currentUser = fetchedUser;
        }
      } else {
        _currentUser = null;
      }
    } catch (e) {
      debugPrint('UserProvider.loadUser error: $e');
      _currentUser = null;
    } finally {
      _isLoading = false;
      try {
        notifyListeners();
      } catch (e) {
        debugPrint('UserProvider.loadUser final notify error: $e');
      }
    }
  }

  Future<void> updateUser(User user) async {
    await _userService.saveUser(user);
    _currentUser = user;
    notifyListeners();
  }

  Future<void> updateConditions(List<String> conditions) async {
    try {
      // Always persist to backend (even if `_currentUser` isn't loaded yet).
      await _userService.updateConditions(conditions);

      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(conditions: conditions);
      } else {
        // If provider wasn't initialized, refresh from backend so UI can reflect changes.
        _currentUser = await _userService.getCurrentUser();
      }
      notifyListeners();
    } on AuthException catch (e) {
      debugPrint('UserProvider.updateConditions auth error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('UserProvider.updateConditions error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    await _userService.logout();
    _currentUser = null;
    notifyListeners();
  }
}
