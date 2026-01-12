// File: lib/screens/quiz_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart'; // Để dùng HapticFeedback
import '../services/database_service.dart';

class QuizScreen extends StatefulWidget {
  final String topicId;
  final String topicTitle;
  final int lessonIndex;
  final bool isJumpTest;
  final int jumpToIndex;

  const QuizScreen({
    super.key,
    required this.topicId,
    required this.topicTitle,
    this.lessonIndex = 0,
    this.isJumpTest = false,
    this.jumpToIndex = 0,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  // --- VARIABLES ---
  List<QueryDocumentSnapshot> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  bool _isAnswered = false;
  int _currentHearts = 5;

  final FlutterTts flutterTts = FlutterTts();
  final DatabaseService _dbService = DatabaseService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late stt.SpeechToText _speech;
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  bool _isListening = false;
  String _textSpoken = "Bấm mic và đọc...";
  String? _selectedImageOption;
  List<String> _availableWords = [];
  List<String> _selectedWords = [];
  bool _isArrangeInitialized = false;
  String? _selectedFillOption;

  List<Map<String, dynamic>> _leftColumn = [];
  List<Map<String, dynamic>> _rightColumn = [];
  String? _selectedLeftId;
  String? _selectedRightId;
  Set<String> _matchedIds = {};
  bool _isMatchInitialized = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initTts();
    _loadData();
    _requestPermission();
  }

  @override
  void dispose() {
    flutterTts.stop();
    _audioPlayer.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    await Permission.microphone.request();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    await flutterTts.stop();
    if (text.isNotEmpty) await flutterTts.speak(text);
  }

  Future<void> _playSound(bool isCorrect) async {
    try {
      String source = isCorrect ? 'audio/correct.mp3' : 'audio/wrong.mp3';
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(source));
      if (!isCorrect) HapticFeedback.heavyImpact(); // Rung khi sai
    } catch (e) {
      print("Lỗi nhạc: $e");
    }
  }

