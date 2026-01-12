// File: lib/screens/leaderboard_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // 1. HEADER
            Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 80),
                Positioned(
                  top: 0,
                  child: Icon(Icons.star, color: Colors.white.withOpacity(0.8), size: 20),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text("Bảng Phong Thần", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const Text("Top 50 Phi Hành Gia Xuất Sắc", style: TextStyle(color: Colors.white54, fontSize: 14)),

            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              height: 2,
              decoration: BoxDecoration(
                  color: Colors.cyanAccent,
                  boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 10, spreadRadius: 1)]
              ),
            ),
            const SizedBox(height: 20),

            // 2. DANH SÁCH
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .orderBy('score', descending: true)
                    .limit(60) // Lấy dư một chút để lọc
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));

                  var rawDocs = snapshot.data!.docs;
                  List<QueryDocumentSnapshot> cleanDocs = [];
                  int myRankIndex = -1;
                  Map<String, dynamic>? myData;

                  // --- LOGIC LỌC & TÍNH HẠNG ---
                  for (var doc in rawDocs) {
                    var data = doc.data() as Map<String, dynamic>;

                    // 1. Lọc Admin & User lỗi
                    if (data.containsKey('role') && data['role'] == 'admin') continue;
                    String email = data['email'] ?? "";
                    if (email.isEmpty || email == "Unknown") continue;

                    // 2. Thêm vào danh sách sạch
                    cleanDocs.add(doc);

                    // 3. Kiểm tra xem có phải mình không (Dựa trên vị trí trong list sạch)
                    if (doc.id == currentUid) {
                      myRankIndex = cleanDocs.length; // Hạng chính là số lượng phần tử hiện tại
                      myData = data;
                    }
                  }
                  // -----------------------------

                  // Giới hạn hiển thị 50 người
                  if (cleanDocs.length > 50) cleanDocs = cleanDocs.sublist(0, 50);

                  if (cleanDocs.isEmpty) return const Center(child: Text("Chưa có dữ liệu", style: TextStyle(color: Colors.white)));

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: cleanDocs.length,
                          itemBuilder: (context, index) {
                            var doc = cleanDocs[index];
                            var data = doc.data() as Map<String, dynamic>;
                            return _buildRankItem(context, index, doc, data, currentUid);
                          },
                        ),
                      ),
                      // Thanh rank của tôi (Ghim dưới đáy)
                      if (currentUid != null)
                        _buildMyRankBar(context, myRankIndex, myData, currentUid)
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ITEM TRONG LIST ---
  Widget _buildRankItem(BuildContext context, int index, DocumentSnapshot doc, Map<String, dynamic> data, String? currentUid) {
    String email = data['email'] ?? "Unknown";
    String name = data['displayName'] ?? email.split('@')[0];
    String? photoUrl = data['photoUrl'];
    String frame = data['frame'] ?? 'default';

    if (name.length > 15) name = "${name.substring(0, 12)}...";

    int score = data['score'] ?? 0;
    int streak = data['streak'] ?? 0;
    bool isMe = doc.id == currentUid;

    // Màu sắc Top 1, 2, 3
    Color rankColor = Colors.white54;
    Color borderColor = Colors.transparent;
    List<Color> bgColors = [const Color(0xFF1B252D), const Color(0xFF1B252D)];
    IconData? rankIcon;
    double scale = 1.0;

    if (index == 0) { // TOP 1
      rankColor = const Color(0xFFFFD700);
      borderColor = const Color(0xFFFFD700);
      bgColors = [const Color(0xFF3E3020), const Color(0xFF1B252D)];
      rankIcon = Icons.emoji_events;
      scale = 1.05;
    } else if (index == 1) { // TOP 2
      rankColor = const Color(0xFFC0C0C0);
      borderColor = const Color(0xFFC0C0C0);
      bgColors = [const Color(0xFF2D3033), const Color(0xFF1B252D)];
      rankIcon = Icons.emoji_events;
    } else if (index == 2) { // TOP 3
      rankColor = const Color(0xFFCD7F32);
      borderColor = const Color(0xFFCD7F32);
      bgColors = [const Color(0xFF3A2A25), const Color(0xFF1B252D)];
      rankIcon = Icons.emoji_events;
    }

    if (isMe) {
      borderColor = Colors.cyanAccent;
      bgColors = [const Color(0xFF0F353A), const Color(0xFF131F24)];
    }

    return Transform.scale(
      scale: scale,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor.withOpacity(isMe ? 1 : 0.3), width: isMe ? 2 : 1),
          boxShadow: isMe ? [BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 15, spreadRadius: 1)] : [],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 35,
              child: rankIcon != null
                  ? Icon(rankIcon, color: rankColor, size: 28)
                  : Text("#${index + 1}", style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(width: 8),
            _buildMiniAvatar(photoUrl, name, frame, index == 0),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(color: isMe ? Colors.cyanAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  if (streak > 0)
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 14),
                        Text(" $streak ngày", style: const TextStyle(color: Colors.deepOrange, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    )
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Icon(Icons.star_rounded, color: index < 3 ? rankColor : Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text("$score", style: TextStyle(color: index < 3 ? rankColor : Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- THANH CỦA TÔI ---
  Widget _buildMyRankBar(BuildContext context, int myRankIndex, Map<String, dynamic>? myData, String currentUid) {
    if (myData == null) {
      // Trường hợp chưa load được hoặc không nằm trong Top 60
      return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
            var data = snapshot.data!.data() as Map<String, dynamic>;
            return _buildBottomBarUI(context, -1, data);
          }
      );
    }
    return _buildBottomBarUI(context, myRankIndex, myData);
  }

  Widget _buildBottomBarUI(BuildContext context, int rankIndex, Map<String, dynamic> data) {
    String name = data['displayName'] ?? "Tôi";
    String? photo = data['photoUrl'];
    String frame = data['frame'] ?? 'default';
    int score = data['score'] ?? 0;
    String rankText = rankIndex > 0 ? "#$rankIndex" : "Top 50+";

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      decoration: BoxDecoration(
          color: const Color(0xFF1A2830),
          border: const Border(top: BorderSide(color: Colors.cyanAccent, width: 2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 15, offset: const Offset(0, -5))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildMiniAvatar(photo, name, frame, false),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Thứ hạng của tôi", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(rankText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 5),
                Text("$score XP", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- AVATAR AN TOÀN ---
  Widget _buildMiniAvatar(String? photoUrl, String name, String frame, bool isTop1) {
    bool isGold = frame == 'gold';
    Color borderColor = isGold ? Colors.amber : (isTop1 ? Colors.amber : Colors.white24);
    double borderWidth = (isGold || isTop1) ? 2.5 : 1.5;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: (isGold || isTop1) ? [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 8)] : []
          ),
          child: ClipOval(
            child: SizedBox(
              width: 40, height: 40,
              child: (photoUrl != null && photoUrl.isNotEmpty)
                  ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[800],
                    alignment: Alignment.center,
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  );
                },
              )
                  : Container(
                color: Colors.grey[800],
                alignment: Alignment.center,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
        if (isTop1)
          Positioned(
            top: -12, right: -6,
            child: Transform.rotate(angle: 0.2, child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 22)),
          )
      ],
    );
  }
}