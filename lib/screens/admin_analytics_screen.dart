// File: lib/screens/admin_analytics_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  // Các chỉ số thống kê
  int totalUsers = 0;
  int newUsersToday = 0;
  int totalTopics = 0;
  int totalShopItems = 0;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => isLoading = true);
    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Đếm Tổng Users
      var userCountQuery = await firestore.collection('users').count().get();
      totalUsers = userCountQuery.count ?? 0;

      // 2. Đếm User mới hôm nay
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);

      var newUserQuery = await firestore
          .collection('users')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .count()
          .get();
      newUsersToday = newUserQuery.count ?? 0;

      // 3. Đếm Tổng Topics
      var topicCountQuery = await firestore.collection('topics').count().get();
      totalTopics = topicCountQuery.count ?? 0;

      // 4. Đếm Tổng Vật Phẩm trong Shop
      var shopCountQuery = await firestore.collection('shop_items').count().get();
      totalShopItems = shopCountQuery.count ?? 0;

    } catch (e) {
      print("Lỗi thống kê: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      appBar: AppBar(
        title: const Text("Thống kê dữ liệu 📊", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            onPressed: _loadStatistics,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : RefreshIndicator(
        onRefresh: _loadStatistics,
        color: Colors.cyanAccent,
        backgroundColor: const Color(0xFF1B252D),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("TỔNG QUAN", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 15),

              // --- 1. LƯỚI THỐNG KÊ (GRID VIEW) ---
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                // QUAN TRỌNG: Giảm tỉ lệ xuống 1.2 để thẻ cao hơn -> Hết lỗi tràn đáy
                childAspectRatio: 1.2,
                children: [
                  _buildStatCard("Người dùng", "$totalUsers", Icons.people_alt_rounded, Colors.blueAccent),
                  _buildStatCard("Mới hôm nay", "+$newUsersToday", Icons.person_add_alt_1_rounded, Colors.greenAccent),
                  _buildStatCard("Chủ đề học", "$totalTopics", Icons.library_books_rounded, Colors.orangeAccent),
                  _buildStatCard("Vật phẩm Shop", "$totalShopItems", Icons.store_mall_directory_rounded, Colors.purpleAccent),
                ],
              ),

              const SizedBox(height: 30),
              const Text("HOẠT ĐỘNG (DEMO)", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 15),

              // --- 2. BIỂU ĐỒ CỘT ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B252D),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Truy cập 7 ngày qua", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildBar("T2", 40, Colors.cyanAccent),
                        _buildBar("T3", 60, Colors.cyanAccent),
                        _buildBar("T4", 30, Colors.cyanAccent),
                        _buildBar("T5", 80, Colors.amber),
                        _buildBar("T6", 50, Colors.cyanAccent),
                        _buildBar("T7", 90, Colors.greenAccent),
                        _buildBar("CN", 70, Colors.cyanAccent),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Center(child: Text("Biểu đồ đang hiển thị dữ liệu mẫu", style: TextStyle(color: Colors.white24, fontSize: 12, fontStyle: FontStyle.italic))),
            ],
          ),
        ),
      ),
    );
  }

  // Widget cột biểu đồ
  Widget _buildBar(String label, double heightPercent, Color color) {
    return Column(
      children: [
        Container(
          width: 20,
          height: 100 * (heightPercent / 100),
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
              boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 5, spreadRadius: 1)]
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  // Widget Card thống kê (Đã tinh chỉnh để KHÔNG BỊ TRÀN)
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12), // Giảm padding từ 15 -> 12 để tiết kiệm chỗ
      decoration: BoxDecoration(
        color: const Color(0xFF1B252D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon phía trên
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 26), // Giảm size icon chút xíu (32 -> 26)
          ),

          const Spacer(), // Đẩy nội dung text xuống đáy an toàn

          // Số liệu (Dùng FittedBox để tự thu nhỏ nếu số quá to, tránh tràn ngang/dọc)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
            ),
          ),
          const SizedBox(height: 2),
          // Tiêu đề (Giới hạn 1 dòng để an toàn)
          Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis
          ),
        ],
      ),
    );
  }
}