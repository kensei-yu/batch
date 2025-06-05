import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;

    return Scaffold(
      appBar: AppBar(title: const Text('利用規約')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '利用規約',
              style: TextStyle(
                fontSize: 22.0 * textScaleFactor, // 少し大きく
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: screenWidth * 0.05),
            _buildSectionTitle('第1条（適用）', textScaleFactor),
            _buildSectionContent(
              '''
1. 本規約は、当アプリの利用に関する権利義務関係を定めるものであり、当アプリを利用するすべての利用者に適用されます。
2. 利用者は本規約に同意したうえで、当アプリを利用するものとします。
              ''',
              textScaleFactor,
            ),
            SizedBox(height: screenWidth * 0.04),
            _buildSectionTitle('第2条（利用目的）', textScaleFactor),
            _buildSectionContent(
              '''
当アプリは、以下の目的で提供されます：
1. バンドメンバーの募集・マッチング
2. 音楽活動に関する情報共有・コミュニティ形成
3. その他、音楽活動をサポートする目的
              ''',
              textScaleFactor,
            ),
            SizedBox(height: screenWidth * 0.04),
            _buildSectionTitle('第3条（禁止事項）', textScaleFactor),
            _buildSectionContent(
              '''
利用者は、以下の行為を行ってはなりません：
1. 虚偽の情報を登録する行為
2. 他の利用者を誹謗中傷する行為
3. 営利目的の宣伝、スパム行為
4. 著作権、商標権、その他知的財産権を侵害する行為
5. 不適切なコンテンツの投稿（暴力的、わいせつ、差別的内容など）
6. その他、公序良俗に反する行為
              ''',
              textScaleFactor,
            ),
            SizedBox(height: screenWidth * 0.04),
            _buildSectionTitle('第4条（アカウントの登録と管理）', textScaleFactor),
            _buildSectionContent(
              '''
1. 利用者は、正確かつ最新の情報を登録するものとします。
2. アカウントの管理責任は利用者本人にあり、不正利用や第三者への譲渡は禁止します。
3. 違反行為が確認された場合、当アプリはアカウントを削除する権利を有します。
              ''',
              textScaleFactor,
            ),
            SizedBox(height: screenWidth * 0.04),
            _buildSectionTitle('第5条（個人情報の取り扱い）', textScaleFactor),
            _buildSectionContent(
              '''
1. 当アプリは、利用者の個人情報を適切に管理し、プライバシーポリシーに基づき取り扱います。
2. 個人情報は、利用目的の範囲内でのみ利用し、法令で認められた場合を除き、第三者に提供することはありません。
              ''',
              textScaleFactor,
            ),
            SizedBox(height: screenWidth * 0.04),
            _buildSectionTitle('第6条（免責事項）', textScaleFactor),
            _buildSectionContent(
              '''
1. 当アプリは、利用者間で発生したトラブルや損害について、一切の責任を負いません。
2. サーバー障害やメンテナンス等により当アプリの提供が一時的に停止する場合がありますが、それによる損害についても責任を負いません。
              ''',
              textScaleFactor,
            ),
            SizedBox(height: screenWidth * 0.04),
            _buildSectionTitle('第7条（規約の変更）', textScaleFactor),
            _buildSectionContent(
              '''
当アプリは、本規約を必要に応じて変更することがあります。変更後の利用規約は、当アプリ上に表示した時点で効力を生じるものとします。
              ''',
              textScaleFactor,
            ),
            SizedBox(height: screenWidth * 0.04),
            _buildSectionTitle('第8条（準拠法および管轄）', textScaleFactor),
            _buildSectionContent(
              '''
1. 本規約は、日本法に準拠します。
2. 当アプリに関連して生じた紛争については、運営者所在地を管轄する裁判所を専属的合意管轄とします。
              ''',
              textScaleFactor,
            ),
            SizedBox(height: screenWidth * 0.04),
            Text(
              '附則\nこの規約は、[公開日]から施行されます。\n\n', // TODO: [公開日]を実際の公開日に置き換えてください。
              style: TextStyle(fontSize: 14.0 * textScaleFactor, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, double textScaleFactor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18.0 * textScaleFactor, // 少し大きく
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionContent(String content, double textScaleFactor) {
    return Text(
      content.trim(), //前後の空白を除去
      style: TextStyle(
        fontSize: 15.0 * textScaleFactor, // 少し大きく
        height: 1.6, // 行間を調整
      ),
    );
  }
}