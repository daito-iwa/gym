import 'dart:math';

// ローマ数字変換関数
int _parseRomanNumeral(String? roman) {
  if (roman == null || roman.isEmpty) return 0;
  
  final romanToInt = {
    'Ⅰ': 1, 'I': 1,
    'Ⅱ': 2, 'II': 2,
    'Ⅲ': 3, 'III': 3,
    'Ⅳ': 4, 'IV': 4,
    'Ⅴ': 5, 'V': 5,
  };
  
  return romanToInt[roman.trim()] ?? 0;
}

// 難度レター変換関数
double _parseValueLetter(String? letter) {
  if (letter == null || letter.isEmpty) return 0.0;
  
  final letterToValue = {
    'A': 0.1,
    'B': 0.2,
    'C': 0.3,
    'D': 0.4,
    'E': 0.5,
    'F': 0.6,
    'G': 0.7,
    'H': 0.8,
    'I': 0.9,
    'J': 1.0,
  };
  
  return letterToValue[letter.trim().toUpperCase()] ?? 0.0;
}

// Skillクラスはd_score_calculator.dartに移動し、main.dartからはインポートして使うようにする
class Skill {
  final String id;
  final String name;
  final String valueLetter;
  final int group;
  final double value;
  final String description;
  final String apparatus;

  Skill({
    required this.id,
    required this.name,
    required this.valueLetter,
    required this.group,
    required this.value,
    required this.description,
    required this.apparatus,
  });

