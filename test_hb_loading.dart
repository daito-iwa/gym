import 'dart:convert';
import 'dart:io';

// Mock CSV loading function to test HB skills
void main() async {
  // Read the CSV file
  final file = File('/Users/iwasakihiroto/Desktop/gym/data/skills_ja.csv');
  final content = await file.readAsString();
  
  // Parse CSV manually (simple split method)
  final lines = content.split('\n');
  final hbSkills = <Map<String, String>>[];
  
  print('Total lines in CSV: ${lines.length}');
  
  // Skip header line
  for (int i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    
    final parts = line.split(',');
    if (parts.length >= 4) {
      final apparatus = parts[0];
      if (apparatus == 'HB') {
        hbSkills.add({
          'apparatus': apparatus,
          'name': parts[1],
          'group': parts[2],
          'value_letter': parts[3],
        });
      }
    }
  }
  
  print('\n=== HB SKILLS ANALYSIS ===');
  print('Total HB skills found: ${hbSkills.length}');
  
  // Analyze groups
  final groups = <String, int>{};
  final difficulties = <String, int>{};
  
  for (final skill in hbSkills) {
    final group = skill['group']!;
    final difficulty = skill['value_letter']!;
    
    groups[group] = (groups[group] ?? 0) + 1;
    difficulties[difficulty] = (difficulties[difficulty] ?? 0) + 1;
  }
  
  print('\nGroup distribution:');
  groups.forEach((group, count) {
    print('  $group: $count skills');
  });
  
  print('\nDifficulty distribution:');
  difficulties.forEach((difficulty, count) {
    print('  $difficulty: $count skills');
  });
  
  print('\nFirst 20 HB skills:');
  for (int i = 0; i < hbSkills.length && i < 20; i++) {
    final skill = hbSkills[i];
    print('  ${i+1}. ${skill['group']}-${skill['value_letter']}: ${skill['name']}');
  }
  
  // Check if there are any parsing issues
  print('\nChecking for issues:');
  final group1Count = groups['Ⅰ'] ?? 0;
  final aDiffCount = difficulties['A'] ?? 0;
  final totalSkills = hbSkills.length;
  
  print('Group I ratio: ${(group1Count / totalSkills * 100).toStringAsFixed(1)}%');
  print('A difficulty ratio: ${(aDiffCount / totalSkills * 100).toStringAsFixed(1)}%');
  
  if (group1Count / totalSkills > 0.8) {
    print('🚨 WARNING: Too many Group I skills detected!');
  }
  if (aDiffCount / totalSkills > 0.7) {
    print('🚨 WARNING: Too many A difficulty skills detected!');
  }
  
  // Check if all groups are present
  final expectedGroups = ['Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ'];
  print('\nGroup completeness check:');
  for (final expectedGroup in expectedGroups) {
    if (groups.containsKey(expectedGroup)) {
      print('  ✅ $expectedGroup: ${groups[expectedGroup]} skills');
    } else {
      print('  ❌ $expectedGroup: MISSING!');
    }
  }
}