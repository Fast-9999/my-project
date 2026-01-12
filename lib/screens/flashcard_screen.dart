// File: lib/screens/flashcard_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  final FlutterTts flutterTts = FlutterTts();

  List<QueryDocumentSnapshot> _mistakes = [];
  bool _isLoading = true;

  // Trạng thái câu hỏi
  bool _isAnswered = false;
  String? _userSelectedOption; // Lưu đáp án người dùng chọn để tô màu

  int _currentIndex = 0;
  String _questionText = "";
  String _correctAnswer = "";
  List<String> _options = [];

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadMistakes();
  }

  void _initTts() async {
    try {
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setPitch(1.0);
    } catch (e) {
      print("TTS Error: $e");
    }
  }

  void _speak(String text) async {
    await flutterTts.stop();
    if (text.isNotEmpty) await flutterTts.speak(text);
  }

  Future<void> _loadMistakes() async {
    setState(() => _isLoading = true);
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('vocabulary')
          .get();

      if (mounted) {
        setState(() {
          _mistakes = snapshot.docs;
          _isLoading = false;
        });
        if (_mistakes.isNotEmpty) _generateQuestion();
      }
    } catch (e) {
      print("Lỗi tải lỗi sai: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  void _generateQuestion() {
    if (_mistakes.isEmpty) return;

    // Reset trạng thái
    _isAnswered = false;
    _userSelectedOption = null; // Reset lựa chọn

    if (_currentIndex >= _mistakes.length) _currentIndex = 0;

    var currentDoc = _mistakes[_currentIndex].data() as Map<String, dynamic>;

    String rawMeaning = currentDoc['meaning'] ?? "";
    _correctAnswer = currentDoc['word'] ?? "";

    if (rawMeaning.isEmpty || rawMeaning == "Từ vựng cần ôn") {
      _questionText = "Hãy chọn từ: $_correctAnswer";
    } else {
      _questionText = rawMeaning;
    }

    // --- TẠO ĐÁP ÁN NHIỄU ---
    List<String> allWords = _mistakes
        .map((e) => (e.data() as Map<String, dynamic>)['word'] as String)
        .toList();

    allWords.remove(_correctAnswer);
    allWords.shuffle();

    List<String> options = allWords.take(3).toList();

    if (options.length < 3) {
      List<String> dummy = ["Apple", "Banana", "Cat", "Dog", "Hello", "School", "Teacher", "Computer", "World", "Love", "Happy", "Sad"];
      dummy.shuffle();
      for(var w in dummy) {
        if(options.length < 3 && w != _correctAnswer && !options.contains(w)) {
          options.add(w);
        }
      }
    }

    options.add(_correctAnswer);
    options.shuffle();

    setState(() {
      _options = options;
    });
  }

  void _checkAnswer(String selectedOption) async {
    if (_isAnswered) return;

    setState(() {
      _isAnswered = true;
      _userSelectedOption = selectedOption; // Lưu lại đáp án vừa chọn
    });

    _speak(selectedOption);

    bool isCorrect = selectedOption == _correctAnswer;

    if (isCorrect) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('vocabulary')
          .doc(_mistakes[_currentIndex].id)
          .delete();

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Đã sửa lỗi! +10 XP 🔥"), backgroundColor: Colors.green, duration: Duration(milliseconds: 800))
        );
      }

      // Delay để người dùng kịp nhìn thấy màu xanh
      await Future.delayed(const Duration(milliseconds: 1000));

      setState(() => _mistakes.removeAt(_currentIndex));

      if (_mistakes.isEmpty) {
        setState(() {});
      } else {
        _generateQuestion();
      }
    } else {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Sai rồi: $_correctAnswer"), backgroundColor: Colors.redAccent, duration: const Duration(milliseconds: 1000))
        );
      }

      await Future.delayed(const Duration(milliseconds: 1500));

      setState(() {
        _currentIndex++;
        if (_currentIndex >= _mistakes.length) _currentIndex = 0;
        _generateQuestion();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      appBar: AppBar(
          title: const Text("Ôn tập lỗi sai 💔", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : _mistakes.isEmpty ? _buildEmptyState() : _buildQuizContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.check_circle_outline, size: 100, color: Colors.greenAccent),
      const SizedBox(height: 20),
      const Text("Sạch sành sanh lỗi sai! 🎉", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      const Text("Bạn đã khắc phục tất cả các từ vựng yếu.", style: TextStyle(color: Colors.white54)),
      const SizedBox(height: 30),
      ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
          onPressed: () => Navigator.pop(context),
          child: const Text("QUAY VỀ HỌC TIẾP", style: TextStyle(fontWeight: FontWeight.bold))
      )
    ]));
  }

  Widget _buildQuizContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text("Còn lại: ${_mistakes.length} lỗi", style: const TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: const Color(0xFF1B252D),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Dịch sang Tiếng Anh:", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    child: Text(
                        _questionText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          Expanded(
            flex: 5,
            child: ListView.separated(
              itemCount: _options.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, index) {
                String option = _options[index];

                // --- LOGIC MÀU SẮC NÂNG CAO ---
                Color bgColor = const Color(0xFF2D3033);
                Color borderColor = Colors.white24;
                Color textColor = Colors.white;

                if (_isAnswered) {
                  if (option == _correctAnswer) {
                    // Đáp án ĐÚNG luôn hiện màu Xanh
                    bgColor = Colors.green;
                    borderColor = Colors.greenAccent;
                  } else if (option == _userSelectedOption) {
                    // Đáp án SAI người dùng chọn sẽ hiện màu Đỏ
                    bgColor = Colors.redAccent;
                    borderColor = Colors.red;
                  }
                }

                return SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: bgColor,
                        foregroundColor: textColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: borderColor, width: 2)
                        ),
                        elevation: 0
                    ),
                    onPressed: () => _checkAnswer(option),
                    child: Text(option, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}