 factory Skill.fromMap(Map<String, dynamic> map) {
    final skillName = map['name']?.toString() ?? '';
    
    // デバッグ情報
    print('Skill.fromMap CSV Processing: name="$skillName", raw_data=$map');
    
    // CSVからグループを正しく解析（ローマ数字対応）
    int groupNumber = _parseRomanNumeral(map['group']?.toString());
    
    // CSVから難度レターを取得
    final valueLetter = map['value_letter']?.toString() ?? '';
    
    // 難度レターから数値を計算
    double value = _parseValueLetter(valueLetter);
    
    // フォールバック値（CSVデータが不正な場合のみ）
    if (groupNumber <= 0) {
      print('警告: グループが不正です。技名="$skillName", グループ="${map['group']}", デフォルト値=1を使用');
      groupNumber = 1;
    }
    
    if (value <= 0.0 || valueLetter.isEmpty) {
      print('警告: 難度が不正です。技名="$skillName", 難度レター="$valueLetter", デフォルト値=0.1を使用');
      value = 0.1;
    }
    
    final finalValueLetter = valueLetter.isNotEmpty ? valueLetter : 'A';
    
    // デバッグ情報
    print('Skill.fromMap CSV Result: name="$skillName", group=$groupNumber, value=$value, letter=$finalValueLetter');

    return Skill(
      id: map['id']?.toString() ?? '',
      name: skillName,
      valueLetter: finalValueLetter,
      group: groupNumber,
      value: value,
      description: map['description']?.toString() ?? '',
      apparatus: map['apparatus']?.toString() ?? '',
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

  // 技数が上限を超える場合、グループボーナスも考慮した最適な組み合わせを探す
  List<Skill> countedSkills;
  if (allSkills.length > countLimit) {
      countedSkills = _selectOptimalSkillCombination(allSkills, countLimit, rules);
  } else {
      countedSkills = allSkills;
  }

  // 1. 難度点の合計
  final difficultyValue = countedSkills.fold<double>(0.0, (sum, skill) => sum + skill.value);

  // 2. グループ要求ボーナス
  final fulfilledGroupsSet = countedSkills.map((skill) => skill.group).toSet();
  final numFulfilledGroups = fulfilledGroupsSet.length;
  
  // グループごとの最高難度技を特定
  final Map<int, Skill> highestSkillPerGroup = {};
  for (final skill in countedSkills) {
    if (!highestSkillPerGroup.containsKey(skill.group) ||
        skill.value > highestSkillPerGroup[skill.group]!.value) {
      highestSkillPerGroup[skill.group] = skill;
    }
  }
  
  // グループボーナス計算（FIG公式ルール）
  double groupBonus = 0.0;
  for (final entry in highestSkillPerGroup.entries) {
    final group = entry.key;
    final highestSkill = entry.value;
    
    if (group == 1) {
      // グループ1: 無条件で0.5点
      groupBonus += 0.5;
    } else if (group == 2 || group == 3) {
      // グループ2,3: D難度以上で0.5点、C難度以下で0.3点
      groupBonus += highestSkill.value >= 0.4 ? 0.5 : 0.3;
    } else if (group == 4) {
      if (apparatus == "FX") {
        // 床運動: グループ4も通常ルール（D以上0.5、C以下0.3）※終末技概念なし
        groupBonus += highestSkill.value >= 0.4 ? 0.5 : 0.3;
      } else {
        // その他種目: グループ4は終末技、技の難度値をそのまま加算
        groupBonus += highestSkill.value;
      }
    } else if (group == 5) {
      // グループ5: D難度以上で0.5点、C難度以下で0.3点
      groupBonus += highestSkill.value >= 0.4 ? 0.5 : 0.3;
    }
  }

  // 3. 連続技ボーナス
  double connectionBonus = 0.0;
  
  // 床運動の連続技ボーナス
  if (apparatus == "FX") {
    for (final connectionGroup in routine) {
      if (connectionGroup.length > 1) {
        for (int i = 0; i < connectionGroup.length - 1; i++) {
          final skill1 = connectionGroup[i];
          final skill2 = connectionGroup[i + 1];
          
          // グループ2,3,4の技のみ（グループ1は除外）
          if ((skill1.group == 2 || skill1.group == 3 || skill1.group == 4) &&
              (skill2.group == 2 || skill2.group == 3 || skill2.group == 4)) {
            
            // グループ4同士の連続は除外
            if (skill1.group == 4 && skill2.group == 4) {
              continue;
            }
            
            final v1 = skill1.value;
            final v2 = skill2.value;
            
            // D+D以上 = 0.2点
            if (v1 >= 0.4 && v2 >= 0.4) {
              connectionBonus += 0.2;
            }
            // D+B/C または B/C+D = 0.1点
            else if ((v1 >= 0.4 && v2 >= 0.2) || (v1 >= 0.2 && v2 >= 0.4)) {
              connectionBonus += 0.1;
            }
          }
        }
      }
    }
  }
  // 鉄棒の連続技ボーナス
  else if (apparatus == "HB") {
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

  // 連続技ボーナスの上限制限（FIGルール：最大0.4点）
  connectionBonus = connectionBonus > 0.4 ? 0.4 : connectionBonus;

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

/// 技数上限を超える場合の最適な技の組み合わせを選択する関数
/// グループボーナスと難度点の合計を最大化する
List<Skill> _selectOptimalSkillCombination(List<Skill> allSkills, int countLimit, Map<String, dynamic> rules) {
  if (allSkills.length <= countLimit) {
    return allSkills;
  }

  // 器具の種類を特定（関数の外から渡すのが理想だが、ここでは推定）
  String apparatus = "FX"; // デフォルト
  if (allSkills.isNotEmpty) {
    apparatus = allSkills.first.apparatus;
  }
  
  // 各グループごとに技をソートして整理
  final Map<int, List<Skill>> skillsByGroup = {};
  for (final skill in allSkills) {
    skillsByGroup.putIfAbsent(skill.group, () => []).add(skill);
  }
  
  // 各グループ内で価値順にソート
  for (final groupSkills in skillsByGroup.values) {
    groupSkills.sort((a, b) => b.value.compareTo(a.value));
  }
  
  double bestScore = 0.0;
  List<Skill> bestCombination = [];
  
  // 可能な組み合わせを探索（グリーディアプローチ + 局所探索）
  // まずは各グループから最低1つずつ選んで、残りを価値順で埋める戦略
  final groups = skillsByGroup.keys.toList();
  
  for (int minSkillsPerGroup = 0; minSkillsPerGroup <= 2; minSkillsPerGroup++) {
    final combination = <Skill>[];
    final usedGroups = <int>{};
    
    // 各グループから最低限の技を選択
    for (final group in groups) {
      final groupSkills = skillsByGroup[group]!;
      final skillsToTake = minSkillsPerGroup < groupSkills.length ? minSkillsPerGroup : groupSkills.length;
      for (int i = 0; i < skillsToTake && combination.length < countLimit; i++) {
        combination.add(groupSkills[i]);
        usedGroups.add(group);
      }
    }
    
    // 残り枠を価値の高い技で埋める
    final remainingSkills = <Skill>[];
    for (final entry in skillsByGroup.entries) {
      final group = entry.key;
      final groupSkills = entry.value;
      final skipCount = usedGroups.contains(group) ? minSkillsPerGroup : 0;
      for (int i = skipCount; i < groupSkills.length; i++) {
        remainingSkills.add(groupSkills[i]);
      }
    }
    
    remainingSkills.sort((a, b) => b.value.compareTo(a.value));
    
    for (final skill in remainingSkills) {
      if (combination.length >= countLimit) break;
      combination.add(skill);
      usedGroups.add(skill.group);
    }
    
    // スコアを計算
    final difficultyValue = combination.fold<double>(0.0, (sum, skill) => sum + skill.value);
    
    // FIG公式ルールに基づくグループボーナス計算
    double groupBonus = _calculateFIGGroupBonus(combination, apparatus);
    
    final totalScore = difficultyValue + groupBonus;
    
    if (totalScore > bestScore) {
      bestScore = totalScore;
      bestCombination = List.from(combination);
    }
  }
  
  // フォールバック: 単純に価値順で選択
  if (bestCombination.isEmpty) {
    final sortedSkills = List<Skill>.from(allSkills);
    sortedSkills.sort((a, b) => b.value.compareTo(a.value));
    bestCombination = sortedSkills.sublist(0, countLimit);
  }
  
  return bestCombination;
}

/// FIG公式ルールに基づくグループボーナス計算関数
double _calculateFIGGroupBonus(List<Skill> skills, String apparatus) {
  // グループごとの最高難度技を特定
  final Map<int, Skill> highestSkillPerGroup = {};
  for (final skill in skills) {
    if (!highestSkillPerGroup.containsKey(skill.group) ||
        skill.value > highestSkillPerGroup[skill.group]!.value) {
      highestSkillPerGroup[skill.group] = skill;
    }
  }
  
  // グループボーナス計算（FIG公式ルール）
  double groupBonus = 0.0;
  for (final entry in highestSkillPerGroup.entries) {
    final group = entry.key;
    final highestSkill = entry.value;
    
    if (group == 1) {
      // グループ1: 無条件で0.5点
      groupBonus += 0.5;
    } else if (group == 2 || group == 3) {
      // グループ2,3: D難度以上で0.5点、C難度以下で0.3点
      groupBonus += highestSkill.value >= 0.4 ? 0.5 : 0.3;
    } else if (group == 4) {
      if (apparatus == "FX") {
        // 床運動: グループ4も通常ルール（D以上0.5、C以下0.3）※終末技概念なし
        groupBonus += highestSkill.value >= 0.4 ? 0.5 : 0.3;
      } else {
        // その他種目: グループ4は終末技、技の難度値をそのまま加算
        groupBonus += highestSkill.value;
      }
    } else if (group == 5) {
      // グループ5: D難度以上で0.5点、C難度以下で0.3点
      groupBonus += highestSkill.value >= 0.4 ? 0.5 : 0.3;
    }
  }
  
  return groupBonus;
} 