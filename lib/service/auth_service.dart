import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> login(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        await _saveLoginStatus(true);
        return true;
      }
    } catch (e) {
      print(e);
    }
    return false;
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _saveLoginStatus(false);
  }

  Future<void> _saveLoginStatus(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // Tambahkan metode ini untuk memeriksa status login saat aplikasi dimulai
  Future<bool> checkLoginStatus() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _saveLoginStatus(true);
      return true;
    }
    await _saveLoginStatus(false);
    return false;
  }
}
