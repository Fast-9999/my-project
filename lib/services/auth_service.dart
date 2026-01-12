// File: lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart'; // Import để lưu thông tin user

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _dbService = DatabaseService();

  // 1. ĐĂNG KÝ (SignUp) - Giữ nguyên
  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password
      );
      User? user = result.user;

      if (user != null) {
        await _dbService.saveUserData(user.uid, email);
      }
      return user;
    } catch (e) {
      print("Lỗi Đăng ký: $e");
      return null;
    }
  }

  // 2. ĐĂNG NHẬP (SignIn) - Giữ nguyên
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password
      );
      return result.user;
    } catch (e) {
      print("Lỗi Đăng nhập: $e");
      return null;
    }
  }

  // 3. ĐĂNG NHẬP GITHUB (MỚI) 🐙
  Future<User?> signInWithGitHub() async {
    try {
      // Tạo Provider GitHub
      GithubAuthProvider githubProvider = GithubAuthProvider();

      // Dòng này sẽ mở cửa sổ trình duyệt để xác thực (Hỗ trợ cả Android/iOS/Web)
      UserCredential result = await _auth.signInWithProvider(githubProvider);
      User? user = result.user;

      if (user != null) {
        // Lưu thông tin vào Database
        // Lưu ý: GitHub có thể ẩn email, nên ta dùng fallback nếu email null
        String email = user.email ?? "${user.uid}@github.com";

        // Lưu uid và email vào Firestore
        await _dbService.saveUserData(user.uid, email);
      }
      return user;
    } catch (e) {
      print("Lỗi GitHub Sign-In: $e");
      return null;
    }
  }

  // 4. ĐĂNG XUẤT (SignOut)
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Lấy người dùng hiện tại
  User? get currentUser => _auth.currentUser;
}