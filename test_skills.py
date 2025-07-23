#!/usr/bin/env python3
"""
Skills database test script
"""
import csv
import os

def test_skills_database():
    """Test skills database loading"""
    try:
        csv_path = os.path.join("data", "skills_ja.csv")
        
        # Test file existence
        if not os.path.exists(csv_path):
            print(f"❌ File not found: {csv_path}")
            return False
            
        # Test CSV loading
        with open(csv_path, 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            rows = list(reader)
            
        print(f"✅ Successfully loaded {len(rows)} skills from database")
        
        # Test data structure
        if rows:
            sample = rows[0]
            required_fields = ['apparatus', 'name', 'group', 'value_letter']
            missing_fields = [field for field in required_fields if field not in sample]
            
            if missing_fields:
                print(f"❌ Missing required fields: {missing_fields}")
                return False
            else:
                print(f"✅ All required fields present: {required_fields}")
        
        # Test data by apparatus
        apparatus_count = {}
        for row in rows:
            apparatus = row['apparatus']
            apparatus_count[apparatus] = apparatus_count.get(apparatus, 0) + 1
            
        print("📊 Skills by apparatus:")
        for apparatus, count in apparatus_count.items():
            print(f"  {apparatus}: {count} skills")
            
        # Test difficulty distribution
        difficulty_count = {}
        for row in rows:
            diff = row['value_letter']
            difficulty_count[diff] = difficulty_count.get(diff, 0) + 1
            
        print("📈 Skills by difficulty:")
        for diff in sorted(difficulty_count.keys()):
            count = difficulty_count[diff]
            if len(diff) == 1 and diff in 'ABCDEFGHIJ':
                points = (ord(diff) - ord('A') + 1) / 10.0
                print(f"  {diff} ({points}点): {count} skills")
            else:
                print(f"  {diff} (未定義): {count} skills")
            
        # Test sample searches
        print("\n🔍 Sample skill searches:")
        test_queries = ['倒立', '宙返り', 'トーマス', '車輪']
        for query in test_queries:
            found_skills = [row for row in rows if query in row['name']]
            print(f"  '{query}': {len(found_skills)} matches")
            if found_skills:
                sample_skill = found_skills[0]
                print(f"    Example: {sample_skill['name']} ({sample_skill['apparatus']} - {sample_skill['value_letter']})")
        
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_deduction_system():
    """Test deduction system"""
    print("\n📋 Testing deduction system:")
    
    deduction_table = {
        "小欠点_0.10": [
            "あいまいな姿勢（かがみ込み、屈身、伸身）",
            "手や握り手の位置調整・修正（毎回）",
            "倒立で歩く、またはとぶ（1歩につき）",
            "着地でぐらつく、小さく足をずらす、手を回す"
        ],
        "中欠点_0.30": [
            "演技中に補助者が選手に触れる",
            "着地で脚を開く（肩幅を超える）"
        ],
        "大欠点_0.50": [
            "ゆか、マット、または器械にぶつかる",
            "落下なしに演技を中断する"
        ]
    }
    
    test_queries = ['着地', '接触', '中断', '姿勢']
    for query in test_queries:
        matches = []
        for deduction_type, items in deduction_table.items():
            for item in items:
                if query in item:
                    points = deduction_type.split("_")[1]
                    category = deduction_type.split("_")[0]
                    matches.append(f"{category}（{points}点）: {item}")
        
        print(f"  '{query}': {len(matches)} matches")
        for match in matches[:2]:  # Show first 2 matches
            print(f"    {match}")

if __name__ == "__main__":
    print("🏅 Gymnastics AI Skills Database Test")
    print("=" * 50)
    
    success = test_skills_database()
    test_deduction_system()
    
    if success:
        print("\n✅ All tests passed! Database is ready for deployment.")
    else:
        print("\n❌ Tests failed. Please check the database setup.")