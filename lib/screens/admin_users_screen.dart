// File: lib/screens/admin_users_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  // Hàm hiển thị hộp thoại xác nhận hành động
  Future<void> _confirmAction(BuildContext context, String title, String content, VoidCallback onConfirm) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D3033),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text("Xác nhận", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Hàm helper để hiển thị SnackBar
  void _showSnackBar(BuildContext context, String message, Color color) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentAdminId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      appBar: AppBar(
        title: const Text("Quản lý Học viên"),
        backgroundColor: const Color(0xFF2D3033),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('users').orderBy('score', descending: true).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              String name = data['displayName'] ?? data['email'] ?? 'Unknown';
              String email = data['email'] ?? 'No Email';
              String role = data['role'] ?? 'user';
              int score = data['score'] ?? 0;
              String? photoUrl = data['photoUrl'];
              bool isAdmin = role == 'admin';

              // Kiểm tra xem đây có phải là tài khoản đang đăng nhập không
              bool isMe = doc.id == currentAdminId;

              return Card(
                color: const Color(0xFF1B252D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: isMe ? Colors.green : (isAdmin ? Colors.redAccent.withOpacity(0.5) : Colors.transparent),
                      width: 1.5
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    backgroundColor: Colors.grey[800],
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : "?", style: const TextStyle(fontWeight: FontWeight.bold))
                        : null,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name + (isMe ? " (Bạn)" : ""),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (isAdmin)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(6)
                          ),
                          child: const Text("ADMIN", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email, style: const TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text("$score XP", style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),

                  // Chỉ hiện nút thao tác nếu KHÔNG PHẢI là chính mình
                  trailing: isMe
                      ? const Icon(Icons.verified_user, color: Colors.green)
                      : PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    color: const Color(0xFF2D3033),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _confirmAction(
                            context,
                            "Xóa người dùng?",
                            "Hành động này sẽ xóa dữ liệu học tập của $name. Lưu ý: Tài khoản đăng nhập vẫn tồn tại trên hệ thống Auth.",
                                () async {
                              await doc.reference.delete();
                              _showSnackBar(context, "Đã xóa user thành công", Colors.redAccent);
                            }
                        );
                      } else if (value == 'promote') {
                        _confirmAction(
                            context, "Cấp quyền Admin?", "Bạn có chắc muốn thăng chức cho $name thành Admin?",
                                () async {
                              await doc.reference.update({'role': 'admin'});
                              _showSnackBar(context, "Đã thăng chức $name thành Admin 👮", Colors.green);
                            }
                        );
                      } else if (value == 'demote') {
                        _confirmAction(
                            context, "Hủy quyền Admin?", "Bạn có chắc muốn giáng chức $name xuống thành viên thường?",
                                () async {
                              await doc.reference.update({'role': 'user'});
                              _showSnackBar(context, "Đã giáng chức $name xuống Member ⬇️", Colors.orangeAccent);
                            }
                        );
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      if (!isAdmin)
                        const PopupMenuItem(value: 'promote', child: Row(children: [Icon(Icons.arrow_upward, color: Colors.green), SizedBox(width: 10), Text('Thăng chức Admin', style: TextStyle(color: Colors.white))])),

                      if (isAdmin)
                        const PopupMenuItem(value: 'demote', child: Row(children: [Icon(Icons.arrow_downward, color: Colors.orange), SizedBox(width: 10), Text('Giáng chức', style: TextStyle(color: Colors.white))])),

                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever, color: Colors.redAccent), SizedBox(width: 10), Text('Xóa User', style: TextStyle(color: Colors.redAccent))])),
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
}