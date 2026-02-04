import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MatchingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ユーザーを「いいね」する
  /// マッチングが成立した場合は true を返す
  Future<bool> likeUser(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not logged in');
    final currentUserId = currentUser.uid;

    // 1. likes コレクションに保存
    await _firestore.collection('likes').add({
      'fromUserId': currentUserId,
      'toUserId': targetUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. 相手も自分をいいねしているか確認 (Mutual Match Check)
    // 相手が自分をいいねした記録があるか
    final mutualLikeQuery = await _firestore
        .collection('likes')
        .where('fromUserId', isEqualTo: targetUserId)
        .where('toUserId', isEqualTo: currentUserId)
        .limit(1)
        .get();

    if (mutualLikeQuery.docs.isNotEmpty) {
      // マッチング成立！
      await _createMatch(currentUserId, targetUserId);
      return true;
    }

    return false;
  }

  /// マッチング成立時の処理
  Future<void> _createMatch(String userA, String userB) async {
    // matches コレクションにドキュメント作成
    await _firestore.collection('matches').add({
      'users': [userA, userB],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }

  /// マッチング候補のユーザーを取得する
  /// 自分以外、かつまだ「いいね」していないユーザーを取得
  Future<List<Map<String, dynamic>>> getCandidates() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    // 1. 自分が既にいいねしたユーザーIDを取得
    final likedUserIds = await getLikedUserIds();

    // 2. 全ユーザーを取得 (本番では limit や cursor を使うべき)
    final snapshot = await _firestore.collection('users').get();

    // 3. フィルタリング
    return snapshot.docs
        .where((doc) {
          final uid = doc.id;
          if (uid == currentUser.uid) return false; // 自分自身
          if (likedUserIds.contains(uid)) return false; // 既にいいね済み
          return true;
        })
        .map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        })
        .toList();
  }
  
  /// 自分が「いいね」したユーザーIDのリストを取得（1回だけ取得）
  Future<List<String>> getLikedUserIds() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    final snapshot = await _firestore
        .collection('likes')
        .where('fromUserId', isEqualTo: currentUser.uid)
        .get();

    return snapshot.docs.map((doc) => doc['toUserId'] as String).toList();
  }
}
