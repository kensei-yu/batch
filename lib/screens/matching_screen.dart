import 'dart:convert';
import 'package:batch/services/matching_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'match_dialog.dart';

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({Key? key}) : super(key: key);

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  final MatchingService _matchingService = MatchingService();
  final CardSwiperController _swiperController = CardSwiperController();
  
  List<Map<String, dynamic>> _candidates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    // Disabled
  }

  // ... (Keep helper methods if needed but body won't use them)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('さがす'),
        // actions removed
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text('現在機能を調整中です', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}