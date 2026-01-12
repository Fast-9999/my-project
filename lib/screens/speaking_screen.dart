// File: lib/screens/speaking_screen.dart
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart'; // <--- 1. MỚI: Import thư viện âm thanh
import 'dart:math';

class SpeakingScreen extends StatefulWidget {
  const SpeakingScreen({super.key});

  @override
  State<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends State<SpeakingScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _textSpoken = "Bấm mic để nói...";
  double _confidence = 1.0;

  // <--- 2. MỚI: Khai báo máy phát nhạc
  final AudioPlayer _audioPlayer = AudioPlayer();

  final List<String> _sentences = [
    "Hello how are you",
    "What is your name",
    "I love learning English",
    "The cat is very cute",
    "Where are you from",
    "Good morning teacher",
    "I like to eat pizza",
    "Have a nice day"
  ];

  String targetSentence = "";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _requestPermission();
    _randomizeSentence();
  }

  // <--- 3. MỚI: HÀM PHÁT NHẠC
  Future<void> _playSound(bool isCorrect) async {
    try {
      String source = isCorrect ? 'audio/correct.mp3' : 'audio/wrong.mp3';
      await _audioPlayer.play(AssetSource(source));
    } catch (e) {
      print("Lỗi phát nhạc: $e");
    }
  }

  // <--- 4. MỚI: Tắt loa khi thoát màn hình để nhẹ máy
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _randomizeSentence() {
    setState(() {
      targetSentence = _sentences[Random().nextInt(_sentences.length)];
      _textSpoken = "Bấm mic để nói...";
      _isListening = false;
    });
  }

  Future<void> _requestPermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('Trạng thái: $val'),
        onError: (val) => print('Lỗi: $val'),
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _textSpoken = val.recognizedWords;
              if (val.hasConfidenceRating && val.confidence > 0) {
                _confidence = val.confidence;
              }
            });
          },
          localeId: "en_US",
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _checkResult();
    }
  }

  void _checkResult() {
    String spoken = _textSpoken.toLowerCase().trim();
    String target = targetSentence.toLowerCase().trim();

    spoken = spoken.replaceAll(RegExp(r'[^\w\s]+'),'');
    target = target.replaceAll(RegExp(r'[^\w\s]+'),'');

    if (spoken == target) {
      _playSound(true); // <--- KÊU TING!
      _showResultDialog(true);
    } else {
      _playSound(false); // <--- KÊU BỤP!
      _showResultDialog(false);
    }
  }

  void _showResultDialog(bool isCorrect) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCorrect ? "Tuyệt vời! 🎉" : "Thử lại nhé 😅"),
        content: Text(isCorrect
            ? "Bạn phát âm rất chuẩn!"
            : "App nghe được: \"$_textSpoken\"\nCâu đúng là: \"$targetSentence\""),
        actions: [
          if (isCorrect)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _randomizeSentence();
              },
              child: const Text("Câu tiếp theo", style: TextStyle(fontWeight: FontWeight.bold)),
            ),

          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Đóng")
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Luyện nói tiếng Anh")),
      body: Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Hãy đọc to câu sau:", style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue),
              ),
              child: Text(
                targetSentence,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 50),

            Text(
              _textSpoken,
              style: const TextStyle(fontSize: 22, color: Colors.black87),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),
            if (_isListening)
              const Text("Đang nghe...", style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic)),

            const Spacer(),

            GestureDetector(
              onTap: _listen,
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                    color: _isListening ? Colors.red : Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)]
                ),
                child: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}