// File: lib/screens/admin_stories_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminStoriesScreen extends StatefulWidget {
  const AdminStoriesScreen({super.key});

  @override
  State<AdminStoriesScreen> createState() => _AdminStoriesScreenState();
}

class _AdminStoriesScreenState extends State<AdminStoriesScreen> {
  final CollectionReference _storiesRef = FirebaseFirestore.instance.collection('stories');

  void _openStoryEditor(BuildContext context, [DocumentSnapshot? doc]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131F24),
      builder: (ctx) => StoryEditor(
        doc: doc,
        onSave: (data) async {
          if (doc == null) {
            await _storiesRef.add(data);
          } else {
            await _storiesRef.doc(doc.id).update(data);
          }
          if (mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      appBar: AppBar(
        title: const Text("Quản lý Truyện Chêm 📚", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyanAccent,
        onPressed: () => _openStoryEditor(context),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _storiesRef.orderBy('level').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              return Card(
                color: const Color(0xFF1B252D),
                child: ListTile(
                  leading: data['image'] != null && data['image'].toString().isNotEmpty
                      ? Image.network(data['image'], width: 50, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.book, color: Colors.white))
                      : const Icon(Icons.book, color: Colors.white),
                  title: Text(data['title'] ?? "No Title", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text("Level: ${data['level']} • ${ (data['content'] as List).length } dòng thoại", style: const TextStyle(color: Colors.grey)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _openStoryEditor(context, docs[index])),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(docs[index])),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D3033),
        title: const Text("Xóa truyện?", style: TextStyle(color: Colors.white)),
        content: const Text("Hành động này không thể hoàn tác.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () { doc.reference.delete(); Navigator.pop(ctx); }, child: const Text("Xóa", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class StoryEditor extends StatefulWidget {
  final DocumentSnapshot? doc;
  final Function(Map<String, dynamic>) onSave;

  const StoryEditor({super.key, this.doc, required this.onSave});

  @override
  State<StoryEditor> createState() => _StoryEditorState();
}

class _StoryEditorState extends State<StoryEditor> {
  final _titleController = TextEditingController();
  final _imageController = TextEditingController();
  final _levelController = TextEditingController();
  List<Map<String, dynamic>> _content = [];

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      var data = widget.doc!.data() as Map<String, dynamic>;
      _titleController.text = data['title'];
      _imageController.text = data['image'] ?? "";
      _levelController.text = (data['level'] ?? 1).toString();
      _content = List<Map<String, dynamic>>.from(data['content'] ?? []);
    } else {
      _levelController.text = "1";
    }
  }

  // --- 1. SỬA LỖI DIALOG THOẠI (Dùng Wrap thay vì Row để tránh tràn ngang) ---
  void _showLineDialog({Map<String, dynamic>? existingItem, int? index}) {
    final textCtrl = TextEditingController(text: existingItem?['text']);
    final vnCtrl = TextEditingController(text: existingItem?['vietnamese']);
    String role = existingItem?['role'] ?? 'A';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D3033),
        scrollable: true, // Giữ nguyên cái này để fix lỗi bàn phím
        title: Text(index == null ? "Thêm Thoại" : "Sửa Thoại", style: const TextStyle(color: Colors.cyanAccent)),
        content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, // Canh lề trái cho đẹp khi dùng Wrap
                children: [
                  const Text("Vai:", style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 8), // Tăng khoảng cách một chút

                  // --- SỬA ĐỔI CHÍNH Ở ĐÂY: Dùng Wrap ---
                  Wrap(
                    spacing: 10.0, // Khoảng cách giữa các chip theo chiều ngang
                    runSpacing: 8.0, // Khoảng cách giữa các dòng chip nếu bị xuống dòng
                    children: [
                      FilterChip(
                        label: const Text("A (Nam)"),
                        selected: role == 'A',
                        onSelected: (val) => setStateDialog(() => role = 'A'),
                        checkmarkColor: Colors.black,
                        selectedColor: Colors.amber, // Thêm màu selected cho rõ
                      ),
                      FilterChip(
                        label: const Text("B (Nữ)"),
                        selected: role == 'B',
                        onSelected: (val) => setStateDialog(() => role = 'B'),
                        checkmarkColor: Colors.black,
                        selectedColor: Colors.amber,
                      ),
                    ],
                  ),
                  // ----------------------------------------

                  const SizedBox(height: 15),
                  _buildDialogInput(textCtrl, "Tiếng Anh"),
                  const SizedBox(height: 10),
                  _buildDialogInput(vnCtrl, "Tiếng Việt"),
                ],
              );
            }
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Map<String, dynamic> newLine = {
                'type': 'line',
                'role': role,
                'text': textCtrl.text.trim(),
                'vietnamese': vnCtrl.text.trim()
              };
              setState(() {
                if (index != null) {
                  _content[index] = newLine;
                } else {
                  _content.add(newLine);
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text("Lưu"),
          )
        ],
      ),
    );
  }

