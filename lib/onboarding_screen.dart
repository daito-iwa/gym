import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// オンボーディング画面のデータモデル
class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> features;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.features,
  });
}

// オンボーディング画面メイン
class OnboardingScreen extends StatefulWidget {
  final Function() onCompleted;

  const OnboardingScreen({
    Key? key,
    required this.onCompleted,
  }) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // オンボーディングページのデータ
  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Gymnastics AI へようこそ',
      description: 'プロレベルの体操競技採点システムで\n演技の可能性を最大化しよう',
      icon: Icons.sports_gymnastics,
      color: Colors.blue,
      features: [
        '正確なD-スコア計算',
        '全種目対応の技データベース',
        'AI搭載のコーチングアシスタント',
      ],
    ),
    OnboardingPage(
      title: '技の検索と分析',
      description: '35,000以上の技から最適な演技構成を\n簡単に作成できます',
      icon: Icons.search,
      color: Colors.green,
      features: [
        '難度別・グループ別検索',
        'リアルタイム難度計算',
        '連続技ボーナス自動算出',
      ],
    ),
    OnboardingPage(
      title: 'AIコーチング',
      description: 'AI搭載のコーチがあなたの演技を\n分析して改善提案を行います',
      icon: Icons.psychology,
      color: Colors.purple,
      features: [
        '演技構成の最適化提案',
        '技の組み合わせアドバイス',
        '採点ルールの詳細解説',
      ],
    ),
    OnboardingPage(
      title: 'プレミアム機能',
      description: 'より高度な機能で競技力を\n次のレベルに引き上げよう',
      icon: Icons.star,
      color: Colors.amber,
      features: [
        '無制限AIチャット',
        '詳細分析レポート',
        '広告なしの快適な体験',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    HapticFeedback.lightImpact();
    
    // オンボーディング完了をローカルに保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    // アニメーション付きで画面を閉じる
    await _animationController.reverse();
    
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ヘッダー（スキップボタン）
            _buildHeader(),
            
            // メインコンテンツ
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  _animationController.reset();
                  _animationController.forward();
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),
            
            // ページインジケーター
            _buildPageIndicator(),
            
            const SizedBox(height: 20),
            
            // ナビゲーションボタン
            _buildNavigationButtons(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ロゴ
          Row(
            children: [
              Icon(
                Icons.sports_gymnastics,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Gymnastics AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          // スキップボタン
          if (_currentPage < _pages.length - 1)
            GestureDetector(
              onTap: _skipOnboarding,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[600]!),
                ),
                child: Text(
                  'スキップ',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // アイコン
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: page.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(
                    color: page.color.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Icon(
                  page.icon,
                  size: 60,
                  color: page.color,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // タイトル
              Text(
                page.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 20),
              
              // 説明
              Text(
                page.description,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // 機能リスト
              Column(
                children: page.features.map((feature) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: page.color,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: _currentPage == index ? 24 : 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? _pages[_currentPage].color
                : Colors.grey[600],
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Row(
        children: [
          // 戻るボタン
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[600]!),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('戻る'),
              ),
            ),
          
          if (_currentPage > 0) const SizedBox(width: 16),
          
          // 次へ・開始ボタン
          Expanded(
            flex: _currentPage == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: _pages[_currentPage].color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                _currentPage == _pages.length - 1 ? '開始する' : '次へ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// オンボーディング完了チェック用のユーティリティクラス
class OnboardingUtils {
  static const String _onboardingKey = 'onboarding_completed';
  
  // オンボーディングが完了しているかチェック
  static Future<bool> isOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingKey) ?? false;
    } catch (e) {
      print('Error checking onboarding status: $e');
      return false;
    }
  }
  
  // オンボーディング状態をリセット（デバッグ用）
  static Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingKey);
    } catch (e) {
      print('Error resetting onboarding: $e');
    }
  }
  
  // オンボーディング完了をマーク
  static Future<void> markOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, true);
    } catch (e) {
      print('Error marking onboarding completed: $e');
    }
  }
}