// File: lib/services/database_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. LƯU USER AN TOÀN (Cập nhật Last Login)
  Future<void> saveUserData(String uid, String email, {String? photoUrl, String? displayName}) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      final docSnapshot = await userRef.get();

      if (!docSnapshot.exists) {
        // Tạo mới hoàn toàn
        await userRef.set({
          'email': email,
          'displayName': displayName ?? email.split('@')[0],
          'photoUrl': photoUrl ?? "",
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(), // Thêm dòng này
          'score': 0,
          'hearts': 5,
          'level': 1,
          'frame': 'default',
          'hasShield': false, // Mặc định chưa có khiên
          'lastLostTime': null,
          'streak': 0,
          'lastLessonDate': null,
          'currentLesson': 0,
          'lastQuestDate': '',
          'dailyQuests': [],
        });
      } else {
        // Cập nhật thông tin nếu đăng nhập lại
        Map<String, dynamic> updates = {
          'lastLogin': FieldValue.serverTimestamp() // Luôn cập nhật lần cuối online
        };
        if (photoUrl != null && photoUrl.isNotEmpty) updates['photoUrl'] = photoUrl;
        if (displayName != null && displayName.isNotEmpty) updates['displayName'] = displayName;

        await userRef.update(updates);
      }
    } catch (e) {
      print("Lỗi lưu user: $e");
    }
  }

  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // 2. TRỪ TIM
  Future<void> deductHeart(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'hearts': FieldValue.increment(-1),
        'lastLostTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Lỗi trừ tim: $e");
    }
  }

  // 3. HỒI PHỤC TIM (Cơ chế 15 phút/tim)
  Future<void> checkAndRefillHearts(String uid) async {
    try {
      var doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return;

      var data = doc.data() as Map<String, dynamic>;
      int currentHearts = data['hearts'] ?? 5;

      if (currentHearts >= 5) return;

      Timestamp? lastLost = data['lastLostTime'];
      if (lastLost == null) return;

      DateTime lastTime = lastLost.toDate();
      DateTime now = DateTime.now();
      int minutesPassed = now.difference(lastTime).inMinutes;

      int minutesPerHeart = 15;
      int heartsToRecover = (minutesPassed / minutesPerHeart).floor();

      if (heartsToRecover > 0) {
        int newHearts = currentHearts + heartsToRecover;
        if (newHearts > 5) newHearts = 5;

        await _firestore.collection('users').doc(uid).update({
          'hearts': newHearts,
          'lastLostTime': newHearts < 5 ? FieldValue.serverTimestamp() : null,
        });
      }
    } catch (e) {
      print("Lỗi hồi tim: $e");
    }
  }

  // 4. CẬP NHẬT ĐIỂM SỐ
  Future<void> updateScore(String uid, int scoreToAdd) async {
    await _firestore.collection('users').doc(uid).update({
      'score': FieldValue.increment(scoreToAdd),
    });
  }

  // 5. MỞ KHÓA BÀI HỌC TIẾP THEO
  Future<void> unlockNextLesson(String uid, int completedLessonIndex) async {
    try {
      var doc = await _firestore.collection('users').doc(uid).get();
      int currentLesson = doc.data()?['currentLesson'] ?? 0;

      if (completedLessonIndex == currentLesson) {
        await _firestore.collection('users').doc(uid).update({
          'currentLesson': currentLesson + 1
        });
      }
    } catch (e) {
      print("Lỗi mở khóa bài học: $e");
    }
  }

  // 6. CẬP NHẬT STREAK (🔥 ĐÃ THÊM LOGIC KHIÊN BẢO VỆ 🔥)
  Future<void> updateStreak(String uid) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(uid);
      DocumentSnapshot doc = await userRef.get();
      if (!doc.exists) return;

      var data = doc.data() as Map<String, dynamic>;
      int currentStreak = data['streak'] ?? 0;
      bool hasShield = data['hasShield'] ?? false; // Kiểm tra có khiên không
      Timestamp? lastLessonTs = data['lastLessonDate'];

      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);

      if (lastLessonTs == null) {
        // Lần đầu học
        await userRef.update({
          'streak': 1,
          'lastLessonDate': FieldValue.serverTimestamp(),
        });
      } else {
        DateTime lastDateFull = lastLessonTs.toDate();
        DateTime lastDateOnly = DateTime(lastDateFull.year, lastDateFull.month, lastDateFull.day);

        if (lastDateOnly.isAtSameMomentAs(today)) {
          // Đã học hôm nay -> Giữ nguyên
        } else if (lastDateOnly.isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
          // Học hôm qua -> Tăng Streak
          await userRef.update({
            'streak': currentStreak + 1,
            'lastLessonDate': FieldValue.serverTimestamp(),
          });
        } else {
          // --- LOGIC KHIÊN BẢO VỆ ---
          if (hasShield) {
            // Có khiên -> Giữ streak, mất khiên, cập nhật ngày học thành hôm nay để tiếp tục
            print("Đã dùng khiên bảo vệ streak!");
            await userRef.update({
              'hasShield': false, // Mất khiên
              'lastLessonDate': FieldValue.serverTimestamp(), // Coi như hôm nay đã học để nối streak
              // Streak giữ nguyên
            });
          } else {
            // Không có khiên -> Reset về 1
            await userRef.update({
              'streak': 1,
              'lastLessonDate': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      print("Lỗi update streak: $e");
    }
  }

  // 7. KIỂM TRA VÀ TẠO NHIỆM VỤ MỚI
  Future<void> checkAndGenerateDailyQuests(String uid) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(uid);
      DocumentSnapshot userDoc = await userRef.get();

      if (!userDoc.exists) return;

      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      String todayStr = DateTime.now().toString().split(' ')[0];
      String lastQuestDate = data['lastQuestDate'] ?? "";

      if (lastQuestDate != todayStr) {
        List<Map<String, dynamic>> newQuests = _generateRandomQuests();
        await userRef.update({
          'lastQuestDate': todayStr,
          'dailyQuests': newQuests
        });
      }
    } catch (e) {
      print("Lỗi tạo Daily Quests: $e");
    }
  }

  // 8. RANDOM NHIỆM VỤ
  List<Map<String, dynamic>> _generateRandomQuests() {
    Random rng = Random();
    List<Map<String, dynamic>> templates = [
      {'type': 'lesson', 'target': 1, 'title': 'Hoàn thành 1 bài học', 'reward': 10},
      {'type': 'lesson', 'target': 3, 'title': 'Hoàn thành 3 bài học', 'reward': 30},
      {'type': 'score', 'target': 20, 'title': 'Đạt 20 điểm XP', 'reward': 15},
      {'type': 'score', 'target': 50, 'title': 'Đạt 50 điểm XP', 'reward': 40},
      {'type': 'perfect', 'target': 1, 'title': '1 bài đạt điểm tuyệt đối', 'reward': 50},
    ];

    templates.shuffle(rng);
    List<Map<String, dynamic>> selected = templates.take(3).toList();

    return selected.map((q) => {
      'type': q['type'],
      'target': q['target'],
      'title': q['title'],
      'reward': q['reward'],
      'progress': 0,
      'isClaimed': false,
    }).toList();
  }

  // 9. UPDATE TIẾN ĐỘ QUEST
  Future<void> updateQuestProgress(String uid, String type, int amount) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(uid);
      DocumentSnapshot doc = await userRef.get();

      if (doc.exists) {
        List<dynamic> quests = (doc.data() as Map<String, dynamic>)['dailyQuests'] ?? [];
        bool hasChange = false;

        List<dynamic> updatedQuests = quests.map((q) {
          if (q['type'] == type && (q['progress'] ?? 0) < q['target']) {
            int newProgress = (q['progress'] ?? 0) + amount;
            if (newProgress > q['target']) newProgress = q['target'];
            hasChange = true;
            return {...q, 'progress': newProgress};
          }
          return q;
        }).toList();

        if (hasChange) {
          await userRef.update({'dailyQuests': updatedQuests});
        }
      }
    } catch (e) {
      print("Lỗi update quest: $e");
    }
  }

  // 10. NHẬN THƯỞNG
  Future<void> claimQuestReward(String uid, int index, int reward) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(uid);
      DocumentSnapshot doc = await userRef.get();
      List<dynamic> quests = (doc.data() as Map<String, dynamic>)['dailyQuests'] ?? [];

      quests[index]['isClaimed'] = true;

      await userRef.update({
        'dailyQuests': quests,
        'score': FieldValue.increment(reward),
      });
    } catch (e) {
      print("Lỗi nhận thưởng: $e");
    }
  }

  // 11. TỪ VỰNG
  Future<void> addVocabulary(String uid, String word, String meaning, String type) async {
    final vocabRef = _firestore.collection('users').doc(uid).collection('vocabulary');
    final check = await vocabRef.where('word', isEqualTo: word).get();

    if (check.docs.isEmpty) {
      await vocabRef.add({
        'word': word,
        'meaning': meaning,
        'type': type,
        'mastered': false,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}