  // --- 2. SỬA LỖI DIALOG QUIZ (Dùng scrollable: true) ---
  void _showQuizDialog({Map<String, dynamic>? existingItem, int? index}) {
    final questionCtrl = TextEditingController(text: existingItem?['question']);
    final optionsCtrl = TextEditingController(text: (existingItem?['options'] as List?)?.join(','));
    final correctCtrl = TextEditingController(text: existingItem?['correctAnswer']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D3033),
        scrollable: true, // 🔥 QUAN TRỌNG: Cho phép cuộn nội dung tự động
        title: const Text("Câu hỏi trắc nghiệm", style: TextStyle(color: Colors.orangeAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogInput(questionCtrl, "Câu hỏi"),
            const SizedBox(height: 10),
            _buildDialogInput(optionsCtrl, "Đáp án (phân cách bởi dấu phẩy)"),
            const SizedBox(height: 10),
            _buildDialogInput(correctCtrl, "Đáp án đúng (Copy y chang)"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              List<String> opts = optionsCtrl.text.split(',').map((e) => e.trim()).toList();
              Map<String, dynamic> newQuiz = {
                'type': 'question',
                'question': questionCtrl.text.trim(),
                'options': opts,
                'correctAnswer': correctCtrl.text.trim()
              };
              setState(() {
                if (index != null) {
                  _content[index] = newQuiz;
                } else {
                  _content.add(newQuiz);
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text("Lưu"),
          )
        ],
      ),
    );
  }

  Widget _buildDialogInput(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      maxLines: null,
      decoration: InputDecoration(
          labelText: hint,
          labelStyle: TextStyle(color: Colors.grey[400]),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Padding bottom này giúp đẩy nội dung lên khi bàn phím hiện
      padding: EdgeInsets.only(top: 20, left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Biên tập Truyện", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(child: _buildInput(_titleController, "Tên truyện")),
                const SizedBox(width: 10),
                SizedBox(width: 80, child: _buildInput(_levelController, "Level", isNumber: true)),
              ],
            ),
            const SizedBox(height: 10),
            _buildInput(_imageController, "Link Ảnh bìa"),

            const SizedBox(height: 20),
            const Text("Kịch bản:", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // LIST KỊCH BẢN
            Container(
              height: 300,
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
              child: _content.isEmpty
                  ? const Center(child: Text("Chưa có nội dung", style: TextStyle(color: Colors.white54)))
                  : ListView.separated(
                itemCount: _content.length,
                separatorBuilder: (_,__) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  var item = _content[index];
                  bool isLine = item['type'] == 'line';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isLine ? (item['role'] == 'A' ? Colors.blue : Colors.pink) : Colors.orange,
                      child: Text(isLine ? item['role'] : "?", style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(isLine ? item['text'] : item['question'], style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(isLine ? item['vietnamese'] : "Quiz", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), onPressed: () => isLine ? _showLineDialog(existingItem: item, index: index) : _showQuizDialog(existingItem: item, index: index)),
                        IconButton(icon: const Icon(Icons.close, size: 20, color: Colors.redAccent), onPressed: () => setState(() => _content.removeAt(index))),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: ElevatedButton.icon(onPressed: () => _showLineDialog(), icon: const Icon(Icons.chat_bubble), label: const Text("Thêm Thoại"), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(onPressed: () => _showQuizDialog(), icon: const Icon(Icons.quiz), label: const Text("Thêm Quiz"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black))),
              ],
            ),

            const SizedBox(height: 20),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 15)),
                onPressed: () {
                  if (_titleController.text.isEmpty) return;
                  widget.onSave({
                    'title': _titleController.text.trim(),
                    'image': _imageController.text.trim(),
                    'level': int.tryParse(_levelController.text) ?? 1,
                    'content': _content,
                  });
                },
                child: const Text("LƯU TRUYỆN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: Colors.grey[400]), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
    );
  }
}