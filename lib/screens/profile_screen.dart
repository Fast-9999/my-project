// File: lib/screens/profile_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      body: SafeArea(
        child: user == null
            ? const Center(child: Text("Vui lòng đăng nhập", style: TextStyle(color: Colors.white)))
            : StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            // 1. Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // 2. Error handling
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return _buildErrorView(context);
            }

            var userData = snapshot.data!.data() as Map<String, dynamic>;

            // --- GET USER DATA ---
            int score = userData['score'] ?? 0;
            int hearts = userData['hearts'] ?? 5;
            int streak = userData['streak'] ?? 0;
            String email = userData['email'] ?? "User";

            String name = userData['displayName'] ?? user.displayName ?? email.split('@')[0];
            String? photoUrl = userData['photoUrl'];
            if (photoUrl == null || photoUrl.isEmpty) {
              photoUrl = user.photoURL;
            }
            String frameType = userData['frame'] ?? 'default';

            // Calculate Level & Progress
            int level = (score / 100).floor() + 1;
            int nextLevelScore = level * 100;
            double progress = (score % 100) / 100;
            if (progress < 0) progress = 0;
            if (progress > 1) progress = 1;

            int vocabCount = (score / 10).floor();

            // 🔥 REAL-TIME RANK CALCULATION 🔥
            // Logic: Rank = (Số người có điểm cao hơn mình) + 1
            return FutureBuilder<AggregateQuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .where('score', isGreaterThan: score)
                    .count()
                    .get(),
                builder: (context, rankSnapshot) {

                  String rankDisplay = "...";
                  Color rankColor = Colors.grey;
                  IconData rankIcon = Icons.leaderboard;

                  if (rankSnapshot.hasData) {
                    int rank = (rankSnapshot.data!.count ?? 0) + 1;
                    rankDisplay = "#$rank";

                    if (rank == 1) {
                      rankDisplay = "Top 1 👑";
                      rankColor = const Color(0xFFFFD700);
                      rankIcon = Icons.emoji_events;
                    } else if (rank == 2) {
                      rankDisplay = "Top 2 🥈";
                      rankColor = const Color(0xFFC0C0C0);
                      rankIcon = Icons.emoji_events;
                    } else if (rank == 3) {
                      rankDisplay = "Top 3 🥉";
                      rankColor = const Color(0xFFCD7F32);
                      rankIcon = Icons.emoji_events;
                    } else {
                      rankColor = Colors.cyanAccent;
                    }
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),

                        // 3. AVATAR
                        _buildAvatarWithFrame(photoUrl, name, frameType),

                        const SizedBox(height: 15),
                        Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(email, style: const TextStyle(color: Colors.white54)),

                        const SizedBox(height: 30),

                        // 4. LEVEL CARD
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [Colors.blue.shade900.withOpacity(0.8), Colors.purple.shade900.withOpacity(0.8)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight
                            ),
                            borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Cấp độ $level", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                                  Text("$score / $nextLevelScore XP", style: const TextStyle(color: Colors.white70)),
                                ],
                              ),
                              const SizedBox(height: 15),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(value: progress, backgroundColor: Colors.black26, color: Colors.cyanAccent, minHeight: 12),
                              ),
                              const SizedBox(height: 10),
                              const Text("Tiếp tục học để mở khóa huy hiệu mới!", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 25),

                        // 5. STATS GRID
                        Row(
                          children: [
                            _buildStatBox("Chuỗi", "$streak Ngày", Icons.local_fire_department, Colors.orange),
                            const SizedBox(width: 15),
                            _buildStatBox("Tim", "$hearts", Icons.favorite, Colors.redAccent),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            _buildStatBox("Xếp hạng", rankDisplay, rankIcon, rankColor),
                            const SizedBox(width: 15),
                            _buildStatBox("Từ vựng", "$vocabCount", Icons.translate, Colors.greenAccent),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // 6. MENU
                        _buildMenuOption(context, Icons.person_outline, "Chỉnh sửa hồ sơ"),
                        _buildMenuOption(context, Icons.settings_outlined, "Cài đặt chung"),
                        _buildMenuOption(context, Icons.help_outline, "Trợ giúp & Phản hồi"),
                        const SizedBox(height: 30),

                        // LOGOUT BUTTON
                        SizedBox(
                          width: double.infinity, height: 55,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.withOpacity(0.1),
                                foregroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.redAccent, width: 1.5)),
                                elevation: 0
                            ),
                            onPressed: () async {
                              await AuthService().signOut();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                                        (Route<dynamic> route) => false
                                );
                              }
                            },
                            icon: const Icon(Icons.logout),
                            label: const Text("Đăng xuất", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  );
                }
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatarWithFrame(String? photoUrl, String name, String frameType) {
    bool isGold = frameType == 'gold';
    Color borderColor = isGold ? const Color(0xFFFFD700) : Colors.cyanAccent;
    double borderWidth = isGold ? 4.0 : 2.0;
    List<BoxShadow> shadows = isGold
        ? [BoxShadow(color: Colors.amber.withOpacity(0.6), blurRadius: 20, spreadRadius: 2)]
        : [BoxShadow(color: Colors.cyanAccent.withOpacity(0.4), blurRadius: 15)];

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 110, height: 110,
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: shadows),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor, width: borderWidth), color: const Color(0xFF131F24)),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[800],
            backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
            child: (photoUrl == null || photoUrl.isEmpty)
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : "?", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white))
                : null,
          ),
        ),
        if (isGold)
          Positioned(
            top: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: const Icon(Icons.star, color: Colors.white, size: 16),
            ),
          )
      ],
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white10)
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(color: color == Colors.grey ? Colors.white : color, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))
            ]
        ),
      ),
    );
  }

  Widget _buildMenuOption(BuildContext context, IconData icon, String title) {
    return ListTile(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tính năng '$title' đang được phát triển! 🛠️"), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating));
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 5),
        leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white70, size: 20)
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14)
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
          const SizedBox(height: 20),
          const Text("Không tải được hồ sơ!", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              AuthService().signOut();
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false);
            },
            child: const Text("Đăng xuất", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}