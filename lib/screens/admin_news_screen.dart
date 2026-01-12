// File: lib/screens/admin_news_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminNewsScreen extends StatefulWidget {
  const AdminNewsScreen({super.key});

  @override
  State<AdminNewsScreen> createState() => _AdminNewsScreenState();
}

class _AdminNewsScreenState extends State<AdminNewsScreen> {
  final CollectionReference _newsRef = FirebaseFirestore.instance.collection('news');

  // Mở Dialog thêm/sửa tin
  void _openNewsEditor(BuildContext context, [DocumentSnapshot? doc]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131F24),
      builder: (ctx) => NewsEditor(
        doc: doc,
        onSave: (data) async {
          if (doc == null) {
            // Thêm mới
            await _newsRef.add({
              ...data,
              'timestamp': FieldValue.serverTimestamp(),
            });
          } else {
            // Cập nhật
            await _newsRef.doc(doc.id).update(data);
          }
          if (mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  // Xóa tin
  void _confirmDelete(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D3033),
        title: const Text("Xóa bản tin?", style: TextStyle(color: Colors.white)),
        content: const Text("Hành động này không thể hoàn tác.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () { doc.reference.delete(); Navigator.pop(ctx); }, child: const Text("Xóa", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      appBar: AppBar(
        title: const Text("Quản lý Bản Tin 📡", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.tealAccent,
        onPressed: () => _openNewsEditor(context),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _newsRef.orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
          var docs = snapshot.data!.docs;

          if (docs.isEmpty) return const Center(child: Text("Chưa có tin tức nào", style: TextStyle(color: Colors.white54)));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              bool isFeatured = data['isFeatured'] ?? false;

              return Card(
                color: const Color(0xFF1B252D),
                shape: RoundedRectangleBorder(
                    side: isFeatured ? const BorderSide(color: Colors.amber, width: 1) : BorderSide.none,
                    borderRadius: BorderRadius.circular(12)
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: data['image'] != null && data['image'].toString().isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      data['image'],
                      width: 60, height: 60, fit: BoxFit.cover,
                      errorBuilder: (_,__,___) => Container(width: 60, height: 60, color: Colors.grey[800], child: const Icon(Icons.broken_image, color: Colors.white54)),
                    ),
                  )
                      : Container(width: 60, height: 60, color: Colors.grey[800], child: const Icon(Icons.newspaper, color: Colors.white54)),
                  title: Text(data['title'] ?? "No Title", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(data['subtitle'] ?? "", style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.teal.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.teal.withOpacity(0.5))),
                            child: Text(data['tag'] ?? "TIN TỨC", style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          if (isFeatured) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.amber),
                            const Text(" Hot", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold))
                          ]
                        ],
                      )
                    ],
                  ),
                  trailing: PopupMenuButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    color: const Color(0xFF2D3033),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 20), SizedBox(width: 10), Text("Sửa", style: TextStyle(color: Colors.white))])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 10), Text("Xóa", style: TextStyle(color: Colors.white))])),
                    ],
                    onSelected: (val) {
                      if (val == 'edit') _openNewsEditor(context, docs[index]);
                      if (val == 'delete') _confirmDelete(docs[index]);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- CLASS EDITOR RIÊNG (ĐÃ NÂNG CẤP) ---
class NewsEditor extends StatefulWidget {
  final DocumentSnapshot? doc;
  final Function(Map<String, dynamic>) onSave;

  const NewsEditor({super.key, this.doc, required this.onSave});

  @override
  State<NewsEditor> createState() => _NewsEditorState();
}

class _NewsEditorState extends State<NewsEditor> {
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  String _selectedType = 'event';
  bool _isFeatured = false;
  String? _previewImage; // Biến để lưu link ảnh xem trước

  final List<String> _types = ['event', 'update', 'maintenance', 'tip', 'focus'];

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      var data = widget.doc!.data() as Map<String, dynamic>;
      _titleCtrl.text = data['title'] ?? "";
      _subtitleCtrl.text = data['subtitle'] ?? "";
      _contentCtrl.text = data['content'] ?? "";
      _imageCtrl.text = data['image'] ?? "";
      _tagCtrl.text = data['tag'] ?? "SỰ KIỆN";
      _selectedType = data['type'] ?? 'event';
      _isFeatured = data['isFeatured'] ?? false;
      _previewImage = data['image']; // Load ảnh cũ nếu có
    } else {
      _tagCtrl.text = "SỰ KIỆN";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Padding bottom này cực quan trọng để đẩy nội dung lên khi bàn phím hiện
      padding: EdgeInsets.only(top: 20, left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Biên tập Bản Tin", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 20),

            _buildInput(_titleCtrl, "Tiêu đề (Title) *"),
            const SizedBox(height: 10),
            _buildInput(_subtitleCtrl, "Mô tả ngắn (Subtitle)"),
            const SizedBox(height: 10),

            // Nội dung dài
            TextField(
              controller: _contentCtrl,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                  labelText: "Nội dung chi tiết (Content)",
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  alignLabelWithHint: true
              ),
            ),
            const SizedBox(height: 10),

            // Ô nhập ảnh có sự kiện onChanged để xem trước
            TextField(
              controller: _imageCtrl,
              style: const TextStyle(color: Colors.white),
              onChanged: (val) {
                setState(() {
                  _previewImage = val; // Cập nhật ảnh xem trước ngay lập tức
                });
              },
              decoration: InputDecoration(labelText: "Link Ảnh (URL)", labelStyle: TextStyle(color: Colors.grey[400]), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),

            // --- KHUNG XEM TRƯỚC ẢNH ---
            if (_previewImage != null && _previewImage!.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                  color: Colors.black38,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _previewImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(child: Text("Ảnh lỗi hoặc link không đúng", style: TextStyle(color: Colors.redAccent))),
                  ),
                ),
              ),
            // ---------------------------

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(child: _buildInput(_tagCtrl, "Tag (VD: SỰ KIỆN)")),
                const SizedBox(width: 10),
                // Dropdown chọn loại
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedType,
                      dropdownColor: const Color(0xFF2D3033),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent),
                      style: const TextStyle(color: Colors.white),
                      items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setState(() => _selectedType = val!),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // Switch Tiêu điểm
            Container(
              decoration: BoxDecoration(color: _isFeatured ? Colors.amber.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: _isFeatured ? Colors.amber : Colors.white10)),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                title: const Text("🔥 Đặt làm Tiêu điểm?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Tin sẽ hiện to ở đầu trang", style: TextStyle(color: Colors.grey, fontSize: 12)),
                value: _isFeatured,
                activeColor: Colors.amber,
                onChanged: (val) => setState(() => _isFeatured = val),
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: () {
                  if (_titleCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập tiêu đề!"), backgroundColor: Colors.redAccent));
                    return;
                  }
                  widget.onSave({
                    'title': _titleCtrl.text.trim(),
                    'subtitle': _subtitleCtrl.text.trim(),
                    'content': _contentCtrl.text.trim(),
                    'image': _imageCtrl.text.trim(),
                    'tag': _tagCtrl.text.trim().toUpperCase(),
                    'type': _selectedType,
                    'isFeatured': _isFeatured,
                  });
                },
                child: const Text("LƯU BẢN TIN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400]),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
      ),
    );
  }
}