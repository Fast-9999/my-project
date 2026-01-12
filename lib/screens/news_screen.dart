// File: lib/screens/news_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      appBar: AppBar(
        title: const Text("Bản Tin Vũ Trụ 📡", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('news')
            .orderBy('timestamp', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.newspaper_rounded, size: 80, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 10),
                  const Text("Chưa có tin tức nào!", style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }

          var docs = snapshot.data!.docs;

          // Logic: Nếu có tin Featured thì lấy, nếu không thì lấy tin mới nhất làm Featured
          var featuredList = docs.where((doc) => (doc.data() as Map<String, dynamic>)['isFeatured'] == true).toList();
          var featuredDoc = featuredList.isNotEmpty ? featuredList.first : docs.first;
          var normalDocs = docs.where((doc) => doc.id != featuredDoc.id).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildFeaturedSection(context, featuredDoc),
              const SizedBox(height: 25),
              if (normalDocs.isNotEmpty) ...[
                const Text("Tin mới nhất", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                ...normalDocs.map((doc) => _buildNewsItem(context, doc)),
              ]
            ],
          );
        },
      ),
    );
  }

  // --- 1. BANNER TIÊU ĐIỂM ---
  Widget _buildFeaturedSection(BuildContext context, DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    Color color = _getColorByType(data['type'] ?? 'default');
    String imageUrl = data['image'] ?? "";

    return GestureDetector(
      onTap: () => _showNewsDetail(context, data, color),
      child: Container(
        width: double.infinity,
        height: 240,
        clipBehavior: Clip.antiAlias, // Cắt góc bo tròn để ảnh nền không bị tràn ra ngoài
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
              colors: [color, color.withOpacity(0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight
          ),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Stack(
          children: [
            // Background Image (Mờ ảo - Trang trí)
            Positioned(
                right: -30, bottom: -30,
                child: Opacity(
                  opacity: 0.15,
                  child: Transform.rotate(
                    angle: -0.2,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 200, fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const SizedBox(),
                    ),
                  ),
                )
            ),

            // Nội dung chính
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                    child: const Text("🔥 TIÊU ĐIỂM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                  const Spacer(),
                  Text(data['title'] ?? "Tiêu đề", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text(data['subtitle'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Text("Xem ngay", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),

            // Ảnh chính (Thumbnail nhỏ bên phải)
            Positioned(
              right: 15, bottom: 80,
              child: Hero(
                tag: doc.id, // Hiệu ứng chuyển cảnh mượt
                child: Container(
                  decoration: BoxDecoration(
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 90, height: 90, fit: BoxFit.cover,
                      placeholder: (context, url) => const SizedBox(),
                      errorWidget: (context, url, error) => const SizedBox(), // Nếu lỗi thì ẩn đi để hiện nền text thôi
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- 2. ITEM TIN TỨC ---
  Widget _buildNewsItem(BuildContext context, DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    Color color = _getColorByType(data['type'] ?? 'default');
    String timeAgo = _formatTimestamp(data['timestamp']);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF1B252D),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showNewsDetail(context, data, color),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Ảnh Thumbnail (Đã sửa lại BoxFit.cover cho đẹp)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 75, height: 75,
                  color: Colors.black26,
                  child: CachedNetworkImage(
                    imageUrl: data['image'] ?? "",
                    fit: BoxFit.cover, // Lấp đầy khung hình
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)),
                    errorWidget: (context, url, error) => const Icon(Icons.newspaper, color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                          child: Text(data['tag'] ?? "TIN TỨC", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text("• $timeAgo", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(data['title'] ?? "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(data['subtitle'] ?? "", style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 3. CHI TIẾT TIN ---
  void _showNewsDetail(BuildContext context, Map<String, dynamic> data, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85, // Tăng chiều cao lên chút
        decoration: const BoxDecoration(
          color: Color(0xFF131F24),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          border: Border(top: BorderSide(color: Colors.white24, width: 1)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(25),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: CachedNetworkImage(
                      imageUrl: data['image'] ?? "",
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const SizedBox(height: 100, child: Icon(Icons.broken_image, color: Colors.white54, size: 50)),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text(data['tag'] ?? "TIN TỨC", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(data['title'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.3)),
                  const SizedBox(height: 20),
                  Divider(color: Colors.white10),
                  const SizedBox(height: 20),
                  SelectableText(
                    data['content'] != null && data['content'].toString().isNotEmpty
                        ? data['content']
                        : (data['subtitle'] ?? "Nội dung đang cập nhật..."),
                    style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Đóng tin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Color _getColorByType(String type) {
    switch (type) {
      case 'event': return Colors.purpleAccent;
      case 'update': return Colors.greenAccent;
      case 'maintenance': return Colors.redAccent;
      case 'tip': return Colors.orangeAccent;
      case 'focus': return Colors.blueAccent;
      default: return Colors.cyanAccent;
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Vừa xong";
    DateTime date = timestamp.toDate();
    Duration diff = DateTime.now().difference(date);

    if (diff.inDays > 0) {
      if (diff.inDays == 1) return "Hôm qua";
      if (diff.inDays < 7) return "${diff.inDays} ngày trước";
      return "${date.day}/${date.month}/${date.year}";
    }
    if (diff.inHours > 0) return "${diff.inHours} giờ trước";
    if (diff.inMinutes > 0) return "${diff.inMinutes} phút trước";
    return "Vừa xong";
  }
}