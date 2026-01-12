// File: lib/screens/ai_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  // --- CONFIG ---
  // ⚠️ LƯU Ý: Vẫn dùng key cũ của bạn, nhớ bảo mật khi release
  final String _apiKey = 'AIzaSyBYBUutzI44d9Ukog--XIrdeAiYOnO8XZw';
  final String _sarahAvatarUrl = "https://cdn-icons-png.flaticon.com/512/4322/4322991.png"; // Đổi avatar giáo viên hoạt hình cho hợp app
  String _userAvatarUrl = "https://cdn-icons-png.flaticon.com/512/9187/9187604.png";

  // --- AI & TTS VARS ---
  late final GenerativeModel _model;
  late final ChatSession _chatSession;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _flutterTts = FlutterTts();

  // --- SPEECH TO TEXT VARS ---
  late stt.SpeechToText _speech;
  bool _speechEnabled = false;

  // State Hold-to-Talk
  bool _isListening = false;
  bool _isHoldingMic = false;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': false,
      'message': "Hello! I'm Ms. Sarah. Press and hold the microphone to practice English with me! 🎙️"
    }
  ];

  @override
  void initState() {
    super.initState();
    _getUserAvatar();
    _initGemini();
    _initTts();
    _initSpeech();
  }

  // 🔥 QUAN TRỌNG: Phải có dispose để ngắt giọng nói khi thoát màn hình
  @override
  void dispose() {
    _flutterTts.stop(); // Ngắt âm thanh ngay lập tức
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initSpeech() async {
    _speech = stt.SpeechToText();
    // Yêu cầu quyền Micro ngay khi vào màn hình để trải nghiệm mượt hơn
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          // Tự động tắt trạng thái nghe nếu micro ngắt (dự phòng)
          if (status == 'notListening' && _isHoldingMic) {
            // Logic này để xử lý trường hợp ngắt đột ngột
          }
        },
        onError: (error) => print('Micro error: $error'),
      );
      setState(() {});
    }
  }

  // --- LOGIC HOLD-TO-TALK ---
  void _startListening() async {
    if (!_speechEnabled) {
      _initSpeech();
      return;
    }

    await _flutterTts.stop(); // Ngắt lời AI nếu đang nói
    _textController.clear();

    setState(() {
      _isHoldingMic = true;
      _isListening = true;
    });

    await _speech.listen(
      onResult: (val) {
        setState(() {
          _textController.text = val.recognizedWords;
        });
      },
      localeId: "en_US",
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
    );
  }

  void _stopListeningAndSend() async {
    setState(() {
      _isHoldingMic = false;
      _isListening = false;
    });

    await _speech.stop();

    // Delay nhẹ để STT chốt câu chữ cuối cùng
    Future.delayed(const Duration(milliseconds: 600), () {
      if (_textController.text.trim().isNotEmpty) {
        _sendMessage();
      }
    });
  }

  void _getUserAvatar() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.photoURL != null) setState(() => _userAvatarUrl = user!.photoURL!);
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    // Cấu hình giọng iOS/Android cho tự nhiên hơn (nếu có)
    await _flutterTts.setPitch(1.0);
  }

  void _initGemini() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash', // Cập nhật model ổn định hơn
      apiKey: _apiKey,
      generationConfig: GenerationConfig(temperature: 0.7),
    );

    _chatSession = _model.startChat(
      history: [
        Content.text("""
You are Ms. Sarah, a friendly English teacher. 
User level: Beginner/Intermediate.
Rules:
1. Correct grammar mistakes gently in [brackets].
2. Keep responses short (under 40 words).
3. Always ask a follow-up question.
""")
      ],
    );
  }

  Future<void> _sendMessage() async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    }

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'isUser': true, 'message': text});
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final response = await _chatSession.sendMessage(Content.text(text));
      final botText = response.text;

      if (botText != null) {
        if (mounted) { // Kiểm tra mounted để tránh lỗi gọi setState khi đã thoát
          setState(() {
            _messages.add({'isUser': false, 'message': botText});
            _isLoading = false;
          });
          _scrollToBottom();
          _flutterTts.speak(botText);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'isUser': false, 'message': "Sorry, I lost connection. Try again!"});
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildAvatar(bool isUser) {
    return CircleAvatar(
      radius: 18, backgroundColor: Colors.white10,
      backgroundImage: NetworkImage(isUser ? _userAvatarUrl : _sarahAvatarUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text("Ms. Sarah AI ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("👩‍🏫", style: TextStyle(fontSize: 24))],
        ),
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // KHUNG CHAT
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) ...[_buildAvatar(false), const SizedBox(width: 8)],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                              color: isUser ? Colors.cyanAccent : const Color(0xFF2A3A47),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                                bottomLeft: isUser ? const Radius.circular(18) : Radius.zero,
                                bottomRight: isUser ? Radius.zero : const Radius.circular(18),
                              ),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 3))]
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(msg['message'], style: TextStyle(color: isUser ? Colors.black : Colors.white, fontSize: 16, height: 1.4)),
                            if (!isUser) GestureDetector(onTap: () => _flutterTts.speak(msg['message']), child: Padding(padding: const EdgeInsets.only(top: 8), child: Icon(Icons.volume_up_rounded, size: 20, color: Colors.cyanAccent.withOpacity(0.8))))
                          ]),
                        ),
                      ),
                      if (isUser) ...[const SizedBox(width: 8), _buildAvatar(true)],
                    ],
                  ),
                );
              },
            ),
          ),

          if (_isLoading) Padding(padding: const EdgeInsets.only(left: 50, bottom: 10), child: Row(children: [const Text("Sarah is thinking... ", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)), SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent.withOpacity(0.5)))])),

          // --- THANH NHẬP LIỆU & MICRO ---
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: const Color(0xFF1B252D), borderRadius: const BorderRadius.vertical(top: Radius.circular(25)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -5))]),
            child: Row(
              children: [
                // NÚT MICRO (HOLD-TO-TALK)
                GestureDetector(
                  onLongPressStart: (_) => _startListening(),
                  onLongPressEnd: (_) => _stopListeningAndSend(),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Giữ nút Micro để nói chuyện! 🎙️"), duration: Duration(milliseconds: 800), backgroundColor: Colors.orange));
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isHoldingMic ? Colors.redAccent : Colors.grey[800],
                      shape: BoxShape.circle,
                      boxShadow: _isHoldingMic
                          ? [BoxShadow(color: Colors.redAccent.withOpacity(0.6), blurRadius: 15, spreadRadius: 5)] // Hiệu ứng tỏa sáng khi giữ
                          : [],
                    ),
                    transform: _isHoldingMic ? Matrix4.diagonal3Values(1.2, 1.2, 1.0) : Matrix4.identity(),
                    child: Icon(_isHoldingMic ? Icons.mic : Icons.mic_none, color: Colors.white, size: 26),
                  ),
                ),
                const SizedBox(width: 10),

                // Ô NHẬP LIỆU
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _isHoldingMic ? "Đang nghe..." : "Nhắn tin cho Sarah...",
                      hintStyle: TextStyle(color: _isHoldingMic ? Colors.redAccent : Colors.grey[500]),
                      border: InputBorder.none, filled: true, fillColor: Colors.black12,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.cyanAccent)),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),

                // NÚT GỬI
                GestureDetector(
                  onTap: _isLoading ? null : _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.cyanAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
                    child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Icon(Icons.send_rounded, color: Colors.black),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}