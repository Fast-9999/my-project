// File: lib/screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'admin_topics_screen.dart';
import 'admin_users_screen.dart';
import 'admin_shop_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_stories_screen.dart';
import 'admin_news_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D3033),
        title: const Text("Đăng xuất?", style: TextStyle(color: Colors.white)),
        content: const Text("Bạn có chắc muốn thoát khỏi quyền Admin?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              }
            },
            child: const Text("Đăng xuất", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? admin = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      appBar: AppBar(
        title: const Text("Admin Dashboard 🛡️", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: "Đăng xuất",
            onPressed: () => _confirmSignOut(context),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Admin
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.redAccent,
                    child: Icon(Icons.admin_panel_settings_rounded, size: 35, color: Colors.white),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Xin chào, Sếp! 👋", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text(admin?.email ?? "admin@lingo.app", style: const TextStyle(color: Colors.cyanAccent, fontSize: 14)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 2. Menu Grid
            const Text("QUẢN TRỊ HỆ THỐNG", style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 15),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              // Tinh chỉnh tỷ lệ để card cao hơn, thoáng hơn, tránh tràn chữ
              childAspectRatio: 1.0,
              children: [
                _buildMenuCard(
                  context,
                  title: "Chủ đề & Câu hỏi",
                  icon: Icons.library_books_rounded,
                  color: Colors.orange,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTopicsScreen())),
                ),
                _buildMenuCard(
                  context,
                  title: "Người dùng",
                  icon: Icons.people_alt_rounded,
                  color: Colors.blue,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
                ),
                _buildMenuCard(
                  context,
                  title: "Kho Truyện",
                  icon: Icons.auto_stories_rounded,
                  color: Colors.pinkAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminStoriesScreen())),
                ),
                _buildMenuCard(
                  context,
                  title: "Bản Tin",
                  icon: Icons.newspaper_rounded,
                  color: Colors.tealAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminNewsScreen())),
                ),
                _buildMenuCard(
                  context,
                  title: "Cửa hàng",
                  icon: Icons.store_mall_directory_rounded,
                  color: Colors.purple,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminShopScreen())),
                ),
                _buildMenuCard(
                  context,
                  title: "Thống kê",
                  icon: Icons.bar_chart_rounded,
                  color: Colors.green,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {required String title, required IconData icon, required Color color, int badgeCount = 0, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFF1B252D),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: color.withOpacity(0.2),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 15),
              // Thêm padding cho text để không bị sát lề
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                    title,
                    textAlign: TextAlign.center, // Căn giữa text
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}