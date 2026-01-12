// File: lib/screens/home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../widgets/daily_quest_card.dart';
import 'quiz_screen.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';
import 'news_screen.dart';
import 'shop_screen.dart';
import 'flashcard_screen.dart';
import 'ai_chat_screen.dart';
import 'story_list_screen.dart'; // Đã import đúng

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseService dbService = DatabaseService();

  int _selectedIndex = 0;

  final List<Color> _sectionColors = [
    const Color(0xFF58CC02),
    const Color(0xFFCE82FF),
    const Color(0xFFFF9600),
    const Color(0xFF1CB0F6),
    const Color(0xFFFF4B4B),
  ];

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      dbService.checkAndRefillHearts(user!.uid);
      dbService.checkAndGenerateDailyQuests(user!.uid);
    }
    _pages = [
      _buildLearningTab(),     // Tab 0
      const LeaderboardScreen(), // Tab 1
      const ShopScreen(),        // Tab 2
      const NewsScreen(),        // Tab 3
      const ProfileScreen(),     // Tab 4
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      appBar: _selectedIndex == 0 ? _buildGamifiedAppBar() : null,

      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),

      // AI Chat Button (Chỉ hiện ở Tab Học tập)
      floatingActionButton: _selectedIndex == 0 ? SizedBox(
        height: 65, width: 65, // Giảm size chút cho cân đối
        child: FloatingActionButton(
          heroTag: "ai_chat_btn",
          backgroundColor: Colors.cyanAccent,
          elevation: 10,
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AIChatScreen()));
          },
          child: const Icon(Icons.smart_toy_rounded, color: Colors.black, size: 30),
        ),
      ) : null,

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10, width: 1)),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF131F24),
          selectedItemColor: Colors.cyanAccent,
          unselectedItemColor: Colors.grey,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.rocket_launch), label: "Học tập"),
            BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: "Xếp hạng"),
            BottomNavigationBarItem(icon: Icon(Icons.store_mall_directory_rounded), label: "Cửa hàng"),
            BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: "Bản tin"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Hồ sơ"),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildGamifiedAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF131F24),
      elevation: 0,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: Colors.white10, height: 1.0),
      ),
      actions: [
        // 1. Nút Truyện Chêm (Mới)
        Padding(
          padding: const EdgeInsets.only(right: 5),
          child: IconButton(
            icon: const Icon(Icons.menu_book_rounded, color: Colors.pinkAccent, size: 28),
            tooltip: "Truyện chêm",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const StoryListScreen()));
            },
          ),
        ),

        // 2. Nút Nhiệm vụ
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: IconButton(
            icon: const Icon(Icons.assignment_turned_in_rounded, color: Colors.amberAccent, size: 28),
            onPressed: () => _showDailyQuestsDialog(),
          ),
        )
      ],
      title: StreamBuilder<DocumentSnapshot>(
        stream: dbService.getUserStream(user!.uid),
        builder: (context, snapshot) {
          int hearts = 5;
          int score = 0;
          int streak = 0;

          if (snapshot.hasData && snapshot.data!.data() != null) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            hearts = data['hearts'] ?? 5;
            score = data['score'] ?? 0;
            streak = data['streak'] ?? 0;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Row(
              children: [
                // Flag Icon (Có xử lý lỗi ảnh)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                  child: Image.network(
                    "https://cdn-icons-png.flaticon.com/512/197/197374.png",
                    width: 24, height: 24,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.flag, color: Colors.white, size: 24),
                  ),
                ),
                const Spacer(),
                // Các chỉ số (Dùng Flexible để tránh tràn)
                _buildStatItem(Icons.local_fire_department, const Color(0xFFFF9600), "$streak"),
                const SizedBox(width: 15),
                _buildStatItem(Icons.diamond, const Color(0xFF1CB0F6), "$score"),
                const SizedBox(width: 15),
                _buildStatItem(Icons.favorite, const Color(0xFFFF4B4B), "$hearts"),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDailyQuestsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131F24),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
            stream: dbService.getUserStream(user!.uid),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)));

              var userData = snapshot.data!.data() as Map<String, dynamic>;
              List quests = userData['dailyQuests'] ?? [];

              return Container(
                padding: const EdgeInsets.all(20),
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    Container(
                      width: 50, height: 5,
                      decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(10)),
                    ),
                    const SizedBox(height: 20),
                    const Text("Nhiệm vụ hôm nay 📅", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    const Text("Hoàn thành để nhận XP!", style: TextStyle(color: Colors.white54)),
                    const SizedBox(height: 20),

                    Expanded(
                      child: quests.isEmpty
                          ? const Center(child: Text("Đang tải nhiệm vụ...", style: TextStyle(color: Colors.white54)))
                          : ListView.builder(
                        itemCount: quests.length,
                        itemBuilder: (ctx, index) {
                          var q = quests[index];
                          return DailyQuestCard(
                            title: q['title'],
                            progress: q['progress'],
                            target: q['target'],
                            reward: q['reward'],
                            isClaimed: q['isClaimed'] ?? false,
                            onClaim: () {
                              dbService.claimQuestReward(user!.uid, index, q['reward']);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text("Nhận thành công +${q['reward']} XP! 🎉"),
                                      backgroundColor: Colors.green
                                  )
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, Color color, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min, // Chỉ chiếm không gian cần thiết
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  // --- TAB HỌC TẬP ---
  Widget _buildLearningTab() {
    return StreamBuilder<DocumentSnapshot>(
        stream: dbService.getUserStream(user!.uid),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));

          var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          int currentLessonIndex = userData?['currentLesson'] ?? 0;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('topics').orderBy('section').snapshots(),
            builder: (context, topicSnapshot) {
              if (!topicSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
              var documents = topicSnapshot.data!.docs;

              List<Widget> listItems = [];

              for (int i = 0; i < documents.length; i++) {
                var doc = documents[i];
                var data = doc.data() as Map<String, dynamic>;
                int currentSection = data['section'] ?? 1;

                bool showHeader = false;
                if (i == 0) {
                  showHeader = true;
                } else {
                  var prevData = documents[i - 1].data() as Map<String, dynamic>;
                  if ((prevData['section'] ?? 1) != currentSection) {
                    showHeader = true;
                  }
                }

                Color sectionColor = _sectionColors[(currentSection - 1) % _sectionColors.length];

                if (showHeader) {
                  bool isSectionLocked = i > currentLessonIndex;

                  listItems.add(_buildUnitHeader(
                    currentSection,
                    "Cửa $currentSection",
                    "Hành trình số $currentSection",
                    sectionColor,
                    isLocked: isSectionLocked,
                    jumpToIndex: i,
                    jumpTopicId: doc.id,
                    jumpTopicTitle: data['title'] ?? "Bài kiểm tra",
                  ));
                }

                // Logic vẽ đường cong (Snake Layout)
                int pos = 0;
                int patternIndex = i % 4;
                if (patternIndex == 1) pos = -1;
                if (patternIndex == 3) pos = 1;

                bool isLocked = i > currentLessonIndex;
                bool isCurrent = i == currentLessonIndex;
                bool isCompleted = i < currentLessonIndex;

                listItems.add(
                    AnimatedLessonNode(
                      index: i,
                      position: pos,
                      title: data['title'] ?? "Bài học",
                      topicId: doc.id,
                      color: sectionColor,
                      isLocked: isLocked,
                      isCurrent: isCurrent,
                      isCompleted: isCompleted,
                    )
                );
              }

              listItems.add(
                  Padding(
                    padding: const EdgeInsets.only(top: 40, bottom: 120),
                    child: Opacity(
                        opacity: 0.5,
                        child: Image.network(
                          "https://cdn-icons-png.flaticon.com/512/3408/3408545.png",
                          height: 100, fit: BoxFit.contain,
                          errorBuilder: (_,__,___) => const SizedBox(),
                        )
                    ),
                  )
              );

              return Stack(
                children: [
                  Positioned.fill(child: Container(color: const Color(0xFF131F24))),
                  ListView(
                    padding: const EdgeInsets.only(top: 20),
                    children: listItems,
                  ),

                  // Nút Ôn tập Flashcard (Nằm góc trái dưới)
                  Positioned(
                    left: 20,
                    bottom: 20,
                    child: Column(
                      children: [
                        FloatingActionButton(
                          heroTag: "flashcard_btn",
                          backgroundColor: Colors.indigoAccent,
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const FlashcardScreen()));
                          },
                          child: const Icon(Icons.style, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 5),
                        const Text("Ôn tập", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        }
    );
  }

  Widget _buildUnitHeader(
      int unitNumber,
      String title,
      String subtitle,
      Color color,
      {
        bool isLocked = false,
        int jumpToIndex = 0,
        String jumpTopicId = "",
        String jumpTopicTitle = ""
      }) {

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      margin: const EdgeInsets.only(bottom: 30, top: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border(
            top: BorderSide(color: color, width: 2),
            bottom: BorderSide(color: color, width: 2)
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("PHẦN $unitNumber", style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 5),
                Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          if (isLocked)
            GestureDetector(
              onTap: () => _showJumpConfirmDialog(jumpTopicId, jumpTopicTitle, jumpToIndex),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)]
                ),
                child: const Icon(Icons.vpn_key_rounded, color: Colors.black, size: 24),
              ),
            )
          else
            Icon(Icons.map_rounded, color: color, size: 40),
        ],
      ),
    );
  }

  void _showJumpConfirmDialog(String topicId, String title, int targetIndex) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF131F24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.cyanAccent)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.rocket_launch_rounded, size: 60, color: Colors.cyanAccent),
              const SizedBox(height: 20),
              const Text("Học vượt?", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Bài kiểm tra này sẽ rất khó! Nếu vượt qua, bạn sẽ mở khóa toàn bộ các bài trước đó.",
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(
                      topicId: topicId,
                      topicTitle: "Kiểm tra vượt cấp",
                      lessonIndex: 0,
                      isJumpTest: true,
                      jumpToIndex: targetIndex,
                    )));
                  },
                  child: const Text("BẮT ĐẦU THI NGAY", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Chưa sẵn sàng", style: TextStyle(color: Colors.grey)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- AnimatedLessonNode (Giữ nguyên) ---
class AnimatedLessonNode extends StatefulWidget {
  final int index;
  final int position;
  final String title;
  final String topicId;
  final Color color;
  final bool isLocked;
  final bool isCurrent;
  final bool isCompleted;

  const AnimatedLessonNode({
    super.key,
    required this.index,
    required this.position,
    required this.title,
    required this.topicId,
    required this.color,
    required this.isLocked,
    required this.isCurrent,
    required this.isCompleted,
  });

  @override
  State<AnimatedLessonNode> createState() => _AnimatedLessonNodeState();
}

class _AnimatedLessonNodeState extends State<AnimatedLessonNode> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isCurrent) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedLessonNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent && !oldWidget.isCurrent) {
      _controller.repeat(reverse: true);
    } else if (!widget.isCurrent && oldWidget.isCurrent) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startLesson() async {
    if (widget.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hãy hoàn thành bài học trước để mở khóa! 🔒"), backgroundColor: Colors.grey));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    var userSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    int currentHearts = userSnapshot.data()?['hearts'] ?? 0;

    if (currentHearts > 0) {
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(
            topicId: widget.topicId,
            topicTitle: widget.title,
            lessonIndex: widget.index
        )));
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bạn đã hết tim! Hãy chờ hồi phục hoặc mua thêm 💔"), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double offset = widget.position * (screenWidth * 0.16);

    Color baseColor;
    Color shadowColor;
    IconData icon;

    if (widget.isLocked) {
      baseColor = const Color(0xFF2A3A47);
      shadowColor = Colors.black26;
      icon = Icons.lock;
    } else if (widget.isCompleted) {
      baseColor = const Color(0xFFFFC800);
      shadowColor = const Color(0xFFC79100);
      icon = Icons.check_rounded;
    } else {
      baseColor = widget.color;
      shadowColor = HSLColor.fromColor(widget.color).withLightness(0.4).toColor();
      icon = Icons.star_rounded;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isCurrent ? _scaleAnimation.value : 1.0,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: _startLesson,
        child: Container(
          margin: const EdgeInsets.only(bottom: 30),
          child: Center(
            child: Transform.translate(
              offset: Offset(offset, 0),
              child: Opacity(
                opacity: widget.isLocked ? 0.7 : 1.0,
                child: Column(
                  children: [
                    Container(
                      width: 75, height: 70,
                      decoration: BoxDecoration(
                        color: baseColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: shadowColor, offset: const Offset(0, 6), blurRadius: 0),
                          if (widget.isCurrent) BoxShadow(color: baseColor.withOpacity(0.6), blurRadius: 20, spreadRadius: 2)
                        ],
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 4),
                      ),
                      child: Icon(icon, color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 10),
                    if (!widget.isLocked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: widget.isCurrent ? Colors.white : Colors.black26,
                            borderRadius: BorderRadius.circular(12)
                        ),
                        child: Text(
                          widget.title,
                          style: TextStyle(
                              color: widget.isCurrent ? baseColor : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 12
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}