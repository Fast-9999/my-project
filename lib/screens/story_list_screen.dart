// File: lib/screens/story_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'story_player_screen.dart';

class StoryListScreen extends StatelessWidget {
  const StoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      appBar: AppBar(
        title: const Text("Kho Truyện Chêm 📚", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('stories').orderBy('level').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_stories_rounded, size: 80, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 10),
                  const Text("Chưa có truyện nào", style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }

          var docs = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              // 🔥 FIX 1: Giảm tỉ lệ khung hình xuống 0.68 để thẻ dài hơn
              // Giúp nội dung không bị tràn đáy (Overflow)
              childAspectRatio: 0.68,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              return _buildStoryCard(context, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildStoryCard(BuildContext context, Map<String, dynamic> data) {
    String imageUrl = data['image'] ?? "";
    String title = data['title'] ?? "Truyện";
    int level = data['level'] ?? 1;
    List content = data['content'] ?? [];

    return GestureDetector(
      onTap: () {
        if (content.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Truyện này đang được biên soạn! ✍️"), backgroundColor: Colors.orange),
          );
          return;
        }

        Navigator.push(context, MaterialPageRoute(
            builder: (context) => StoryPlayerScreen(
              storyTitle: title,
              content: content,
            )
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2D3033),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. ẢNH BÌA
            Expanded(
              flex: 5, // 🔥 FIX 2: Tăng không gian ảnh lên chút
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: imageUrl.isNotEmpty
                    ? Hero(
                  tag: title,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[800], child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                    errorWidget: (context, url, error) => Container(color: Colors.teal, child: const Icon(Icons.broken_image, color: Colors.white)),
                  ),
                )
                    : Container(color: Colors.teal, child: const Icon(Icons.menu_book, size: 40, color: Colors.white)),
              ),
            ),

            // 2. THÔNG TIN
            Expanded(
              flex: 4, // 🔥 FIX 2: Cân đối lại phần chữ (Ảnh 5 phần, Chữ 4 phần)
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Tự động đẩy Level xuống đáy
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Badge Level
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getLevelColor(level).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _getLevelColor(level).withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.signal_cellular_alt, color: _getLevelColor(level), size: 14),
                          const SizedBox(width: 4),
                          Text(
                              "Level $level",
                              style: TextStyle(color: _getLevelColor(level), fontSize: 12, fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(int level) {
    if (level <= 2) return Colors.greenAccent;
    if (level <= 5) return Colors.amber;
    return Colors.redAccent;
  }
}