import 'dart:math';
import 'package:flutter/foundation.dart';

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
    final apparatus = map['apparatus']?.toString() ?? '';
    
    // デバッグ情報
    print('Skill.fromMap CSV Processing: name="$skillName", apparatus="$apparatus", raw_data=$map');
    
    // CSVからグループを正しく解析（ローマ数字対応）
    int groupNumber = _parseRomanNumeral(map['group']?.toString());
    
    // CSVから難度レターを取得
    final valueLetter = map['value_letter']?.toString() ?? '';
    
    // 難度レターから数値を計算
    double value;
    
    // 跳馬（VT）の場合は、value_letterを直接数値として解析
    if (apparatus == 'VT') {
      // 跳馬では value_letter が実際のD-score値（例: "1.8", "2.0"）
      try {
        value = double.parse(valueLetter);
        print('跳馬D-score解析: "$valueLetter" -> $value');
      } catch (e) {
        print('警告: 跳馬のD-score解析に失敗。技名="$skillName", 値="$valueLetter", デフォルト値=1.0を使用');
        value = 1.0; // 跳馬のデフォルト値
      }
    } else {
      // その他の種目では従来通り難度レター（A, B, C, etc.）として解析
      value = _parseValueLetter(valueLetter);
    }
    
    // フォールバック値（CSVデータが不正な場合のみ）
    if (groupNumber <= 0) {
      print('警告: グループが不正です。技名="$skillName", グループ="${map['group']}", デフォルト値=1を使用');
      groupNumber = 1;
    }
    
    if (value <= 0.0 || valueLetter.isEmpty) {
      if (apparatus == 'VT') {
        print('警告: 跳馬のD-scoreが不正です。技名="$skillName", 値="$valueLetter", デフォルト値=1.0を使用');
        value = 1.0;
      } else {
        print('警告: 難度が不正です。技名="$skillName", 難度レター="$valueLetter", デフォルト値=0.1を使用');
        value = 0.1;
      }
    }
    
    final finalValueLetter = valueLetter.isNotEmpty ? valueLetter : (apparatus == 'VT' ? '1.0' : 'A');
    
    // デバッグ情報
    print('Skill.fromMap CSV Result: name="$skillName", apparatus="$apparatus", group=$groupNumber, value=$value, letter=$finalValueLetter');

    return Skill(
      id: map['id']?.toString() ?? '',
      name: skillName,
      valueLetter: finalValueLetter,
      group: groupNumber,
      value: value,
      description: map['description']?.toString() ?? '',
      apparatus: apparatus,
    );
  }
}

class DScoreResult {
  final double totalDScore;
  final double difficultyValue;
  final double groupBonus;
  final double connectionBonus;
  final double neutralDeductions;
  final Map<String, double> deductionBreakdown;
  final int fulfilledGroups;
  final int requiredGroups;
  final int totalSkills;

  DScoreResult({
    this.totalDScore = 0.0,
    this.difficultyValue = 0.0,
    this.groupBonus = 0.0,
    this.connectionBonus = 0.0,
    this.neutralDeductions = 0.0,
    this.deductionBreakdown = const {},
    this.fulfilledGroups = 0,
    this.requiredGroups = 0,
    this.totalSkills = 0,
  });
}

// --- 定数定義 ---
const Map<String, Map<String, dynamic>> APPARATUS_RULES = {
    "FX": {"count_limit": 8, "groups_required": 4, "bonus_per_group": 0.5},
    "PH": {"count_limit": 8, "groups_required": 4, "bonus_per_group": 0.5},
    "SR": {"count_limit": 8, "groups_required": 4, "bonus_per_group": 0.5},
    "VT": {"count_limit": 1, "groups_required": 0, "bonus_per_group": 0.0},
    "PB": {"count_limit": 8, "groups_required": 4, "bonus_per_group": 0.5},
    "HB": {"count_limit": 8, "groups_required": 4, "bonus_per_group": 0.5},
};

// ニュートラルディダクション（技数不足による減点）ルール
// ルールブック6-3条「短い演技に対して」より
const Map<int, double> SKILL_COUNT_DEDUCTIONS = {
  8: 0.0,
  7: 0.0,
  6: 0.0,
  5: 3.0,
  4: 4.0,
  3: 5.0,
  2: 6.0,
  1: 7.0,
  0: 10.0,
};

