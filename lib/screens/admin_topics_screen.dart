// File: lib/screens/admin_topics_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_questions_screen.dart';

class AdminTopicsScreen extends StatefulWidget {
  const AdminTopicsScreen({super.key});

  @override
  State<AdminTopicsScreen> createState() => _AdminTopicsScreenState();
}

class _AdminTopicsScreenState extends State<AdminTopicsScreen> {
  final CollectionReference _topicsCollection = FirebaseFirestore.instance.collection('topics');

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _sectionController = TextEditingController();

  // Giải phóng bộ nhớ khi thoát màn hình
  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  void _showTopicForm(BuildContext context, [DocumentSnapshot? document]) {
    bool isEditing = document != null;
    if (isEditing) {
      _titleController.text = document['title'];
      _descController.text = document['description'] ?? '';
      _sectionController.text = (document['section'] ?? 1).toString();
    } else {
      _titleController.clear();
      _descController.clear();
      _sectionController.text = "1";
    }

    // Dùng BottomSheet thay vì Dialog để đồng bộ với các màn hình Admin khác
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B252D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20 // Đẩy lên khi bàn phím hiện
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(isEditing ? "Sửa Chủ Đề" : "Thêm Chủ Đề Mới",
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),

            _buildInput(_titleController, "Tên chủ đề (VD: Du lịch)"),
            const SizedBox(height: 15),
            _buildInput(_descController, "Mô tả ngắn (VD: Học từ vựng sân bay...)"),
            const SizedBox(height: 15),
            _buildInput(_sectionController, "Thuộc Phần số mấy? (Section)", isNumber: true, icon: Icons.map),

            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: () async {
                  if (_titleController.text.isNotEmpty && _sectionController.text.isNotEmpty) {
                    Map<String, dynamic> data = {
                      'title': _titleController.text.trim(),
                      'description': _descController.text.trim(),
                      'section': int.tryParse(_sectionController.text) ?? 1,
                      'createdAt': isEditing ? null : FieldValue.serverTimestamp(),
                    };

                    if (isEditing) data.remove('createdAt');

                    if (isEditing) {
                      await _topicsCollection.doc(document.id).update(data);
                    } else {
                      await _topicsCollection.add(data);
                    }
                    if (context.mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text("LƯU CHỦ ĐỀ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, {bool isNumber = false, IconData? icon}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: Colors.grey[400]),
        suffixIcon: icon != null ? Icon(icon, color: Colors.white54) : null,
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  // Hàm xác nhận xóa an toàn
  void _confirmDelete(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D3033),
        title: const Text("Xóa chủ đề?", style: TextStyle(color: Colors.white)),
        content: const Text("CẢNH BÁO: Xóa chủ đề này sẽ mất toàn bộ câu hỏi bên trong nó!", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy", style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () {
                doc.reference.delete();
                Navigator.pop(ctx);
              },
              child: const Text("Xóa vĩnh viễn", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      appBar: AppBar(
        title: const Text("Quản lý Chủ Đề"),
        backgroundColor: const Color(0xFF2D3033),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyanAccent,
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: () => _showTopicForm(context),
      ),
      body: StreamBuilder(
        stream: _topicsCollection.orderBy('section').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Chưa có chủ đề nào", style: TextStyle(color: Colors.white54)));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              int section = data['section'] ?? 1;

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1B252D),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withOpacity(0.2),
                    child: Text("$section", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(data['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),

                  // --- HIỂN THỊ SỐ CÂU HỎI ---
                  // Dùng FutureBuilder để đếm số lượng câu hỏi trong sub-collection
                  subtitle: FutureBuilder<AggregateQuerySnapshot>(
                      future: doc.reference.collection('questions').count().get(),
                      builder: (context, countSnapshot) {
                        String countText = "Đang tải...";
                        if (countSnapshot.hasData) {
                          countText = "${countSnapshot.data!.count} câu hỏi";
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text("Phần $section • $countText", style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        );
                      }
                  ),
                  // ---------------------------

                  trailing: PopupMenuButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    color: const Color(0xFF2D3033),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text("Sửa", style: TextStyle(color: Colors.white))),
                      const PopupMenuItem(value: 'delete', child: Text("Xóa", style: TextStyle(color: Colors.redAccent))),
                    ],
                    onSelected: (val) {
                      if (val == 'edit') _showTopicForm(context, doc);
                      if (val == 'delete') _confirmDelete(doc);
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminQuestionsScreen(topicId: doc.id, topicName: data['title']),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}