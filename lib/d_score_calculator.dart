import 'dart:math';

// Skillクラスはd_score_calculator.dartに移動し、main.dartからはインポートして使うようにする
class Skill {
  final String name;
  final String valueLetter;
  final int group;
  final double value;

  Skill({
    required this.name,
    required this.valueLetter,
    required this.group,
    required this.value,
  });

 factory Skill.fromMap(Map<String, dynamic> map) {
    const difficultyValues = { "A": 0.1, "B": 0.2, "C": 0.3, "D": 0.4, "E": 0.5, "F": 0.6, "G": 0.7, "H": 0.8, "I": 0.9, "J": 1.0 };
    final romanMap = {'I': 1, 'II': 2, 'III': 3, 'IV': 4, 'V': 5};
    final groupStr = map['group']?.toString() ?? '';
    final groupRoman = groupStr.replaceAll('Group ', '');
    final groupNumber = romanMap[groupRoman] ?? 0;

    return Skill(
      name: map['name']?.toString() ?? '',
      valueLetter: map['value_letter']?.toString() ?? '',
      group: groupNumber,
      value: difficultyValues[map['value_letter']] ?? 0.0,
    );
  }
}

class DScoreResult {
  final double totalDScore;
  final double difficultyValue;
  final double groupBonus;
  final double connectionBonus;
  final int fulfilledGroups;
  final int requiredGroups;
  final int totalSkills;

  DScoreResult({
    this.totalDScore = 0.0,
    this.difficultyValue = 0.0,
    this.groupBonus = 0.0,
    this.connectionBonus = 0.0,
    this.fulfilledGroups = 0,
    this.requiredGroups = 0,
    this.totalSkills = 0,
  });
}

// --- 定数定義 ---
const Map<String, Map<String, dynamic>> APPARATUS_RULES = {
    "FX": {"count_limit": 8, "groups_required": 4, "bonus_per_group": 0.5},
    "PH": {"count_limit": 8, "groups_required": 5, "bonus_per_group": 0.5},
    "SR": {"count_limit": 8, "groups_required": 4, "bonus_per_group": 0.5},
    "VT": {"count_limit": 1, "groups_required": 0, "bonus_per_group": 0.0},
    "PB": {"count_limit": 8, "groups_required": 5, "bonus_per_group": 0.5},
    "HB": {"count_limit": 8, "groups_required": 5, "bonus_per_group": 0.5},
};

DScoreResult calculateDScore(String apparatus, List<List<Skill>> routine) {
  if (routine.isEmpty || !APPARATUS_RULES.containsKey(apparatus)) {
    return DScoreResult();
  }

  final rules = APPARATUS_RULES[apparatus]!;
  final countLimit = rules['count_limit'] as int;

  // 構成内の全ての技をフラットなリストにする
  final allSkills = routine.expand((group) => group).toList();

  // TODO: 技数が上限を超える場合、最適な組み合わせを探すロジックを実装する
  // 今回は、上限を超えた場合は価値の高い順に技を選択する簡易的な実装を行う
  List<Skill> countedSkills;
  if (allSkills.length > countLimit) {
      allSkills.sort((a, b) => b.value.compareTo(a.value));
      countedSkills = allSkills.sublist(0, countLimit);
  } else {
      countedSkills = allSkills;
  }

  // 1. 難度点の合計
  final difficultyValue = countedSkills.fold<double>(0.0, (sum, skill) => sum + skill.value);

  // 2. グループ要求ボーナス
  final fulfilledGroupsSet = countedSkills.map((skill) => skill.group).toSet();
  final numFulfilledGroups = fulfilledGroupsSet.length;
  final groupBonus = numFulfilledGroups * (rules["bonus_per_group"] as double);

  // 3. 連続技ボーナス
  double connectionBonus = 0.0;
  if (apparatus == "HB") {
    for (final connectionGroup in routine) {
      if (connectionGroup.length > 1) {
        for (int i = 0; i < connectionGroup.length - 1; i++) {
          final skill1 = connectionGroup[i];
          final skill2 = connectionGroup[i + 1];
          final v1 = skill1.value;
          final v2 = skill2.value;
          double bonusForThisPair = 0.0;

          // ルールセット1: 「離れ技」同士の連続 (G2 -> G2)
          if (skill1.group == 2 && skill2.group == 2) {
            if ((v1 >= 0.4 && v2 >= 0.5) || (v1 >= 0.5 && v2 >= 0.4)) { // D+E, E+D
              bonusForThisPair = 0.2;
            } else if (v1 >= 0.4 && v2 >= 0.4) { // D+D
              bonusForThisPair = 0.1;
            } else if ((v1 == 0.3 && v2 >= 0.4) || (v1 >= 0.4 && v2 == 0.3)) { // C+D, D+C
              bonusForThisPair = 0.1;
            }
          }
          // ルールセット2: 「グループI/III」と「グループII」の接続
          else {
            final isS1G1Or3 = skill1.group == 1 || skill1.group == 3;
            final isS2G1Or3 = skill2.group == 1 || skill2.group == 3;
            final isS1G2 = skill1.group == 2;
            final isS2G2 = skill2.group == 2;

            if ((isS1G1Or3 && isS2G2) || (isS1G2 && isS2G1Or3)) {
              final vG1Or3 = isS1G1Or3 ? v1 : v2;
              final vG2 = isS1G2 ? v1 : v2;

              if (vG1Or3 >= 0.4 && vG2 >= 0.5) { // D以上 + E以上
                bonusForThisPair = 0.2;
              } else if (vG1Or3 >= 0.4 && vG2 >= 0.4) { // D以上 + D以上
                bonusForThisPair = 0.1;
              }
            }
          }
          connectionBonus += bonusForThisPair;
        }
      }
    }
  }

  // 4. 最終Dスコア
  final totalDScore = difficultyValue + groupBonus + connectionBonus;

  return DScoreResult(
    totalDScore: totalDScore,
    difficultyValue: difficultyValue,
    groupBonus: groupBonus,
    connectionBonus: connectionBonus,
    fulfilledGroups: numFulfilledGroups,
    requiredGroups: rules["groups_required"] as int,
    totalSkills: allSkills.length,
  );
} 