/// 技数不足によるニュートラルディダクション（ND減点）を計算
double calculateNeutralDeductions(String apparatus, int skillCount) {
  // 跳馬はND減点の対象外
  if (apparatus == "VT") {
    return 0.0;
  }
  
  // 技数に応じた減点を取得
  return SKILL_COUNT_DEDUCTIONS[skillCount] ?? 10.0; // 0技の場合は10.0点減点
}

DScoreResult calculateDScore(String apparatus, List<List<Skill>> routine) {
  print('DEBUG_CALC: calculateDScore開始');
  print('DEBUG_CALC: apparatus: $apparatus');
  print('DEBUG_CALC: routine.length: ${routine.length}');
  
  if (routine.isEmpty || !APPARATUS_RULES.containsKey(apparatus)) {
    print('DEBUG_CALC: 早期終了 - routine空またはapparatus不正');
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
  
  // 跳馬はグループボーナスなし
  if (apparatus != "VT") {
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
      } else if (group == 5 && apparatus == "VT") {
        // 跳馬のグループ5: D難度以上で0.5点、C難度以下で0.3点（跳馬のみ）
        groupBonus += highestSkill.value >= 0.4 ? 0.5 : 0.3;
      }
    }
  }

  // 3. 連続技ボーナス
  double connectionBonus = 0.0;
  
  // 床運動の連続技ボーナス（FIG公式ルール準拠）
  if (apparatus == "FX") {
    for (final connectionGroup in routine) {
      if (connectionGroup.length > 1) {
        for (int i = 0; i < connectionGroup.length - 1; i++) {
          final skill1 = connectionGroup[i];
          final skill2 = connectionGroup[i + 1];
          
          // グループ1（技術系）は連続技ボーナス対象外
          if (skill1.group == 1 || skill2.group == 1) {
            continue;
          }
          
          // 「切り返し系」（前方系↔後方系）は連続技ボーナス対象外
          if ((skill1.group == 2 && skill2.group == 3) || (skill1.group == 3 && skill2.group == 2)) {
            continue;
          }
          
          // グループ4同士の連続は連続技ボーナス対象外
          if (skill1.group == 4 && skill2.group == 4) {
            continue;
          }
          
          final v1 = skill1.value;
          final v2 = skill2.value;
          
          // D難度以上 + D難度以上 = 0.2点
          if (v1 >= 0.4 && v2 >= 0.4) {
            connectionBonus += 0.2;
          }
          // D難度以上 + B/C難度 = 0.1点（双方向）
          else if ((v1 >= 0.4 && v2 >= 0.2 && v2 <= 0.3) || (v1 >= 0.2 && v1 <= 0.3 && v2 >= 0.4)) {
            connectionBonus += 0.1;
          }
        }
      }
    }
  }
  // 鉄棒の連続技ボーナス（FIG公式ルール準拠）
  else if (apparatus == "HB") {
    print('DEBUG_CALC: 鉄棒連続技ボーナス計算開始');
    print('DEBUG_CALC: routine.length: ${routine.length}');
    for (int groupIndex = 0; groupIndex < routine.length; groupIndex++) {
      final connectionGroup = routine[groupIndex];
      print('DEBUG_CALC: グループ$groupIndex, スキル数: ${connectionGroup.length}');
      if (connectionGroup.length > 1) {
        for (int i = 0; i < connectionGroup.length - 1; i++) {
          final skill1 = connectionGroup[i];
          final skill2 = connectionGroup[i + 1];
          final v1 = skill1.value;
          final v2 = skill2.value;
          print('DEBUG_CALC: ペア${i}-${i+1}: ${skill1.name}(G${skill1.group}, ${v1}) + ${skill2.name}(G${skill2.group}, ${v2})');
          double bonusForThisPair = 0.0;

          // 手放し技同士の連続（グループII同士）
          if (skill1.group == 2 && skill2.group == 2) {
            print('DEBUG_HB: 鉄棒手放し技連続: ${skill1.name}(難度値:${v1}, レター:${skill1.valueLetter}) + ${skill2.name}(難度値:${v2}, レター:${skill2.valueLetter})');
            print('DEBUG_HB: 条件チェック: v1(${v1}) >= 0.4? ${v1 >= 0.4}, v2(${v2}) >= 0.5? ${v2 >= 0.5}');
            print('DEBUG_HB: 逆方向チェック: v1(${v1}) >= 0.5? ${v1 >= 0.5}, v2(${v2}) >= 0.4? ${v2 >= 0.4}');
            
            // D難度以上 + E難度以上 = 0.20点（双方向）
            if ((v1 >= 0.4 && v2 >= 0.5) || (v1 >= 0.5 && v2 >= 0.4)) {
              bonusForThisPair = 0.2;
              print('DEBUG_HB: → 0.2点: D以上+E以上の条件にマッチ');
            }
            // D難度 + D難度 = 0.10点
            else if (v1 >= 0.4 && v2 >= 0.4) {
              bonusForThisPair = 0.1;
              print('DEBUG_HB: → 0.1点: D+Dの条件にマッチ');
            }
            // C難度 + D難度以上 = 0.10点（双方向）
            else if ((v1 == 0.3 && v2 >= 0.4) || (v1 >= 0.4 && v2 == 0.3)) {
              bonusForThisPair = 0.1;
              print('DEBUG_HB: → 0.1点: C+D以上の条件にマッチ');
            }
            else {
              print('DEBUG_HB: → 0.0点: 条件にマッチせず');
            }
          }
          // グループI/III技 + 手放し技（グループII）の連続
          else if ((skill1.group == 1 || skill1.group == 3) && skill2.group == 2) {
            // D難度以上(EGI/III) + E難度以上(手放し技) = 0.20点
            if (v1 >= 0.4 && v2 >= 0.5) {
              bonusForThisPair = 0.2;
            }
            // D難度以上(EGI/III) + D難度(手放し技) = 0.10点
            else if (v1 >= 0.4 && v2 >= 0.4) {
              bonusForThisPair = 0.1;
            }
          }
          // 手放し技（グループII） + グループI/III技の連続（双方向）
          else if (skill1.group == 2 && (skill2.group == 1 || skill2.group == 3)) {
            // E難度以上(手放し技) + D難度以上(EGI/III) = 0.20点
            if (v1 >= 0.5 && v2 >= 0.4) {
              bonusForThisPair = 0.2;
            }
            // D難度(手放し技) + D難度以上(EGI/III) = 0.10点
            else if (v1 >= 0.4 && v2 >= 0.4) {
              bonusForThisPair = 0.1;
            }
          }
          
          print('DEBUG_CALC: ペアボーナス: ${bonusForThisPair}');
          connectionBonus += bonusForThisPair;
        }
      }
    }
    print('DEBUG_CALC: 鉄棒連続技ボーナス合計: ${connectionBonus}');
  }

  // 連続技ボーナスの上限制限（FIG規則：最大0.4点まで）
  connectionBonus = connectionBonus > 0.4 ? 0.4 : connectionBonus;

  // 4. ニュートラルディダクション（ND）減点の計算
  final neutralDeductions = calculateNeutralDeductions(apparatus, allSkills.length);
  final deductionBreakdown = <String, double>{};
  
  if (neutralDeductions > 0.0) {
    deductionBreakdown['技数不足'] = neutralDeductions;
  }

  // 5. 最終Dスコア（ND減点適用後）
  final baseDScore = difficultyValue + groupBonus + connectionBonus;
  final totalDScore = baseDScore - neutralDeductions;

  return DScoreResult(
    totalDScore: totalDScore,
    difficultyValue: difficultyValue,
    groupBonus: groupBonus,
    connectionBonus: connectionBonus,
    neutralDeductions: neutralDeductions,
    deductionBreakdown: deductionBreakdown,
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
  // 跳馬はグループボーナスなし
  if (apparatus == "VT") {
    return 0.0;
  }
  
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
    }
    // グループ5は跳馬のみなので、ここでは処理しない（上でVTチェック済み）
  }
  
  return groupBonus;
} 