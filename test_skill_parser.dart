import 'lib/d_score_calculator.dart';

void main() {
  // テストデータ
  final testData = [
    {
      'name': '1回(1/2) ひねり倒立',
      'group': 'Ⅰ',
      'value_letter': 'A',
      'apparatus': 'FX'
    },
    {
      'name': 'テンポ宙返り',
      'group': 'Ⅲ',
      'value_letter': 'B',
      'apparatus': 'FX'
    },
    {
      'name': 'バタフライ',
      'group': 'Ⅰ',
      'value_letter': 'A',
      'apparatus': 'FX'
    },
    {
      'name': 'バタフライ2回ひねり',
      'group': 'Ⅰ',
      'value_letter': 'C',
      'apparatus': 'FX'
    },
    {
      'name': 'マンナ (2秒)から肩転位して倒立(2秒)',
      'group': 'Ⅰ',
      'value_letter': 'D',
      'apparatus': 'FX'
    },
  ];

  print('=== Skill Parser Test ===');
  
  for (final data in testData) {
    final skill = Skill.fromMap(data);
    print('技名: ${skill.name}');
    print('グループ: ${skill.group}');
    print('難度: ${skill.valueLetter}(${skill.value})');
    print('---');
  }
}