  Future<void> _loadData() async {
    try {
      var qSnapshot = await FirebaseFirestore.instance.collection('topics').doc(widget.topicId).collection('questions').get();
      var uSnapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (mounted) {
        setState(() {
          _questions = qSnapshot.docs;
          _currentHearts = uSnapshot.data()?['hearts'] ?? 5;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Lỗi load data: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC XỬ LÝ KẾT QUẢ ---
  void _handleResult(bool isCorrect, String correctContent) async {
    setState(() {
      _isAnswered = true;
      _isListening = false;
      _speech.stop();
    });

    if (isCorrect) {
      _playSound(true);
      setState(() { _score += 10; });
    } else {
      _playSound(false);
      setState(() { _currentHearts--; });
      await _dbService.deductHeart(uid);

      try {
        var qData = _questions[_currentIndex].data() as Map<String, dynamic>;
        String type = qData['type'] ?? 'quiz';

        if (type != 'match') {
          String vocabWord = "";
          String vocabMeaning = "";

          if (type == 'quiz') {
            vocabMeaning = qData['question'] ?? "Câu hỏi";
            vocabWord = qData['correctAnswer'] ?? "";
          }
          else if (type == 'image') {
            vocabMeaning = "Chọn hình: " + (qData['question'] ?? "");
            vocabWord = qData['correctAnswer'] ?? "";
          }
          else if (type == 'arrange') {
            vocabMeaning = "Dịch câu: " + (qData['question'] ?? "");
            vocabWord = qData['correctAnswer'] ?? "";
          }
          else if (type == 'listen') {
            vocabMeaning = "Nghe và viết lại: " + (qData['correctAnswer'] ?? "");
            vocabWord = qData['correctAnswer'] ?? "";
          }
          else if (type == 'fill_blank') {
            vocabMeaning = "Điền vào chỗ trống: " + (qData['question'] ?? "");
            vocabWord = qData['correctAnswer'] ?? "";
          }
          else {
            vocabMeaning = qData['question'] ?? qData['meaning'] ?? "Ôn tập câu này";
            vocabWord = qData['correctAnswer'] ?? qData['word'] ?? "";
          }

          if (vocabWord.isNotEmpty) {
            await _dbService.addVocabulary(uid, vocabWord, vocabMeaning, type);
          }
        }
      } catch (e) {
        print("Lỗi lưu flashcard: $e");
      }
    }

    if (mounted) _showFeedbackBottomSheet(isCorrect, correctContent);
  }

  // 1. CHECK QUIZ
  void _checkQuizAnswer(String selectedOption) {
    if (_isAnswered) return;
    _speak(selectedOption);
    String correctAnswer = _questions[_currentIndex]['correctAnswer'];
    _handleResult(selectedOption == correctAnswer, correctAnswer);
  }

  // 2. CHECK IMAGE
  void _checkImageAnswer(String selectedOption) {
    if (_isAnswered) return;
    _speak(selectedOption);
    String correctAnswer = _questions[_currentIndex]['correctAnswer'];
    setState(() => _selectedImageOption = selectedOption);
    _handleResult(selectedOption == correctAnswer, correctAnswer);
  }

  // 3. CHECK SPEAKING
  void _listenSpeaking() async {
    if (_isAnswered) return;
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
            onResult: (val) {
              setState(() { _textSpoken = val.recognizedWords; });
              if (val.finalResult) Future.delayed(const Duration(seconds: 1), _checkSpeakingResult);
            },
            localeId: "en_US"
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _checkSpeakingResult();
    }
  }

  void _checkSpeakingResult() {
    String correctAnswer = _questions[_currentIndex]['correctAnswer'];
    String spoken = _textSpoken.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]+'), '');
    String target = correctAnswer.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]+'), '');

    if (spoken.isEmpty) return;
    _handleResult(spoken == target, correctAnswer);
  }

  // 4. CHECK ARRANGE
  void _initArrangeWords(List<dynamic> options) {
    if (!_isArrangeInitialized) {
      _availableWords = options.map((e) => e.toString()).toList();
      _availableWords.shuffle();
      _selectedWords = [];
      _isArrangeInitialized = true;
    }
  }

  void _onWordSelected(String word) {
    if (_isAnswered) return;
    setState(() {
      _availableWords.remove(word);
      _selectedWords.add(word);
    });
  }

  void _onWordDeselected(String word) {
    if (_isAnswered) return;
    setState(() {
      _selectedWords.remove(word);
      _availableWords.add(word);
    });
  }

  void _checkArrangeResult() {
    if (_isAnswered) return;
    String userAnswer = _selectedWords.join(" ");
    String correctAnswer = _questions[_currentIndex]['correctAnswer'];

    String cleanUser = userAnswer.toLowerCase().replaceAll('.', '').trim();
    String cleanCorrect = correctAnswer.toLowerCase().replaceAll('.', '').trim();

    _handleResult(cleanUser == cleanCorrect, correctAnswer);
  }

  // 5. CHECK FILL BLANK
  void _checkFillBlankResult() {
    if (_isAnswered || _selectedFillOption == null) return;
    String correctAnswer = _questions[_currentIndex]['correctAnswer'];
    _handleResult(_selectedFillOption == correctAnswer, correctAnswer);
  }

  // 6. CHECK MATCH
  void _initMatchWords(Map<String, dynamic> pairs) {
    if (!_isMatchInitialized) {
      _leftColumn = [];
      _rightColumn = [];
      int index = 0;

      pairs.forEach((english, vietnamese) {
        String pairId = "pair_$index";
        _leftColumn.add({'text': english, 'pairId': pairId, 'id': 'left_$index'});
        _rightColumn.add({'text': vietnamese, 'pairId': pairId, 'id': 'right_$index'});
        index++;
      });

      _leftColumn.shuffle();
      _rightColumn.shuffle();

      _matchedIds = {};
      _selectedLeftId = null;
      _selectedRightId = null;
      _isMatchInitialized = true;
    }
  }

  void _onMatchItemTap(String uniqueId, String pairId, bool isLeft) async {
    if (_matchedIds.contains(pairId)) return;

    setState(() {
      if (isLeft) {
        _selectedLeftId = (_selectedLeftId == uniqueId) ? null : uniqueId;
      } else {
        _selectedRightId = (_selectedRightId == uniqueId) ? null : uniqueId;
      }
    });

    if (_selectedLeftId != null && _selectedRightId != null) {
      String leftPairId = _leftColumn.firstWhere((e) => e['id'] == _selectedLeftId)['pairId'];
      String rightPairId = _rightColumn.firstWhere((e) => e['id'] == _selectedRightId)['pairId'];

      if (leftPairId == rightPairId) {
        _playSound(true);
        setState(() {
          _matchedIds.add(leftPairId);
          _selectedLeftId = null;
          _selectedRightId = null;
        });

        if (_matchedIds.length == _leftColumn.length) {
          await Future.delayed(const Duration(milliseconds: 500));
          _handleResult(true, "match_all");
        }
      } else {
        _playSound(false);
        setState(() { _currentHearts--; });
        await _dbService.deductHeart(uid);

        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chưa đúng! Thử lại nhé 😅"), duration: Duration(milliseconds: 500), backgroundColor: Colors.redAccent));
        }

        await Future.delayed(const Duration(milliseconds: 500));
        setState(() {
          _selectedLeftId = null;
          _selectedRightId = null;
        });

        if (_currentHearts <= 0) _showGameOverDialog();
      }
    }
  }

  // --- ĐIỀU HƯỚNG ---
  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswered = false;
        _textSpoken = "Bấm mic và đọc...";
        _selectedImageOption = null;
        _isArrangeInitialized = false;
        _selectedWords = [];
        _availableWords = [];
        _selectedFillOption = null;
        _leftColumn = [];
        _rightColumn = [];
        _matchedIds = {};
        _selectedLeftId = null;
        _selectedRightId = null;
        _isMatchInitialized = false;
      });
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    if (_score > 0) await _dbService.updateScore(uid, _score);
    await _dbService.updateStreak(uid);

    try {
      await _dbService.updateQuestProgress(uid, 'lesson', 1);
      if (_score > 0) {
        await _dbService.updateQuestProgress(uid, 'score', _score);
      }
      if (_currentHearts == 5) {
        await _dbService.updateQuestProgress(uid, 'perfect', 1);
      }

      if (widget.isJumpTest) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'currentLesson': widget.jumpToIndex
        });
      } else {
        var userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        int currentLesson = userDoc.data()?['currentLesson'] ?? 0;
        if (widget.lessonIndex == currentLesson) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'currentLesson': currentLesson + 1
          });
        }
      }
    } catch (e) { print("Lỗi mở khóa bài: $e"); }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: const Color(0xFF131F24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.amber, width: 3)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    _currentHearts == 5 ? Icons.workspace_premium_rounded : Icons.emoji_events_rounded,
                    size: 80,
                    color: _currentHearts == 5 ? Colors.purpleAccent : Colors.amber
                ),
                const SizedBox(height: 20),
                Text(
                    _currentHearts == 5
                        ? "PERFECT! KHÔNG SAI CÂU NÀO! 🔥"
                        : (widget.isJumpTest ? "NHẢY CẤP THÀNH CÔNG! 🚀" : "XUẤT SẮC! 🌟"),
                    style: TextStyle(
                        color: _currentHearts == 5 ? Colors.purpleAccent : Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold
                    ),
                    textAlign: TextAlign.center
                ),
                const SizedBox(height: 10),
                Text(
                    widget.isJumpTest ? "Bạn đã mở khóa toàn bộ phần này!" : "Bạn đã hoàn thành bài học này!",
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center
                ),
                const SizedBox(height: 15),
                Text("+ $_score XP", style: const TextStyle(color: Colors.amberAccent, fontSize: 36, fontWeight: FontWeight.w900)),
                const SizedBox(height: 30),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); }, child: const Text("TIẾP TỤC HÀNH TRÌNH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))))
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF131F24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.redAccent, width: 3)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.heart_broken_rounded, size: 80, color: Colors.redAccent),
              const SizedBox(height: 20),
              const Text("HẾT MẠNG RỒI! 😭", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); }, child: const Text("QUAY VỀ HỒI SỨC", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))))
            ],
          ),
        ),
      ),
    );
  }

  void _showFeedbackBottomSheet(bool isCorrect, String correctContent) {
    showModalBottomSheet(
      context: context, isDismissible: false, enableDrag: false, backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: const Color(0xFF131F24), borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), border: Border(top: BorderSide(color: isCorrect ? Colors.green : Colors.redAccent, width: 3))),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isCorrect ? Colors.green : Colors.redAccent, size: 40), const SizedBox(width: 15), Text(isCorrect ? "Tuyệt vời! 🎉" : "Chưa chính xác... 😢", style: TextStyle(color: isCorrect ? Colors.green : Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 15),
              if (!isCorrect && correctContent != "match_all") ...[
                const Text("Đáp án đúng là:", style: TextStyle(color: Colors.white54, fontSize: 16)),
                const SizedBox(height: 8),
                Text(correctContent, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 25)
              ],
              Container(width: double.infinity, height: 60, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: isCorrect ? Colors.green : Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () { Navigator.pop(context); if (!isCorrect && _currentHearts <= 0) _showGameOverDialog(); else _nextQuestion(); }, child: Text(isCorrect ? "TIẾP TỤC" : "ĐÃ HIỂU", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))
            ],
          ),
        );
      },
    );
  }

  Future<void> _showExitDialog() async {
    return showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF131F24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Đừng đi mà! 😭", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text("Tiến trình bài học này sẽ bị mất.", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 30),
              Row(children: [
                Expanded(child: TextButton(onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); }, child: const Text("THOÁT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)))),
                Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black), onPressed: () => Navigator.of(context).pop(), child: const Text("HỌC TIẾP")))
              ])
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF131F24), body: Center(child: CircularProgressIndicator()));
    if (_questions.isEmpty) return const Scaffold(backgroundColor: Color(0xFF131F24), body: Center(child: Text("Chưa có câu hỏi!", style: TextStyle(color: Colors.white))));

    var data = _questions[_currentIndex].data() as Map<String, dynamic>;
    String type = data['type'] ?? 'quiz';
    String questionText = data['question'] ?? "";
    String imageUrl = data['image'] ?? "";

    if (type == 'arrange' || type == 'listen') _initArrangeWords(data['options'] ?? []);
    if (type == 'match') _initMatchWords(data['pairs'] ?? {});

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async { if (didPop) return; _showExitDialog(); },
      child: Scaffold(
        backgroundColor: const Color(0xFF131F24),
        appBar: AppBar(
          title: Text(widget.topicTitle, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => _showExitDialog()),
          actions: [Padding(padding: const EdgeInsets.all(10.0), child: Row(children: [const Icon(Icons.favorite, color: Colors.red), const SizedBox(width: 5), Text("$_currentHearts", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))]))],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(height: 10, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(10)), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: (_currentIndex + 1) / _questions.length, backgroundColor: Colors.transparent, color: Colors.greenAccent, minHeight: 10))),
              const SizedBox(height: 20),

              if (type == 'match') const Text("Ghép các cặp từ tương ứng", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))
              else if (type == 'image') _buildQuestionHeaderWithAudio(questionText, "Chọn hình ảnh đúng")
              else if (type == 'arrange') _buildQuestionHeaderWithAudio(questionText, "Dịch câu này")
                else if (type == 'listen') _buildListenHeader(questionText)
                  else if (type == 'fill_blank') _buildFillBlankHeader(questionText, imageUrl)
                    else _buildStandardQuestionHeader(questionText, imageUrl),

              const SizedBox(height: 20),
              Expanded(child: _buildAnswerArea(type, data)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerArea(String type, Map<String, dynamic> data) {
    if (type == 'match') return _buildMatchWordInterface();
    else if (type == 'arrange' || type == 'listen') return _buildArrangeInterface();
    else if (type == 'speaking') return _buildSpeakingInterface();
    else if (type == 'image') return _buildImageQuizInterface(data);
    else if (type == 'fill_blank') return _buildFillBlankInterface(data);
    else return ListView(children: (data['options'] as List).map((opt) => _buildTextOptionBtn(opt)).toList());
  }

  Widget _buildMatchWordInterface() {
    return Row(
      children: [
        Expanded(child: ListView.separated(itemCount: _leftColumn.length, separatorBuilder: (ctx, i) => const SizedBox(height: 12), itemBuilder: (context, index) => _buildMatchItemCard(_leftColumn[index], true))),
        const SizedBox(width: 20),
        Expanded(child: ListView.separated(itemCount: _rightColumn.length, separatorBuilder: (ctx, i) => const SizedBox(height: 12), itemBuilder: (context, index) => _buildMatchItemCard(_rightColumn[index], false))),
      ],
    );
  }

  Widget _buildMatchItemCard(Map<String, dynamic> item, bool isLeft) {
    String text = item['text'];
    String uniqueId = item['id'];
    String pairId = item['pairId'];

    bool isMatched = _matchedIds.contains(pairId);
    bool isSelected = isLeft ? (_selectedLeftId == uniqueId) : (_selectedRightId == uniqueId);

    if (isMatched) {
      return Container(height: 60, decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green)), alignment: Alignment.center, child: const Icon(Icons.check, color: Colors.green));
    }
    return GestureDetector(
      onTap: () => _onMatchItemTap(uniqueId, pairId, isLeft),
      child: Container(
        height: 60, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: isSelected ? Colors.cyanAccent : Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? Colors.cyanAccent : Colors.white24, width: isSelected ? 2 : 1)),
        // Dùng Expanded hoặc AutoSizeText để tránh tràn
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
      ),
    );
  }

  Widget _buildFillBlankHeader(String questionText, String imageUrl) {
    List<String> parts = questionText.split('____');
    return Column(children: [
      if (imageUrl.isNotEmpty) Container(height: 150, margin: const EdgeInsets.only(bottom: 20), child: ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(imageUrl, fit: BoxFit.contain))),
      const Text("Hoàn thành câu", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(20), width: double.infinity, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.cyanAccent.withOpacity(0.5))), child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [Text(parts[0], style: const TextStyle(fontSize: 20, color: Colors.white)), Container(margin: const EdgeInsets.symmetric(horizontal: 5), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: _selectedFillOption != null ? Colors.white : Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.cyanAccent)), child: Text(_selectedFillOption ?? "      ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _selectedFillOption != null ? Colors.black : Colors.transparent))), if (parts.length > 1) Text(parts[1], style: const TextStyle(fontSize: 20, color: Colors.white))]))
    ]);
  }

  Widget _buildFillBlankInterface(Map<String, dynamic> data) {
    List<dynamic> options = data['options'] ?? [];
    return Column(children: [
      const Spacer(),
      Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: options.map((option) {
        String word = option.toString();
        bool isSelected = _selectedFillOption == word;
        return GestureDetector(onTap: () { if (_isAnswered) return; setState(() => _selectedFillOption = word); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: isSelected ? Colors.cyanAccent : Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.5))), child: Text(word, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 18, fontWeight: FontWeight.bold))));
      }).toList()),
      const SizedBox(height: 40),
      SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _selectedFillOption == null ? null : _checkFillBlankResult, child: const Text("KIỂM TRA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))
    ]);
  }

  Widget _buildArrangeInterface() {
    return Column(children: [
      Container(width: double.infinity, constraints: const BoxConstraints(minHeight: 100), padding: const EdgeInsets.all(10), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey, width: 2))), child: Wrap(spacing: 8, runSpacing: 8, children: _selectedWords.map((word) => _buildWordChip(word, true)).toList())),
      const Spacer(),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: _availableWords.map((word) => _buildWordChip(word, false)).toList()),
      const SizedBox(height: 30),
      SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _selectedWords.isEmpty ? null : _checkArrangeResult, child: const Text("KIỂM TRA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))
    ]);
  }

  Widget _buildWordChip(String word, bool isSelectedArea) {
    return GestureDetector(onTap: () { if (isSelectedArea) _onWordDeselected(word); else _onWordSelected(word); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.5))), child: Text(word, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))));
  }

  Widget _buildListenHeader(String text) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Nghe và điền", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [GestureDetector(onTap: () => _speak(text), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 40)))]),
      const SizedBox(height: 20), const Center(child: Text("Bấm vào loa để nghe", style: TextStyle(color: Colors.grey, fontSize: 12)))
    ]);
  }

  Widget _buildSpeakingInterface() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_textSpoken, style: const TextStyle(fontSize: 22, color: Colors.white), textAlign: TextAlign.center), const SizedBox(height: 30),
      GestureDetector(onTap: _listenSpeaking, child: Container(height: 80, width: 80, decoration: BoxDecoration(color: _isListening ? Colors.redAccent : Colors.cyanAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.4), blurRadius: 20)]), child: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.black, size: 40)))
    ]);
  }

  Widget _buildImageQuizInterface(Map<String, dynamic> data) {
    List<dynamic> texts = data['options'] ?? [];
    List<dynamic> images = data['optionImages'] ?? [];
    List<Map<String, String>> choices = [];
    for(int i=0; i<texts.length; i++) choices.add({'text': texts[i].toString(), 'image': i < images.length ? images[i].toString() : ''});
    return GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.85), itemCount: choices.length, itemBuilder: (context, index) => _buildImageOptionCard(choices[index]));
  }

  Widget _buildImageOptionCard(Map<String, String> choice) {
    String text = choice['text']!;
    String imgUrl = choice['image']!;
    bool isSelected = _selectedImageOption == text;
    return GestureDetector(onTap: () => _checkImageAnswer(text), child: Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: isSelected ? Colors.cyanAccent : Colors.grey.withOpacity(0.3), width: isSelected ? 3 : 1)), child: Column(children: [Expanded(child: Padding(padding: const EdgeInsets.all(10.0), child: imgUrl.isNotEmpty ? Image.network(imgUrl, fit: BoxFit.contain) : const Icon(Icons.image, size: 50, color: Colors.grey))), Padding(padding: const EdgeInsets.only(bottom: 15), child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)))])));
  }

  Widget _buildStandardQuestionHeader(String questionText, String imageUrl) {
    return Column(children: [
      if (imageUrl.isNotEmpty) Container(height: 150, width: double.infinity, margin: const EdgeInsets.only(bottom: 20), child: ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(imageUrl, fit: BoxFit.cover))),
      GestureDetector(onTap: () => _speak(questionText), child: Container(padding: const EdgeInsets.all(20), width: double.infinity, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.cyanAccent.withOpacity(0.5))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.volume_up, color: Colors.cyanAccent), const SizedBox(width: 10), Expanded(child: Text(questionText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center))]))),
    ]);
  }

  Widget _buildQuestionHeaderWithAudio(String text, String title) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
      Row(children: [GestureDetector(onTap: () => _speak(text), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.cyanAccent, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.volume_up, color: Colors.black, size: 30))), const SizedBox(width: 15), Expanded(child: Text(text, style: const TextStyle(fontSize: 22, color: Colors.white, height: 1.2)))]),
    ]);
  }

  Widget _buildTextOptionBtn(String text) {
    return Container(margin: const EdgeInsets.only(bottom: 15), width: double.infinity, height: 65, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(15), onTap: () => _checkQuizAnswer(text), child: Center(child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))))));
  }
}