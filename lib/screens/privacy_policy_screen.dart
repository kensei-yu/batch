import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;

    return Scaffold(
      appBar: AppBar(title: const Text('プライバシーポリシー')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'プライバシーポリシー',
              style: TextStyle(
                fontSize: 22.0 * textScaleFactor,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: screenWidth * 0.05),
            _buildSectionTitle('第1条（適用範囲）', textScaleFactor),
            _buildSectionContent(
              '''
本ポリシーは、当アプリが提供するサービスにおいて、利用者の個人情報をどのように収集・利用・管理するかを定めるものです。
              ''',
              textScaleFactor,
            ),
            SizedBox(height: screenWidth * 0.04),
            _buildSectionTitle('第2条（取得する情報）', textScaleFactor),
            _buildSectionContent(
              '''
当アプリは、以下の情報を取得します：
1. 利用者が登録時に提供する情報（例：氏名、ニックネーム、メールアドレス、パスワード、プロフィール画像、性別、生年月日、自己紹介文）
2. 利用者のアクティビティに関連する情報（例：サービス内での操作履歴、投稿内容、チャットメッセージ）
3. デバイス情報（例：端末ID、IPアドレス、OS情報、ブラウザの種類、言語設定）
4. 位置情報（利用者が許可した場合）
5. 利用者が提供するその他の情報（例：お問い合わせ内容、アンケート回答）
              ''', // 収集する情報に合わせて具体的に記述
              textScaleFactor,
            ),
            SizedBox(height: screenWidth * 0.04),
            _buildSectionTitle('第3条（情報の利用目的）', textScaleFactor),
            _buildSectionContent(
              '''
当アプリは、取得した情報を以下の目的で利用します：
1. 本サービスの提供、運営、維持、改善のため
2. アカウント管理、本人確認、認証のため
3. 利用者からのお問い合わせ、サポート対応のため
4. 利用規約等に違反する行為への対応のため
5. 本サービスに関するお知らせ、アップデート情報、イベント情報等の通知のため
6. マーケティング調査、統計、分析のため（個人を特定できない形式で利用）
7. 新機能、新サービスの開発のため
8. 法令や規約に基づく対応のため
              ''', // 利用目的に合わせて具体的に記述
              textScaleFactor,
            ),
            SizedBox(height: screenWidth * 0.04),
            _buildSectionTitle('第4条（情報の管理）', textScaleFactor),
            _buildSectionContent(
              '''
1. 当アプリは、利用者の個人情報を適切に管理し、不正アクセス、紛失、破壊、改ざん、漏洩を防ぐために、組織的、物理的、人的、技術的に適切な安全管理措置を講じます。
2. 個人情報の保存期間は、利用目的に必要な範囲内とし、法令等に別途定めがある場合を除き、保存期間終了後、適切に廃棄・削除します。
              ''',
              textScaleFactor,
            ),
            SizedBox(height: screenWidth * 0.04),
            _buildSectionTitle('第5条（第三者への提供）', textScaleFactor),
            _buildSectionContent(
              '''
当アプリは、以下の場合を除き、あらかじめ利用者の同意を得ることなく、利用者の個人情報を第三者に提供することはありません：
1. 法令に基づく場合
2. 人の生命、身体または財産の保護のために必要がある場合であって、本人の同意を得ることが困難であるとき
3. 公衆衛生の向上または児童の健全な育成の推進のために特に必要がある場合であって、本人の同意を得ることが困難であるとき
4. 国の機関もしくは地方公共団体またはその委託を受けた者が法令の定める事務を遂行することに対して協力する必要がある場合であって、本人の同意を得ることにより当該事務の遂行に支障を及ぼすおそれがあるとき
5. 利用目的の達成に必要な範囲内において、個人情報の取扱いの全部または一部を委託する場合（この場合、委託先に対して必要かつ適切な監督を行います。）
6. 合併その他の事由による事業の承継に伴って個人情報が提供される場合
              ''',
              textScaleFactor,
            ),
            SizedBox(height: screenWidth * 0.04),
            _buildSectionTitle('第6条（クッキー（Cookie）等の使用について）', textScaleFactor),
            _buildSectionContent(
              '''
1. 当アプリは、サービスの利便性向上、利用状況の分析、広告配信等のためにクッキーおよび類似技術を使用することがあります。
2. クッキーの使用により収集される情報には、個人を特定する情報は含まれません。
3. 利用者は、ブラウザの設定によりクッキーの使用を無効化することができます。ただし、その場合、本サービスの一部機能が利用できなくなることがあります。
              ''',
              textScaleFactor,
            ),
            SizedBox(height: screenWidth * 0.04),
            _buildSectionTitle('第7条（情報の開示・訂正・削除等）', textScaleFactor),
            _buildSectionContent(
              '''
利用者は、当アプリが保有する自身の個人情報について、法令の定めるところにより、以下の請求を行うことができます。請求があった場合、本人確認を行ったうえで、合理的な期間および範囲内で対応します。
1. 開示請求
2. 訂正、追加または削除の請求
3. 利用停止または消去の請求
4. 第三者提供の停止請求
（手続きについては、末尾のお問い合わせ窓口までご連絡ください。）
              ''',
              textScaleFactor,
            ),
             SizedBox(height: screenWidth * 0.04),
            _buildSectionTitle('第8条（プライバシーポリシーの変更）', textScaleFactor),
            _buildSectionContent(
              '''
1. 当アプリは、法令等の改正や事業内容の変更等に対応するため、本ポリシーを改定することがあります。
2. 本ポリシーを改定した場合、当アプリ上での掲載その他の適切な方法により周知します。改定後のポリシーは、周知された時点から効力を生じるものとします。
              ''',
              textScaleFactor,
            ),
            SizedBox(height: screenWidth * 0.04),
            _buildSectionTitle('第9条（お問い合わせ窓口）', textScaleFactor),
            _buildSectionContent(
              '''
本ポリシーに関するお問い合わせは、以下の窓口までお願いいたします。
[運営者名またはサービス名]
[メールアドレス等の連絡先]
              ''', // TODO: 連絡先を記述
              textScaleFactor,
            ),
            SizedBox(height: screenWidth * 0.04),
            Text(
              '附則\nこのポリシーは、[公開日]から施行されます。\n\n', // TODO: [公開日]を実際の公開日に置き換えてください。
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
          fontSize: 18.0 * textScaleFactor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionContent(String content, double textScaleFactor) {
    return Text(
      content.trim(),
      style: TextStyle(
        fontSize: 15.0 * textScaleFactor,
        height: 1.6,
      ),
    );
  }
}