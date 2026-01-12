// File: lib/screens/shop_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  // Map cấu hình Icon và Màu sắc cho gọn code
  static final Map<String, dynamic> _itemConfig = {
    'heart':  {'icon': Icons.favorite, 'color': Colors.redAccent},
    'shield': {'icon': Icons.security, 'color': Colors.blueAccent},
    'freeze': {'icon': Icons.ac_unit, 'color': Colors.lightBlueAccent},
    'xp':     {'icon': Icons.flash_on, 'color': Colors.orangeAccent},
    'gem':    {'icon': Icons.diamond, 'color': Colors.purpleAccent},
    'time':   {'icon': Icons.timer, 'color': Colors.greenAccent},
  };

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF131F24),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));

              var userData = userSnapshot.data!.data() as Map<String, dynamic>;
              int currentScore = userData['score'] ?? 0;
              int currentHearts = userData['hearts'] ?? 5;
              bool hasShield = userData['hasShield'] ?? false;
              String currentFrame = userData['frame'] ?? 'default';

              return Column(
                children: [
                  // 1. HEADER (Đã fix lỗi Overflow)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF131F24),
                      border: Border(bottom: BorderSide(color: Colors.white10)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            "Cửa Tiệm Vũ Trụ 🛒",
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                              const SizedBox(width: 8),
                              Text("$currentScore XP", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                  // 2. LIST ITEMS
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('shop_items').orderBy('price').snapshots(),
                      builder: (context, shopSnapshot) {
                        if (!shopSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                        if (shopSnapshot.data!.docs.isEmpty) return const Center(child: Text("Cửa hàng đang trống!", style: TextStyle(color: Colors.white54)));

                        return ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: shopSnapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            var itemData = shopSnapshot.data!.docs[index].data() as Map<String, dynamic>;
                            return _buildShopItem(context, user, currentScore, currentHearts, hasShield, currentFrame, itemData);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            }
        ),
      ),
    );
  }

  Widget _buildShopItem(
      BuildContext context,
      User user,
      int currentScore,
      int currentHearts,
      bool hasShield,
      String currentFrame,
      Map<String, dynamic> itemData
      ) {

    String name = itemData['name'] ?? 'Vật phẩm';
    int price = itemData['price'] ?? 0;
    String desc = itemData['description'] ?? '';
    String iconKey = itemData['icon'] ?? 'heart';

    // --- LẤY ICON & MÀU TỪ MAP (Gọn hơn) ---
    var config = _itemConfig[iconKey] ?? {'icon': Icons.card_giftcard, 'color': Colors.cyanAccent};
    IconData iconData = config['icon'];
    Color itemColor = config['color'];

    // --- CHECK SỞ HỮU ---
    bool isOwned = false;
    String ownedLabel = "ĐÃ MUA";

    // Logic kiểm tra
    if (name.contains("Tim") || iconKey == 'heart') {
      isOwned = currentHearts >= 5;
      ownedLabel = "ĐÃ ĐẦY";
    } else if (name.contains("Khiên") || iconKey == 'shield') {
      isOwned = hasShield;
      ownedLabel = "ĐANG DÙNG";
    } else if (name.contains("Khung") || iconKey == 'gem') {
      isOwned = currentFrame == 'gold';
      ownedLabel = "ĐANG DÙNG";
    }

    bool canAfford = currentScore >= price;
    bool isDisabled = isOwned || !canAfford;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF1B252D), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: itemColor.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(iconData, color: itemColor, size: 32),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: isDisabled ? Colors.grey.withOpacity(0.2) : itemColor,
                foregroundColor: isDisabled ? Colors.white38 : Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: isDisabled ? 0 : 5,
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10)
            ),
            onPressed: isDisabled ? null : () => _confirmPurchase(context, user, name, price),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(isOwned ? ownedLabel : (canAfford ? "MUA" : "THIẾU XP"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                if (!isOwned) Text("$price XP", style: TextStyle(fontSize: 10, color: isDisabled ? Colors.redAccent : Colors.black87)),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _confirmPurchase(BuildContext context, User user, String name, int price) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D3033),
        title: const Text("Xác nhận đổi quà 🎁", style: TextStyle(color: Colors.white)),
        content: Text("Bạn muốn dùng $price XP để đổi lấy '$name' không?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Để sau", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  // Logic xử lý mua hàng
                  Map<String, dynamic> updateData = {'score': FieldValue.increment(-price)};

                  // Cập nhật thuộc tính dựa trên tên hoặc key (ở đây dùng tên cho đơn giản theo logic cũ của bạn)
                  if (name.contains("Tim")) updateData['hearts'] = 5;
                  if (name.contains("Khiên")) updateData['hasShield'] = true;
                  if (name.contains("Khung")) updateData['frame'] = 'gold';

                  await FirebaseFirestore.instance.collection('users').doc(user.uid).update(updateData);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Giao dịch thành công! 🎉"), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi giao dịch!"), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text("ĐỔI NGAY", style: TextStyle(fontWeight: FontWeight.bold))
          )
        ],
      ),
    );
  }
}