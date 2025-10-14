// lib/screens/matching_screen.dart


import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'matching_onboarding_screen.dart';
import 'match_dialog.dart';

// URLかBase64かを判定してImageProviderを返すヘルパー
ImageProvider? _getImageProvider(String? data) {
  if (data == null || data.isEmpty) return null;
  if (data.startsWith('http')) return NetworkImage(data);
  try { return MemoryImage(base64Decode(data)); } catch (e) { return null; }
}

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({Key? key}) : super(key: key);

  @override
  _MatchingScreenState createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;
  final CardSwiperController _swiperController = CardSwiperController();
  
  List<Map<String, dynamic>> _candidates = [];
  bool _isLoading = true;
  Map<String, dynamic>? _myPreferences;
  Map<String, dynamic>? _myProfile;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    if (_currentUser == null) return;
    
    final myProfileDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
    final myPrefDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).collection('preferences').doc('matching').get();

    if (!myProfileDoc.exists || !myPrefDoc.exists) {
      if(mounted) setState(() => _isLoading = false);
      return;
    }

    _myProfile = myProfileDoc.data();
    _myPreferences = myPrefDoc.data();

    await _fetchCandidates();
  }

  Future<void> _fetchCandidates() async {
    if (_currentUser == null || _myPreferences == null) return;
    if(mounted) setState(() => _isLoading = true);

    final usersRef = FirebaseFirestore.instance.collection('users');

    final likedDocs = await usersRef.doc(_currentUser!.uid).collection('likes').get();
    final passedDocs = await usersRef.doc(_currentUser!.uid).collection('passes').get();
    final swipedUserIds = {...likedDocs.docs.map((d) => d.id), ...passedDocs.docs.map((d) => d.id), _currentUser!.uid};

    final allUsersSnapshot = await usersRef.get();
    
    List<Map<String, dynamic>> potentialCandidates = [];
    for (var doc in allUsersSnapshot.docs) {
      if (!swipedUserIds.contains(doc.id)) {
        potentialCandidates.add({'uid': doc.id, ...doc.data()});
      }
    }

    potentialCandidates.shuffle();

    if(mounted) {
      setState(() {
        _candidates = potentialCandidates;
        _isLoading = false;
      });
    }
  }

  bool _onSwipe(int oldIndex, int? newIndex, CardSwiperDirection direction) {
    if (_currentUser == null) return false;
    final swipedUserId = _candidates[oldIndex]['uid'];

    if (direction == CardSwiperDirection.left) {
      _handlePass(swipedUserId);
    } else if (direction == CardSwiperDirection.right) {
      _handleLike(swipedUserId);
    }
    return true;
  }

  Future<void> _handlePass(String passedUserId) async {
    if (_currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(_currentUser!.uid)
        .collection('passes').doc(passedUserId)
        .set({'timestamp': FieldValue.serverTimestamp()});
  }

  Future<void> _handleLike(String likedUserId) async {
    if (_currentUser == null || _myProfile == null) return;

    await FirebaseFirestore.instance
        .collection('users').doc(_currentUser!.uid)
        .collection('likes').doc(likedUserId)
        .set({'timestamp': FieldValue.serverTimestamp()});

    final doc = await FirebaseFirestore.instance
        .collection('users').doc(likedUserId)
        .collection('likes').doc(_currentUser!.uid).get();

    if (doc.exists) {
      final peerUserDoc = await FirebaseFirestore.instance.collection('users').doc(likedUserId).get();
      if(peerUserDoc.exists && mounted) {
        showMatchDialog(
          context: context,
          myImageUrl: _myProfile!['imageUrl'] ?? '',
          peerUser: {'uid': peerUserDoc.id, ...peerUserDoc.data()!},
        );
      }
    }
  }

  Future<void> _navigateToOnboarding() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const MatchingOnboardingScreen()),
    );
    if (result == true) {
      _loadInitialData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: Text('ログインしてください')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('メンバーを探す'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final bool hasCompletedOnboarding = userData?['hasCompletedMatchingOnboarding'] ?? false;

          if (!hasCompletedOnboarding) {
            return _buildOnboardingPrompt();
          }

          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_candidates.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Text('現在募集はありません'),
                   const SizedBox(height: 20),
                   ElevatedButton(
                    onPressed: _fetchCandidates,
                    child: const Text('再読み込み'),
                  )
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: CardSwiper(
                  controller: _swiperController,
                  cardsCount: _candidates.length,
                  numberOfCardsDisplayed: _candidates.length < 2 ? 1 : 2,
                  onSwipe: _onSwipe,
                  padding: const EdgeInsets.all(24.0),
                  cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                    final candidate = _candidates[index];
                    // ▼▼▼【ここから修正】画像表示部分の変更 ▼▼▼
                    final candidateImageProvider = _getImageProvider(candidate['imageUrl']);
                    return Card(
                      elevation: 4.0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      clipBehavior: Clip.hardEdge,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: candidateImageProvider != null
                                ? Image(image: candidateImageProvider, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _buildPlaceholderCard())
                                : _buildPlaceholderCard(),
                          ),
                          // ▲▲▲【ここまで修正】▲▲▲
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                                begin: Alignment.bottomCenter,
                                end: Alignment.center,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 20,
                            left: 20,
                            right: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  candidate['nickname'] ?? '名無しさん',
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2)]),
                                ),
                                if (candidate['bio'] != null && candidate['bio'].isNotEmpty)
                                  Text(
                                    candidate['bio'],
                                    style: const TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(blurRadius: 2)]),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 40),
                      onPressed: () => _swiperController.swipe(CardSwiperDirection.left),
                    ),
                    IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.green, size: 40),
                      onPressed: () => _swiperController.swipe(CardSwiperDirection.right),
                    ),
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderCard() {
    return Container(color: Colors.grey[300], child: const Icon(Icons.person, size: 100, color: Colors.grey));
  }

  Widget _buildOnboardingPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text('はじめに、あなたの好みを教えてください', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('最適なマッチングのために、あなたの担当パートや好きなジャンルなどを設定します。', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _navigateToOnboarding,
              child: const Text('設定を始める'),
            ),
          ],
        ),
      ),
    );
  }
}