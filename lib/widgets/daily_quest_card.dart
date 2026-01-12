// File: lib/widgets/daily_quest_card.dart
import 'package:flutter/material.dart';

class DailyQuestCard extends StatelessWidget {
  final String title;
  final int progress;
  final int target;
  final int reward;
  final bool isClaimed;
  final VoidCallback onClaim;

  const DailyQuestCard({
    super.key,
    required this.title,
    required this.progress,
    required this.target,
    required this.reward,
    required this.isClaimed,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Tính toán an toàn
    double percent = target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;
    bool isCompleted = progress >= target;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B252D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          // Viền vàng sáng lên nếu xong mà chưa nhận
            color: (isCompleted && !isClaimed) ? Colors.amber : Colors.white10,
            width: (isCompleted && !isClaimed) ? 2 : 1
        ),
        boxShadow: (isCompleted && !isClaimed)
            ? [BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 8)]
            : [],
      ),
      child: Row(
        children: [
          // 2. Icon Trạng thái
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isClaimed
                  ? Colors.green.withOpacity(0.1)
                  : (isCompleted ? Colors.amber.withOpacity(0.1) : Colors.white.withOpacity(0.05)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isClaimed ? Icons.check_circle : (isCompleted ? Icons.card_giftcard : Icons.lock_clock),
              color: isClaimed ? Colors.green : (isCompleted ? Colors.amber : Colors.grey),
              size: 24,
            ),
          ),
          const SizedBox(width: 15),

          // 3. Thông tin nhiệm vụ
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thêm maxLines để không bị vỡ layout nếu tên nhiệm vụ dài
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Thanh tiến trình
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: percent,
                          backgroundColor: Colors.white10,
                          color: isCompleted ? Colors.amber : Colors.cyanAccent,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text("$progress/$target", style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // 4. Nút Nhận thưởng
          if (isCompleted && !isClaimed)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 5,
                  shadowColor: Colors.amber.withOpacity(0.5)
              ),
              onPressed: onClaim,
              child: Row(
                children: [
                  const Icon(Icons.flash_on, size: 16, color: Colors.black),
                  const SizedBox(width: 2),
                  Text("+$reward", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                ],
              ),
            )
          else if (isClaimed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8)
              ),
              child: const Text("ĐÃ NHẬN", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}