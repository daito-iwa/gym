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
  final result = romanToInt[trimmed] ?? 0;
  
  return result;
}

void main() async {
  // Read the CSV file
  final file = File('/Users/iwasakihiroto/Desktop/gym/data/skills_ja.csv');
  final content = await file.readAsString();
  
  // Parse CSV manually (simple split method)
  final lines = content.split('\n');
  
  print('Testing Roman numeral parsing for all HB groups:');
  print('=' * 60);
  
  final groupCounts = <String, int>{};
  final groupResults = <String, Set<int>>{};
  
  // Skip header line
  for (int i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    
    final parts = line.split(',');
    if (parts.length >= 4) {
      final apparatus = parts[0];
      if (apparatus == 'HB') {
        final rawGroup = parts[2];
        final groupResult = _parseRomanNumeral(rawGroup);
        
        // Track occurrences
        groupCounts[rawGroup] = (groupCounts[rawGroup] ?? 0) + 1;
        
        if (!groupResults.containsKey(rawGroup)) {
          groupResults[rawGroup] = <int>{};
        }
        groupResults[rawGroup]!.add(groupResult);
        
        // Show problematic cases
        if (groupResult == 0) {
          print('🚨 PARSING FAILED: Raw="$rawGroup", Line: $line');
        }
      }
    }
  }
  
  print('\nGroup distribution and parsing results:');
  groupCounts.forEach((rawGroup, count) {
    final parsedResults = groupResults[rawGroup]!.toList()..sort();
    final uniqueResults = parsedResults.toSet();
    
    print('  Raw: "$rawGroup" (${count} skills)');
    print('    Parsed to: ${uniqueResults.join(", ")}');
    
    if (uniqueResults.contains(0)) {
      print('    🚨 WARNING: Contains failed parses (0)!');
    }
    if (uniqueResults.length > 1) {
      print('    🚨 WARNING: Inconsistent parsing results!');
    }
  });
  
  // Test specific Roman numerals
  print('\nTesting specific Roman numerals:');
  final testCases = ['Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'I', 'II', 'III', 'IV'];
  for (final testCase in testCases) {
    final result = _parseRomanNumeral(testCase);
    print('  "$testCase" -> $result');
  }
}