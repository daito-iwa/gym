import 'dart:io';

// Test Roman numeral parsing like in the app
int _parseRomanNumeral(String? roman) {
  if (roman == null || roman.isEmpty) {
    print('Roman numeral is null or empty');
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
  print('Parsing roman: "$roman" -> trimmed: "$trimmed"');
  
  final result = romanToInt[trimmed] ?? 0;
  print('Result: $result');
  
  return result;
}

double _parseValueLetter(String? letter) {
  if (letter == null || letter.isEmpty) {
    print('Value letter is null or empty');
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
  
  final result = letterToValue[letter.trim().toUpperCase()] ?? 0.0;
  print('Parsing value letter: "$letter" -> ${letter.trim().toUpperCase()} -> $result');
  
  return result;
}

void main() async {
  // Read the CSV file
  final file = File('/Users/iwasakihiroto/Desktop/gym/data/skills_ja.csv');
  final content = await file.readAsString();
  
  // Parse CSV manually (simple split method)
  final lines = content.split('\n');
  
  print('Testing Roman numeral and value letter parsing for first 20 HB skills:');
  print('=' * 80);
  
  int hbSkillCount = 0;
  
  // Skip header line
  for (int i = 1; i < lines.length && hbSkillCount < 20; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    
    final parts = line.split(',');
    if (parts.length >= 4) {
      final apparatus = parts[0];
      if (apparatus == 'HB') {
        hbSkillCount++;
        
        print('\nHB Skill $hbSkillCount:');
        print('  Original line: $line');
        print('  Name: ${parts[1]}');
        
        // Test parsing
        print('  Group parsing:');
        final groupResult = _parseRomanNumeral(parts[2]);
        
        print('  Difficulty parsing:');
        final valueResult = _parseValueLetter(parts[3]);
        
        // Test the fallback logic
        int finalGroup = groupResult <= 0 ? 1 : groupResult;
        double finalValue = valueResult <= 0.0 ? 0.1 : valueResult;
        String finalValueLetter = parts[3].trim().isEmpty ? 'A' : parts[3].trim();
        
        print('  Final values after fallback:');
        print('    Group: $finalGroup');
        print('    Value: $finalValue');
        print('    Value Letter: $finalValueLetter');
        
        if (groupResult <= 0) {
          print('  🚨 GROUP FALLBACK TRIGGERED!');
        }
        if (valueResult <= 0.0) {
          print('  🚨 VALUE FALLBACK TRIGGERED!');
        }
      }
    }
  }
}