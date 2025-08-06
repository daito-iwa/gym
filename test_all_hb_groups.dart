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
    'A': 0.1, 'B': 0.2, 'C': 0.3, 'D': 0.4, 'E': 0.5,
    'F': 0.6, 'G': 0.7, 'H': 0.8, 'I': 0.9, 'J': 1.0,
  };
  
  return letterToValue[letter.trim().toUpperCase()] ?? 0.0;
}

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
    
    int groupNumber = _parseRomanNumeral(map['group']?.toString());
    final valueLetter = map['value_letter']?.toString() ?? '';
    double value = _parseValueLetter(valueLetter);
    
    // Fallback logic
    if (groupNumber <= 0) {
      groupNumber = 1;
    }
    
    if (value <= 0.0 || valueLetter.isEmpty) {
      value = 0.1;
    }
    
    final finalValueLetter = valueLetter.isNotEmpty ? valueLetter : 'A';

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
  print('Testing ALL HB skills with cache fix...');
  print('=' * 50);
  
  final file = File('/Users/iwasakihiroto/Desktop/gym/data/skills_ja.csv');
  final content = await file.readAsString();
  final lines = content.split('\n');
  
  final originalSkills = <Skill>[];
  
  // Parse ALL HB skills from CSV
  for (int i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    
    final parts = line.split(',');
    if (parts.length >= 4 && parts[0] == 'HB') {
      final skill = Skill.fromMap({
        'id': 'SKILL_${i.toString().padLeft(3, '0')}',
        'apparatus': parts[0],
        'name': parts[1],
        'group': parts[2],
        'value_letter': parts[3],
        'description': parts[1],
      });
      
      originalSkills.add(skill);
    }
  }
  
  print('Loaded ${originalSkills.length} original HB skills');
  
  final originalGroups = <int, int>{};
  final originalDifficulties = <String, int>{};
  
  for (final skill in originalSkills) {
    originalGroups[skill.group] = (originalGroups[skill.group] ?? 0) + 1;
    originalDifficulties[skill.valueLetter] = (originalDifficulties[skill.valueLetter] ?? 0) + 1;
  }
  
  print('Original distribution:');
  print('  Groups: $originalGroups');
  print('  Difficulties: $originalDifficulties');
  
  // Test NEW cache format with ALL skills
  print('\nTesting NEW cache format with ALL HB skills:');
  final newCacheData = originalSkills.map((skill) => {
    'id': skill.id,
    'name': skill.name,
    'group': _convertGroupToRoman(skill.group),
    'value_letter': skill.valueLetter,
    'description': skill.description,
    'apparatus': skill.apparatus,
    'value': skill.value,
  }).toList();
  
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
  
  // Verify the fix
  final groupsMatch = _mapsEqual(originalGroups, newGroups);
  final difficultiesMatch = _mapsEqual(originalDifficulties, newDifficulties);
  
  if (groupsMatch && difficultiesMatch) {
    print('\n✅ SUCCESS: All HB skills preserved correctly with new cache format!');
    
    // Show some examples from each group
    print('\nExample skills from each group:');
    for (int group = 1; group <= 4; group++) {
      final groupSkills = newRestoredSkills.where((s) => s.group == group).take(3).toList();
      print('  Group $group (${_convertGroupToRoman(group)}):');
      for (final skill in groupSkills) {
        print('    ${skill.valueLetter}: ${skill.name}');
      }
    }
    
  } else {
    print('\n❌ FAILURE: Data corruption still exists!');
    if (!groupsMatch) {
      print('  Group mismatch: $originalGroups vs $newGroups');
    }
    if (!difficultiesMatch) {
      print('  Difficulty mismatch: $originalDifficulties vs $newDifficulties');
    }
  }
}

bool _mapsEqual<K, V>(Map<K, V> map1, Map<K, V> map2) {
  if (map1.length != map2.length) return false;
  for (final key in map1.keys) {
    if (map1[key] != map2[key]) return false;
  }
  return true;
}