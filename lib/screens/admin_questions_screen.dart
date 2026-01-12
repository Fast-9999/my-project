// File: lib/screens/admin_questions_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminQuestionsScreen extends StatefulWidget {
  final String topicId;
  final String topicName;

  const AdminQuestionsScreen({super.key, required this.topicId, required this.topicName});

  @override
  State<AdminQuestionsScreen> createState() => _AdminQuestionsScreenState();
}

class _AdminQuestionsScreenState extends State<AdminQuestionsScreen> {
  // Controller
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _correctAnswerController = TextEditingController();
  final TextEditingController _optionsController = TextEditingController();
  final TextEditingController _wordController = TextEditingController();
  final TextEditingController _wordTypeController = TextEditingController();
  final TextEditingController _meaningController = TextEditingController();

  // Controller Hình ảnh
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _optionImagesController = TextEditingController();

  // Controller cho cặp từ nối (Match)
  final TextEditingController _pairsController = TextEditingController();

  final List<String> _validTypes = [
    'image', 'listen', 'arrange', 'fill_blank', 'speaking', 'quiz', 'match'
  ];

  String _selectedType = 'image';

  // Biến local tạm thời để lưu link ảnh preview khi mở form
  String _tempPreviewUrl = "";

  void _showForm(BuildContext context, [DocumentSnapshot? document]) {
    bool isEditing = document != null;

    if (isEditing) {
      Map<String, dynamic> data = document.data() as Map<String, dynamic>;
      _questionController.text = data['question'] ?? '';
      _correctAnswerController.text = data['correctAnswer'] ?? '';
      _wordController.text = data['word'] ?? '';
      _wordTypeController.text = data['word_type'] ?? '';
      _meaningController.text = data['meaning'] ?? '';
      _imageUrlController.text = data['image'] ?? '';

      // Load ảnh cũ lên biến tạm
      _tempPreviewUrl = data['image'] ?? '';

      List optImgs = data['optionImages'] ?? [];
      _optionImagesController.text = optImgs.join(',');

      if (data['pairs'] != null) {
        Map<String, dynamic> pairsMap = data['pairs'];
        List<String> pairStrings = [];
        pairsMap.forEach((key, value) {
          pairStrings.add("$key:$value");
        });
        _pairsController.text = pairStrings.join(', ');
      } else {
        _pairsController.clear();
      }

      String dbType = data['type'] ?? 'image';
      _selectedType = _validTypes.contains(dbType) ? dbType : 'quiz';

      List opts = data['options'] ?? [];
      _optionsController.text = opts.join(',');
    } else {
      // Reset form
      _questionController.clear();
      _correctAnswerController.clear();
      _optionsController.clear();
      _wordController.clear();
      _wordTypeController.clear();
      _meaningController.clear();
      _imageUrlController.clear();
      _optionImagesController.clear();
      _pairsController.clear();
      _selectedType = 'quiz';
      _tempPreviewUrl = "";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B252D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(isEditing ? "Sửa câu hỏi" : "Thêm câu hỏi mới",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                    ),
                    const SizedBox(height: 20),

                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      dropdownColor: const Color(0xFF2D3033),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                          labelText: "Loại câu hỏi",
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      items: _validTypes.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                      onChanged: (val) {
                        setSheetState(() => _selectedType = val!);
                      },
                    ),
                    const SizedBox(height: 15),

                    _buildInput(_questionController, "Câu hỏi chính"),
                    const SizedBox(height: 15),

                    // --- FORM DYNAMIC ---

                    // 1. Match Form
                    if (_selectedType == 'match')
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(border: Border.all(color: Colors.orange.withOpacity(0.5)), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          children: [
                            _buildInput(_pairsController, "Cặp từ (VD: apple:táo, dog:chó)", icon: Icons.link, maxLines: 3),
                            const SizedBox(height: 5),
                            const Text("⚠️ Lưu ý: Dùng dấu hai chấm (:) ngăn cách, dấu phẩy (,) ngắt cặp.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 10),
                            _buildInput(_correctAnswerController, "Gợi ý đáp án (VD: match_all)"),
                          ],
                        ),
                      ),

                    // 2. Image Form (Có Preview Xịn)
                    if (_selectedType == 'quiz' || _selectedType == 'fill_blank' || _selectedType == 'image') ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _imageUrlController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                  labelText: "Link ảnh (URL)",
                                  filled: true, fillColor: Colors.white10,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
                                    onPressed: () {
                                      setSheetState(() => _tempPreviewUrl = _imageUrlController.text);
                                    },
                                  )
                              ),
                              onChanged: (val) {
                                // Tự động load ảnh sau 1s nếu người dùng dừng gõ (Optional, ở đây làm thủ công cho chắc)
                              },
                            ),
                          ),
                          if (_tempPreviewUrl.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Stack(
                              children: [
                                Container(
                                  height: 60, width: 60,
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(_tempPreviewUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.error, color: Colors.red)),
                                  ),
                                ),
                                Positioned(
                                  right: 0, top: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      _imageUrlController.clear();
                                      setSheetState(() => _tempPreviewUrl = "");
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                                    ),
                                  ),
                                )
                              ],
                            )
                          ]
                        ],
                      ),
                      const SizedBox(height: 15),
                    ],

                    if (_selectedType == 'image')
                      _buildInput(_optionImagesController, "Link ảnh đáp án (cách nhau dấu phẩy)", icon: Icons.photo_library),

                    // Các trường chung
                    if (_selectedType != 'match') ...[
                      _buildInput(_correctAnswerController, "Đáp án ĐÚNG (Key)"),
                      const SizedBox(height: 10),
                      _buildInput(_optionsController, "Các đáp án SAI/KHÁC (cách nhau dấu phẩy)"),
                    ],

                    const SizedBox(height: 15),
                    const Divider(color: Colors.white24),
                    const Text("Thông tin từ vựng (Flashcard)", style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(child: _buildInput(_wordController, "Từ vựng (EN)")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInput(_wordTypeController, "Loại (n/v/adj)")),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildInput(_meaningController, "Nghĩa tiếng Việt"),

                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () async {
                          // --- VALIDATION & SAVE LOGIC ---
                          List<String> optionsList = _optionsController.text.split(',').map((e) => e.trim()).toList();
                          optionsList.removeWhere((e) => e.isEmpty);

                          List<String> optionImagesList = _optionImagesController.text.split(',').map((e) => e.trim()).toList();
                          optionImagesList.removeWhere((e) => e.isEmpty);

                          Map<String, dynamic> data = {
                            'question': _questionController.text.trim(),
                            'type': _selectedType,
                            'correctAnswer': _correctAnswerController.text.trim(),
                            'options': optionsList,
                            'word': _wordController.text.trim(),
                            'word_type': _wordTypeController.text.trim(),
                            'meaning': _meaningController.text.trim(),
                            if (!isEditing) 'createdAt': FieldValue.serverTimestamp(),
                          };

                          if (_imageUrlController.text.isNotEmpty) data['image'] = _imageUrlController.text.trim();
                          if (optionImagesList.isNotEmpty) data['optionImages'] = optionImagesList;

                          if (_selectedType == 'match' && _pairsController.text.isNotEmpty) {
                            Map<String, String> pairsMap = {};
                            try {
                              List<String> rawPairs = _pairsController.text.split(',');
                              for (String item in rawPairs) {
                                List<String> kv = item.split(':');
                                if (kv.length == 2) {
                                  pairsMap[kv[0].trim()] = kv[1].trim();
                                }
                              }
                              data['pairs'] = pairsMap;
                            } catch (e) {
                              print("Lỗi parse pairs: $e"); // Bắt lỗi để không crash app
                            }
                          }

                          CollectionReference questionsRef = FirebaseFirestore.instance
                              .collection('topics').doc(widget.topicId).collection('questions');

                          if (isEditing) {
                            await questionsRef.doc(document.id).update(data);
                          } else {
                            await questionsRef.add(data);
                          }
                          if (context.mounted) Navigator.pop(ctx);
                        },
                        child: const Text("LƯU DỮ LIỆU", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    )
                  ],
                ),
              ),
            );
          }
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, {IconData? icon, int maxLines = 1}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        suffixIcon: icon != null ? Icon(icon, color: Colors.white54) : null,
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      appBar: AppBar(title: Text(widget.topicName, style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF2D3033), iconTheme: const IconThemeData(color: Colors.white)),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyanAccent,
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('topics')
            .doc(widget.topicId)
            .collection('questions')
            .orderBy('createdAt', descending: true) // Sắp xếp mới nhất lên đầu
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Chưa có câu hỏi nào", style: TextStyle(color: Colors.white54)));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              // Màu sắc icon tùy theo loại câu hỏi
              Color typeColor = Colors.grey;
              if (data['type'] == 'quiz') typeColor = Colors.blue;
              if (data['type'] == 'speaking') typeColor = Colors.red;
              if (data['type'] == 'match') typeColor = Colors.orange;
              if (data['type'] == 'image') typeColor = Colors.purple;

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1B252D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                        data['type'] == 'speaking' ? Icons.mic :
                        data['type'] == 'match' ? Icons.link :
                        data['type'] == 'image' ? Icons.image : Icons.quiz,
                        color: typeColor, size: 20
                    ),
                  ),
                  title: Text(data['question'] ?? '(Không có câu hỏi)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      "Type: ${data['type']} • Ans: ${data['correctAnswer']}",
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  trailing: PopupMenuButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    color: const Color(0xFF2D3033),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text("Sửa", style: TextStyle(color: Colors.white))),
                      const PopupMenuItem(value: 'delete', child: Text("Xóa", style: TextStyle(color: Colors.redAccent))),
                    ],
                    onSelected: (val) {
                      if (val == 'edit') _showForm(context, doc);
                      if (val == 'delete') {
                        // Xác nhận xóa
                        showDialog(context: context, builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF2D3033),
                          title: const Text("Xóa câu hỏi?", style: TextStyle(color: Colors.white)),
                          content: const Text("Hành động này không thể hoàn tác.", style: TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy", style: TextStyle(color: Colors.grey))),
                            TextButton(onPressed: () { doc.reference.delete(); Navigator.pop(ctx); }, child: const Text("Xóa", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                          ],
                        ));
                      }
                    },
                  ),
                  onTap: () => _showForm(context, doc),
                ),
              );
            },
          );
        },
      ),
    );
  }
}