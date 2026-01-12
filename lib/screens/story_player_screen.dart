// File: lib/screens/story_player_screen.dart
import 'package:audioplayers/audioplayers.dart'; // Thêm gói này để có âm thanh
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class StoryPlayerScreen extends StatefulWidget {
  final String storyTitle;
  final List<dynamic> content;

  const StoryPlayerScreen({super.key, required this.storyTitle, required this.content});

  @override
  State<StoryPlayerScreen> createState() => _StoryPlayerScreenState();
}

class _StoryPlayerScreenState extends State<StoryPlayerScreen> {
  final FlutterTts flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer(); // Player cho hiệu ứng âm thanh
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _visibleLines = [];
  int _currentIndex = 0;
  bool _isWaitingForAnswer = false;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _setupTts();
    _playNextLine();
  }

  @override
  void dispose() {
    flutterTts.stop();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    // Chờ đọc xong mới chạy dòng code tiếp theo (Quan trọng!)
    await flutterTts.awaitSpeakCompletion(true);
  }

  // Hàm phát âm thanh đúng/sai
  void _playSound(bool isCorrect) async {
    try {
      String source = isCorrect ? 'audio/correct.mp3' : 'audio/wrong.mp3';
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(source));
    } catch (e) {
      // Bỏ qua lỗi nếu chưa có file âm thanh
    }
  }

  void _playNextLine() async {
    if (_currentIndex >= widget.content.length) {
      setState(() => _isFinished = true);
      _showCompletionDialog(); // Hiện Dialog chúc mừng
      return;
    }

    var currentItem = widget.content[_currentIndex];
    String type = currentItem['type'] ?? 'line';

    if (type == 'line') {
      // --- ĐỔI GIỌNG ---
      String role = currentItem['role'] ?? 'A';
      if (role == 'A') {
        await flutterTts.setPitch(1.0); // Giọng nữ/trẻ
      } else {
        await flutterTts.setPitch(0.6); // Giọng nam/trầm
      }

      // Cập nhật UI trước khi đọc
      setState(() {
        _visibleLines.add(currentItem);
      });
      _scrollToBottom();

      String textToSpeak = currentItem['text'] ?? "";
      if (textToSpeak.isNotEmpty) {
        await flutterTts.speak(textToSpeak);
        // Đã đọc xong (nhờ await ở trên), chuyển câu tiếp
        _onSpeakComplete();
      } else {
        _onSpeakComplete();
      }

    } else if (type == 'question') {
      setState(() {
        _isWaitingForAnswer = true;
      });
      _scrollToBottom();
    }
  }

  void _onSpeakComplete() {
    if (!_isWaitingForAnswer && !_isFinished) {
      // Nghỉ 0.5s giữa các câu
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _currentIndex++);
          _playNextLine();
        }
      });
    }
  }

  void _scrollToBottom() {
    // Dùng addPostFrameCallback để đảm bảo UI đã render xong mới cuộn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleAnswer(String selectedOption) {
    var currentItem = widget.content[_currentIndex];
    String correctAnswer = currentItem['correctAnswer'];

    if (selectedOption == correctAnswer) {
      _playSound(true); // Ting!
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chính xác! 🎉"), backgroundColor: Colors.green, duration: Duration(milliseconds: 500)));
      setState(() {
        _isWaitingForAnswer = false;
        _currentIndex++;
      });
      _playNextLine();
    } else {
      _playSound(false); // Tè...
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sai rồi, thử lại nhé! 😅"), backgroundColor: Colors.redAccent));
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131F24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.greenAccent, width: 2)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 60),
            SizedBox(height: 10),
            Text("CÂU CHUYỆN KẾT THÚC!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
        content: const Text("Bạn đã hoàn thành xuất sắc bài đọc hiểu này.", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
              onPressed: () {
                Navigator.pop(ctx); // Đóng Dialog
                Navigator.pop(context); // Thoát màn hình
              },
              child: const Text("HOÀN THÀNH", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? currentQuestionData;
    if (_isWaitingForAnswer && _currentIndex < widget.content.length) {
      currentQuestionData = widget.content[_currentIndex];
    }

    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      appBar: AppBar(
        title: Text(widget.storyTitle),
        backgroundColor: const Color(0xFF131F24),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. KHUNG CHAT
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _visibleLines.length,
              itemBuilder: (context, index) {
                var line = _visibleLines[index];
                bool isRoleA = (line['role'] == 'A');
                return _buildChatBubble(
                  text: line['text'],
                  subText: line['vietnamese'],
                  isLeft: isRoleA,
                  roleName: line['role'] ?? (isRoleA ? "A" : "B"), // Hiển thị tên vai
                );
              },
            ),
          ),

          // 2. KHUNG TRẢ LỜI CÂU HỎI (Chỉ hiện khi đến đoạn hỏi)
          if (_isWaitingForAnswer && currentQuestionData != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: Color(0xFF1B252D),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, -5))]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("KIỂM TRA NHANH 🧠", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text(currentQuestionData['question'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ... (currentQuestionData['options'] as List).map((opt) =>
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2D3033),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.white24))
                          ),
                          onPressed: () => _handleAnswer(opt),
                          child: Text(opt, style: const TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      )
                  ).toList()
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatBubble({required String text, String? subText, required bool isLeft, required String roleName}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end, // Avatar nằm dưới cùng
        children: [
          // Avatar Bên Trái (Role A)
          if (isLeft) ...[
            CircleAvatar(
              backgroundColor: Colors.blueAccent,
              radius: 16,
              child: Text(roleName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
          ],

          // Bong bóng chat
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: isLeft ? const Color(0xFF2D3033) : const Color(0xFF1CB0F6),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: isLeft ? Radius.zero : const Radius.circular(12),
                  bottomRight: isLeft ? const Radius.circular(12) : Radius.zero,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: TextStyle(color: isLeft ? Colors.white : Colors.black, fontSize: 16)),
                  if (subText != null) ...[
                    const SizedBox(height: 4),
                    Text(subText, style: TextStyle(color: isLeft ? Colors.grey : Colors.black54, fontSize: 13, fontStyle: FontStyle.italic)),
                  ]
                ],
              ),
            ),
          ),

          // Avatar Bên Phải (Role B)
          if (!isLeft) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.pinkAccent,
              radius: 16,
              child: Text(roleName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}