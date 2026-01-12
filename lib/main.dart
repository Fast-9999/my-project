// File: lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Thêm cái này để đọc data
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import các màn hình
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_screen.dart'; // <--- Nhớ import màn hình Admin

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Khởi tạo Firebase
  await Firebase.initializeApp();

  // 2. Khóa màn hình dọc
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DevNet Lingo',

      // 3. CẤU HÌNH THEME (Giữ nguyên của bạn)
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.cyanAccent,
        scaffoldBackgroundColor: const Color(0xFF131F24),
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.amber,
          surface: Color(0xFF1B252D),
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),

      // --- LOGIC PHÂN QUYỀN MỚI ---
      home: const AuthWrapper(),
    );
  }
}

// --- WIDGET ĐIỀU HƯỚNG THÔNG MINH ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // 1. Lắng nghe trạng thái đăng nhập (Auth)
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // Đang chờ kết nối Auth...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)));
        }

        // Nếu CHƯA đăng nhập -> Về màn hình Login
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // Nếu ĐÃ đăng nhập -> Lấy thông tin User hiện tại
        User user = snapshot.data!;

        // 2. Dùng FutureBuilder để lấy Role từ Firestore
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userSnapshot) {

            // Đang tải dữ liệu từ Firestore... (Hiện màn hình chờ màu tối cho đỡ chói)
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF131F24),
                body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
              );
            }

            // Có dữ liệu -> Kiểm tra Role
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              Map<String, dynamic>? data = userSnapshot.data!.data() as Map<String, dynamic>?;
              String role = data?['role'] ?? 'user';

              // QUAN TRỌNG: Check role admin
              if (role == 'admin') {
                return const AdminScreen(); // --> Mời Sếp vào
              } else {
                return const HomeScreen();  // --> Mời Học viên vào
              }
            }

            // Trường hợp user đã đăng nhập Auth nhưng chưa có data trong Firestore (Lỗi hiếm gặp)
            // Cho về Home mặc định cho an toàn
            return const HomeScreen();
          },
        );
      },
    );
  }
}