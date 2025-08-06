import 'dart:convert';
import 'dart:io';

// Copy the parsing functions from the app
int _parseRomanNumeral(String? roman) {
  if (roman == null || roman.isEmpty) {
    return 0;
  }
  
  final romanToInt = {
    'Ⅰ': 1, 'I': 1,
    'Ⅱ': 2, 'II': 2,
    'Ⅲ': 3, 'III': 3,
    'Ⅳ': 4, 'IV': 4,
    'Ⅴ': 5, 'V': 5,
  };
  
  final trimmed = roman.trim();
  return romanToInt[trimmed] ?? 0;
}

double _parseValueLetter(String? letter) {
  if (letter == null || letter.isEmpty) {
    return 0.0;
  }
  
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

// Copy the Skill creation logic from the app
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
    
    // CSVからグループを正しく解析（ローマ数字対応）
    int groupNumber = _parseRomanNumeral(map['group']?.toString());
    
    // CSVから難度レターを取得
    final valueLetter = map['value_letter']?.toString() ?? '';
    
    // 難度レターから数値を計算
    double value;
    
    // 跳馬（VT）の場合は、value_letterを直接数値として解析
    if (apparatus == 'VT') {
      try {
        value = double.parse(valueLetter);
      } catch (e) {
        value = 1.0;
      }
    } else {
      value = _parseValueLetter(valueLetter);
    }
    
    // フォールバック値（CSVデータが不正な場合のみ）
    if (groupNumber <= 0) {
      print('🚨 GROUP FALLBACK TRIGGERED for: ${map['group']} (${map['group'].runtimeType})');
      groupNumber = 1;
    }
    
    if (value <= 0.0 || valueLetter.isEmpty) {
      print('🚨 VALUE FALLBACK TRIGGERED for: ${valueLetter}');
      if (apparatus == 'VT') {
        value = 1.0;
      } else {
        value = 0.1;
      }
    }
    
    final finalValueLetter = valueLetter.isNotEmpty ? valueLetter : (apparatus == 'VT' ? '1.0' : 'A');

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

String _convertGroupToRoman(int group) {
  switch (group) {
    case 1: return 'Ⅰ';
    case 2: return 'Ⅱ';
    case 3: return 'Ⅲ';
    case 4: return 'Ⅳ';
    case 5: return 'Ⅴ';
    default: return 'Ⅰ';
  }
}

void main() async {
  print('Testing cache serialization/deserialization fix...');
  print('=' * 60);
  
  // Simulate loading from CSV (like the original flow)
  final file = File('/Users/iwasakihiroto/Desktop/gym/data/skills_ja.csv');
  final content = await file.readAsString();
  final lines = content.split('\n');
  
  final originalSkills = <Skill>[];
  
  // Parse HB skills from CSV (first 20 for testing)
  int hbCount = 0;
  for (int i = 1; i < lines.length && hbCount < 20; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    
    final parts = line.split(',');
    if (parts.length >= 4 && parts[0] == 'HB') {
      hbCount++;
      
      final skill = Skill.fromMap({
        'id': 'SKILL_${i.toString().padLeft(3, '0')}',
        'apparatus': parts[0],
        'name': parts[1],
        'group': parts[2],  // Roman numeral from CSV
        'value_letter': parts[3],  // Difficulty letter from CSV
        'description': parts[1],
      });
      
      originalSkills.add(skill);
    }
  }
  
  print('Loaded ${originalSkills.length} original skills');
  print('Original skill distribution:');
  final originalGroups = <int, int>{};
  final originalDifficulties = <String, int>{};
  
  for (final skill in originalSkills) {
    originalGroups[skill.group] = (originalGroups[skill.group] ?? 0) + 1;
    originalDifficulties[skill.valueLetter] = (originalDifficulties[skill.valueLetter] ?? 0) + 1;
  }
  
  print('  Groups: $originalGroups');
  print('  Difficulties: $originalDifficulties');
  
  // Simulate OLD cache serialization (the buggy way)
  print('\nTesting OLD cache format (buggy):');
  final oldCacheData = originalSkills.map((skill) => {
    'id': skill.id,
    'name': skill.name,
    'group': skill.group,  // INTEGER - this causes the bug!
    'valueLetter': skill.valueLetter,  // WRONG KEY NAME - this also causes issues!
    'description': skill.description,
    'apparatus': skill.apparatus,
    'value': skill.value,
  }).toList();
  
  // Simulate loading from old cache format
  final oldRestoredSkills = oldCacheData.map((data) => 
    Skill.fromMap(Map<String, dynamic>.from(data))).toList();
  
  final oldGroups = <int, int>{};
  final oldDifficulties = <String, int>{};
  
  for (final skill in oldRestoredSkills) {
    oldGroups[skill.group] = (oldGroups[skill.group] ?? 0) + 1;
    oldDifficulties[skill.valueLetter] = (oldDifficulties[skill.valueLetter] ?? 0) + 1;
  }
  
  print('  Restored Groups: $oldGroups');
  print('  Restored Difficulties: $oldDifficulties');
  
  // Simulate NEW cache serialization (the fixed way)
  print('\nTesting NEW cache format (fixed):');
  final newCacheData = originalSkills.map((skill) => {
    'id': skill.id,
    'name': skill.name,
    'group': _convertGroupToRoman(skill.group),  // ROMAN NUMERAL - fixed!
    'value_letter': skill.valueLetter,  // CORRECT KEY NAME - fixed!
    'description': skill.description,
    'apparatus': skill.apparatus,
    'value': skill.value,
  }).toList();
  
  // Simulate loading from new cache format
  final newRestoredSkills = newCacheData.map((data) => 
    Skill.fromMap(Map<String, dynamic>.from(data))).toList();
  
  final newGroups = <int, int>{};
  final newDifficulties = <String, int>{};
  
  for (final skill in newRestoredSkills) {
    newGroups[skill.group] = (newGroups[skill.group] ?? 0) + 1;
    newDifficulties[skill.valueLetter] = (newDifficulties[skill.valueLetter] ?? 0) + 1;
  }
  
  print('  Restored Groups: $newGroups');
  print('  Restored Difficulties: $newDifficulties');
  
  // Compare results
  print('\nComparison:');
  print('  Original == New Fixed: ${_mapsEqual(originalGroups, newGroups) && _mapsEqual(originalDifficulties, newDifficulties)}');
  print('  Original == Old Buggy: ${_mapsEqual(originalGroups, oldGroups) && _mapsEqual(originalDifficulties, oldDifficulties)}');
  
  if (_mapsEqual(originalGroups, newGroups) && _mapsEqual(originalDifficulties, newDifficulties)) {
    print('✅ NEW cache format preserves data correctly!');
  } else {
    print('❌ NEW cache format still has issues!');
  }
  
  if (!_mapsEqual(originalGroups, oldGroups) || !_mapsEqual(originalDifficulties, oldDifficulties)) {
    print('✅ OLD cache format is confirmed buggy (as expected)');
  } else {
    print('❌ OLD cache format works fine (unexpected!)');
  }
}

bool _mapsEqual<K, V>(Map<K, V> map1, Map<K, V> map2) {
  if (map1.length != map2.length) return false;
  for (final key in map1.keys) {
    if (map1[key] != map2[key]) return false;
  }
  return true;
}