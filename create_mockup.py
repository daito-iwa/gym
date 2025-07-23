#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw, ImageFont

def create_app_mockup():
    # App Store screenshot sizes for iPhone
    width, height = 1290, 2796  # 6.7" iPhone Pro Max
    
    # Create image with white background
    img = Image.new('RGB', (width, height), color='white')
    draw = ImageDraw.Draw(img)
    
    # Try to use system font, fallback to default
    try:
        title_font = ImageFont.truetype('/System/Library/Fonts/SF-Pro-Display-Bold.ttf', 80)
        subtitle_font = ImageFont.truetype('/System/Library/Fonts/SF-Pro-Display-Medium.ttf', 60)
        body_font = ImageFont.truetype('/System/Library/Fonts/SF-Pro-Display-Regular.ttf', 50)
    except:
        title_font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()
        body_font = ImageFont.load_default()
    
    # Draw status bar
    draw.rectangle([(0, 0), (width, 120)], fill='#1C1C1E')
    draw.text((60, 40), '9:41', fill='white', font=subtitle_font)
    draw.text((width-200, 40), '100%', fill='white', font=body_font)
    
    # Draw app title
    draw.text((width//2-300, 200), 'Gymnastics AI', fill='#1C1C1E', font=title_font, anchor='mm')
    
    # Draw main content area
    draw.rectangle([(100, 400), (width-100, 1200)], outline='#007AFF', width=5)
    
    # Draw skill analysis section
    draw.text((width//2, 500), '体操技難度判定システム', fill='#1C1C1E', font=subtitle_font, anchor='mm')
    
    # Draw feature list
    features = [
        '• AIによる技の自動認識',
        '• 難度値の即座判定',
        '• 技術データベース検索',
        '• パフォーマンス分析',
        '• コーチング支援機能'
    ]
    
    y_pos = 700
    for feature in features:
        draw.text((150, y_pos), feature, fill='#1C1C1E', font=body_font)
        y_pos += 100
    
    # Draw buttons
    draw.rectangle([(200, 1400), (width-200, 1500)], fill='#007AFF')
    draw.text((width//2, 1450), '技の分析を開始', fill='white', font=subtitle_font, anchor='mm')
    
    draw.rectangle([(200, 1600), (width-200, 1700)], fill='#34C759')
    draw.text((width//2, 1650), 'データベース検索', fill='white', font=subtitle_font, anchor='mm')
    
    # Save image
    img.save('/Users/iwasakihiroto/Desktop/gymnastics_mockup_1.png')
    print("Mockup 1 saved")
    
    # Create second mockup with different content
    img2 = Image.new('RGB', (width, height), color='#F2F2F7')
    draw2 = ImageDraw.Draw(img2)
    
    # Status bar
    draw2.rectangle([(0, 0), (width, 120)], fill='#1C1C1E')
    draw2.text((60, 40), '9:41', fill='white', font=subtitle_font)
    
    # Navigation bar
    draw2.rectangle([(0, 120), (width, 250)], fill='white')
    draw2.text((width//2, 185), '技データベース', fill='#1C1C1E', font=subtitle_font, anchor='mm')
    
    # Content cards
    card_y = 300
    skills = ['前方宙返り', '後方宙返り', '側方宙返り', 'ひねり技']
    
    for skill in skills:
        draw2.rectangle([(50, card_y), (width-50, card_y+150)], fill='white', outline='#C7C7CC', width=2)
        draw2.text((100, card_y+50), skill, fill='#1C1C1E', font=subtitle_font)
        draw2.text((100, card_y+100), f'難度: A-F', fill='#8E8E93', font=body_font)
        card_y += 200
    
    img2.save('/Users/iwasakihiroto/Desktop/gymnastics_mockup_2.png')
    print("Mockup 2 saved")

if __name__ == "__main__":
    create_app_mockup()