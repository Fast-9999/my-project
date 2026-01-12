// File: lib/screens/admin_shop_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminShopScreen extends StatefulWidget {
  const AdminShopScreen({super.key});

  @override
  State<AdminShopScreen> createState() => _AdminShopScreenState();
}

class _AdminShopScreenState extends State<AdminShopScreen> {
  final CollectionReference _shopCollection = FirebaseFirestore.instance.collection('shop_items');

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _selectedIcon = 'heart';

  // Map Icon + Màu sắc
  final Map<String, dynamic> _iconConfig = {
    'heart':  {'icon': Icons.favorite, 'color': Colors.redAccent},
    'shield': {'icon': Icons.security, 'color': Colors.blueAccent},
    'freeze': {'icon': Icons.ac_unit, 'color': Colors.lightBlueAccent},
    'xp':     {'icon': Icons.flash_on, 'color': Colors.orangeAccent},
    'gem':    {'icon': Icons.diamond, 'color': Colors.purpleAccent},
    'time':   {'icon': Icons.timer, 'color': Colors.greenAccent},
  };

  void _showForm(BuildContext context, [DocumentSnapshot? document]) {
    bool isEditing = document != null;

    if (isEditing) {
      Map<String, dynamic> data = document.data() as Map<String, dynamic>;
      _nameController.text = data['name'];
      _priceController.text = data['price'].toString();
      _descController.text = data['description'] ?? '';
      _selectedIcon = data['icon'] ?? 'heart';
    } else {
      _nameController.clear();
      _priceController.clear();
      _descController.clear();
      _selectedIcon = 'heart';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B252D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView( // Thêm ScrollView để an toàn với bàn phím
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(isEditing ? "Sửa Vật Phẩm" : "Thêm Vật Phẩm Mới",
                          style: const TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 20),

                    // Dropdown chọn Icon (Có hình + Màu)
                    DropdownButtonFormField<String>(
                      value: _selectedIcon,
                      dropdownColor: const Color(0xFF2D3033),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Biểu tượng",
                        filled: true, fillColor: Colors.white10,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        // Icon chính cũng đổi màu theo lựa chọn
                        prefixIcon: Icon(
                            _iconConfig[_selectedIcon]['icon'],
                            color: _iconConfig[_selectedIcon]['color']
                        ),
                      ),
                      items: _iconConfig.keys.map((key) {
                        return DropdownMenuItem(
                          value: key,
                          child: Row(
                            children: [
                              Icon(_iconConfig[key]['icon'], color: _iconConfig[key]['color'], size: 20),
                              const SizedBox(width: 10),
                              Text(key.toUpperCase(), style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setSheetState(() => _selectedIcon = val!),
                    ),
                    const SizedBox(height: 15),

                    _buildInput(_nameController, "Tên vật phẩm (VD: Hồi máu)"),
                    const SizedBox(height: 15),
                    _buildInput(_priceController, "Giá bán (XP)", isNumber: true, icon: Icons.monetization_on),
                    const SizedBox(height: 15),
                    _buildInput(_descController, "Mô tả công dụng", maxLines: 2),

                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () async {
                          if (_nameController.text.isNotEmpty && _priceController.text.isNotEmpty) {
                            Map<String, dynamic> data = {
                              'name': _nameController.text.trim(),
                              'price': int.tryParse(_priceController.text) ?? 0,
                              'description': _descController.text.trim(),
                              'icon': _selectedIcon,
                            };

                            if (isEditing) {
                              await _shopCollection.doc(document.id).update(data);
                            } else {
                              await _shopCollection.add(data);
                            }
                            if (context.mounted) Navigator.pop(ctx);
                          }
                        },
                        child: const Text("LƯU VẬT PHẨM", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              );
            }
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, {bool isNumber = false, IconData? icon, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
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

  void _confirmDelete(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D3033),
        title: const Text("Xóa vật phẩm?", style: TextStyle(color: Colors.white)),
        content: Text("Bạn có chắc muốn xóa '${doc['name']}' không?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy", style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () {
                doc.reference.delete();
                Navigator.pop(ctx);
              },
              child: const Text("Xóa", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      appBar: AppBar(title: const Text("Quản lý Cửa Hàng"), backgroundColor: const Color(0xFF2D3033)),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyanAccent,
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: () => _showForm(context),
      ),
      body: StreamBuilder(
        stream: _shopCollection.orderBy('price').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Cửa hàng đang trống", style: TextStyle(color: Colors.white54)));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              String iconKey = data['icon'] ?? 'heart';
              IconData iconData = _iconConfig[iconKey]?['icon'] ?? Icons.card_giftcard;
              Color iconColor = _iconConfig[iconKey]?['color'] ?? Colors.cyanAccent;

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1B252D),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10)
                    ),
                    child: Icon(iconData, color: iconColor, size: 28),
                  ),
                  title: Text(data['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text("${data['price']} • ${data['description'] ?? ''}", style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
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
                      if (val == 'delete') _confirmDelete(doc);
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