// File: lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'admin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // --- HÀM KIỂM TRA ROLE & CHUYỂN HƯỚNG ---
  Future<void> _checkRoleAndRedirect(User user) async {
    try {
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      DocumentSnapshot userDoc = await userRef.get();

      if (userDoc.exists) {
        // --- 1. USER ĐÃ TỒN TẠI ---
        // Cập nhật thông tin mới nhất từ Auth (VD: Avatar, Tên nếu có thay đổi)
        // Chỉ cập nhật các trường info, KHÔNG ghi đè score/hearts
        await userRef.update({
          'email': user.email,
          'displayName': user.displayName ?? user.email!.split('@')[0],
          'photoUrl': user.photoURL,
          'lastLogin': FieldValue.serverTimestamp(), // Thêm thời gian đăng nhập cuối
        });

        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        String role = data?['role']?.toString() ?? 'user';

        if (!mounted) return;
        _navigateBasedOnRole(role);

      } else {
        // --- 2. USER MỚI (Lần đầu tiên) ---
        await userRef.set({
          'email': user.email,
          'displayName': user.displayName ?? user.email!.split('@')[0],
          'photoUrl': user.photoURL,
          'role': 'user',
          'score': 0,
          'streak': 0,
          'hearts': 5,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        _navigateBasedOnRole('user');
      }
    } catch (e) {
      print("Lỗi check role: $e");
      if (mounted) _navigateBasedOnRole('user'); // Fallback an toàn
    }
  }

  void _navigateBasedOnRole(String role) {
    if (role.trim() == 'admin') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AdminScreen()),
            (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF131F24),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. LOGO
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 2),
                      boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)],
                    ),
                    child: const Icon(Icons.rocket_launch_rounded, size: 60, color: Colors.cyanAccent),
                  ),
                  const SizedBox(height: 20),
                  const Text("DevNet Lingo", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _isLogin ? "Chào mừng trở lại phi hành gia! 👨‍🚀" : "Sẵn sàng khởi hành chưa? 🚀",
                      key: ValueKey<bool>(_isLogin),
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 2. INPUT FIELDS
                  _buildTextField(
                      controller: _emailController,
                      label: "Email",
                      icon: Icons.email,
                      inputType: TextInputType.emailAddress,
                      action: TextInputAction.next,
                      validator: (val) => (val == null || !val.contains("@")) ? "Email không hợp lệ" : null
                  ),
                  const SizedBox(height: 15),

                  _buildTextField(
                      controller: _passController,
                      label: "Mật khẩu",
                      icon: Icons.lock,
                      isPassword: true,
                      action: TextInputAction.done,
                      onSubmitted: (_) => _handleAuthAction(),
                      validator: (val) => (val == null || val.length < 6) ? "Mật khẩu phải từ 6 ký tự" : null
                  ),

                  // 3. FORGOT PASSWORD
                  if (_isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _handleForgotPassword,
                        child: const Text("Quên mật khẩu?", style: TextStyle(color: Colors.cyanAccent, fontStyle: FontStyle.italic)),
                      ),
                    )
                  else
                    const SizedBox(height: 20),

                  if (!_isLogin) const SizedBox(height: 10),

                  // 4. MAIN BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: const Color(0xFF131F24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                        shadowColor: Colors.cyanAccent.withOpacity(0.5),
                      ),
                      onPressed: _isLoading ? null : _handleAuthAction,
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
                          : Text(_isLogin ? "ĐĂNG NHẬP NGAY" : "ĐĂNG KÝ TÀI KHOẢN", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 5. SOCIAL LOGIN
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[700])),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("Hoặc tiếp tục với", style: TextStyle(color: Colors.grey))),
                      Expanded(child: Divider(color: Colors.grey[700])),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Center(
                    child: _buildSocialButton(
                      iconUrl: "https://cdn-icons-png.flaticon.com/512/25/25231.png",
                      label: "Đăng nhập bằng GitHub",
                      onTap: _handleGithubSignIn,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 6. TOGGLE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_isLogin ? "Chưa có tài khoản? " : "Đã có tài khoản? ", style: const TextStyle(color: Colors.white70)),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _formKey.currentState?.reset();
                          });
                        },
                        child: Text(
                          _isLogin ? "Đăng ký" : "Đăng nhập",
                          style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationColor: Colors.cyanAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({required String iconUrl, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), offset: const Offset(0, 4), blurRadius: 5)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              iconUrl,
              height: 24,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.code, color: Colors.black), // Fallback nếu ảnh lỗi
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
    TextInputAction action = TextInputAction.done,
    Function(String)? onSubmitted,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: inputType,
        textInputAction: action,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(icon, color: Colors.cyanAccent),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      ),
    );
  }

  Future<void> _handleAuthAction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    String email = _emailController.text.trim();
    String pass = _passController.text.trim();

    User? user;
    try {
      if (_isLogin) {
        user = await _authService.signIn(email, pass);
      } else {
        user = await _authService.signUp(email, pass);
      }

      if (user != null && mounted) {
        await _checkRoleAndRedirect(user);
      } else {
        _showError("Thất bại. Kiểm tra lại thông tin.");
      }
    } catch (e) {
      _showError("Lỗi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGithubSignIn() async {
    setState(() => _isLoading = true);
    try {
      User? user = await _authService.signInWithGitHub();

      if (user != null && mounted) {
        await _checkRoleAndRedirect(user);
      }
    } catch (e) {
      _showError("Lỗi GitHub: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    String email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError("Vui lòng nhập Email hợp lệ!");
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã gửi email khôi phục!"), backgroundColor: Colors.green));
    } catch (e) {
      _showError("Không tìm thấy email này.");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  }
}