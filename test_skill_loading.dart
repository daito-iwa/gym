import 'package:csv/csv.dart';
import 'dart:io';

// Copy the Skill class and parsing functions
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

  @override
  String toString() {
    return 'Skill(name: $name, apparatus: $apparatus, group: $group, valueLetter: $valueLetter, value: $value)';
  }
}

void main() async {
  print('Testing skill loading for HB, VT, SR, PH...');
  
  // Read the CSV file
  try {
    final csvContent = '''apparatus,name,group,value_letter
HB,後ろ振り上がり倒立,Ⅰ,A
HB,後ろ振り上がりひねり倒立,Ⅰ,A
VT,前転とび前方かかえ込み宙返りひねり,Ⅰ,2.4
VT,クエルボひねり,Ⅰ,2.8
SR,前振り上がり支持,Ⅰ,A
SR,支持後ろ振り、前に回りながら懸垂,Ⅰ,A
PH,正交差,Ⅰ,A
PH,正交差横移動（ひねり）,Ⅰ,B''';

    print('CSV Content loaded: ${csvContent.length} characters');
    
    final List<List<dynamic>> listData = const CsvToListConverter().convert(csvContent);
    print('CSV parsed: ${listData.length} rows');
    
    // Test each apparatus
    for (String apparatus in ['HB', 'VT', 'SR', 'PH']) {
      print('\n--- Testing apparatus: $apparatus ---');
      
      final skills = <Skill>[];
      int matchingRows = 0;
      
      for (int i = 1; i < listData.length; i++) {
        final row = listData[i];
        
        if (row.length >= 4) {
          final skillApparatus = row[0].toString();
          
          if (skillApparatus == apparatus) {
            matchingRows++;
            print('Processing row $i: $row');
            
            final skill = Skill.fromMap({
              'id': 'SKILL_${i.toString().padLeft(3, '0')}',
              'apparatus': skillApparatus,
              'name': row[1].toString(),
              'group': row[2].toString(), // ローマ数字
              'value_letter': row[3].toString(),
              'description': row[1].toString(),
            });
            skills.add(skill);
            
            print('Created skill: $skill');
          }
        }
      }
      
      print('Found ${skills.length} skills for $apparatus (matching rows: $matchingRows)');
      if (skills.isNotEmpty) {
        print('Sample skill: ${skills.first}');
      }
    }
    
  } catch (e) {
    print('Error: $e');
  }
}