# Google Play Console Setup Guide for 大東体操クラブ (Gymnastics D-Score Calculator)

## Table of Contents
1. [Google Play Console Registration](#1-google-play-console-registration)
2. [App Registration and Basic Information](#2-app-registration-and-basic-information)
3. [App Metadata Configuration](#3-app-metadata-configuration)
4. [Pricing and Distribution Settings](#4-pricing-and-distribution-settings)
5. [Content Rating and Age Restrictions](#5-content-rating-and-age-restrictions)
6. [Data Safety and Privacy Settings](#6-data-safety-and-privacy-settings)
7. [App Bundle Upload and Technical Requirements](#7-app-bundle-upload-and-technical-requirements)
8. [Testing and Review Process](#8-testing-and-review-process)
9. [Store Listing Optimization](#9-store-listing-optimization)
10. [Post-Launch Management](#10-post-launch-management)

---

## 1. Google Play Console Registration

### Prerequisites
- Google Account (personal or business)
- $25 USD registration fee (one-time payment)
- Valid payment method (credit card or PayPal)

### Steps
1. **Go to Google Play Console**
   - Visit [https://play.google.com/console](https://play.google.com/console)
   - Sign in with your Google account

2. **Developer Registration**
   - Click "Get started" or "Create Developer Account"
   - Choose account type:
     - **Individual**: For personal developers
     - **Organization**: For companies (recommended for 大東体操クラブ)
   - Fill in required information:
     - Developer name: "大東体操クラブ" or "Daito Gymnastics Club"
     - Contact information
     - Phone number verification

3. **Payment**
   - Pay the $25 registration fee
   - This enables publishing apps to Google Play

4. **Identity Verification**
   - Upload government-issued ID
   - Complete verification process (may take 1-3 days)

---

## 2. App Registration and Basic Information

### Create New App
1. **In Google Play Console Dashboard**
   - Click "Create app"
   - Fill in basic information:

2. **App Details**
   - **App name**: "大東体操クラブ - 体操Dスコア計算機"
   - **Default language**: Japanese (日本語)
   - **App or game**: App
   - **Free or paid**: Free (with in-app purchases)

3. **Declarations**
   - ✅ This app complies with Google Play policies
   - ✅ This app complies with US export laws
   - ✅ App is primarily designed for children: **NO** (targets all ages but primarily adults)

### App Information Setup
1. **App category**: Sports
2. **Tags**: Add relevant tags like "gymnastics", "sports", "calculator", "training"
3. **Contact details**:
   - Email: Your support email
   - Phone: Optional
   - Website: Your club website (if available)

---

## 3. App Metadata Configuration

### App Title and Description

#### Short Description (80 characters max)
**Japanese**: 体操競技のDスコア計算とAI分析で演技を向上させるアプリ
**English**: Gymnastics D-score calculator with AI analysis for performance improvement

#### Full Description (4000 characters max)
```
【大東体操クラブ公式アプリ】
体操競技のDスコア計算とAI分析機能を搭載した、体操選手・コーチ・審判員向けの専門アプリです。

🏅 主な機能
・正確なDスコア計算：最新のCode of Pointsに基づいた計算
・AI演技分析：パフォーマンスの詳細な分析とアドバイス
・技の管理：豊富な技のデータベース
・演技構成支援：最適な演技構成の提案
・トレーニング記録：練習の進捗管理
・レポート生成：詳細な分析レポート

💡 対象ユーザー
・体操選手：演技の改善と技術向上
・コーチ：選手指導と戦略立案
・審判員：正確な採点支援
・体操愛好家：技術理解の深化

🌟 特徴
・直感的な操作画面
・リアルタイム計算
・豊富な技のデータベース
・オフライン対応
・日本語完全対応

📱 フリーミアム方式
基本機能は無料。プレミアム機能（AI分析、詳細レポート等）は月額サブスクリプション。

体操競技の技術向上と正確な採点をサポートします。
```

### Screenshots Requirements
You need to provide screenshots for:
- **Phone**: 2-8 screenshots (1080x1920 or 1440x2560 pixels)
- **7-inch tablet**: 1-8 screenshots (1200x1920 pixels)
- **10-inch tablet**: 1-8 screenshots (1920x1200 pixels)

#### Screenshot Content Ideas
1. **Main dashboard** showing D-score calculator interface
2. **Skill selection** screen with Japanese gymnastics terms
3. **AI analysis** results with performance metrics
4. **Routine builder** interface
5. **Training records** and progress tracking
6. **Premium features** showcase
7. **Settings** and customization options

### App Icon
- **Size**: 512x512 pixels
- **Format**: PNG (32-bit)
- **Content**: Should represent gymnastics/sports theme
- **Design**: Clean, recognizable at small sizes

### Feature Graphic
- **Size**: 1024x500 pixels
- **Format**: JPEG or PNG
- **Content**: Promotional banner showcasing app features
- **Text**: Minimal text, focus on visual appeal

---

## 4. Pricing and Distribution Settings

### Pricing
- **App price**: Free
- **In-app purchases**: Yes
- **Subscription pricing**:
  - Monthly: ¥500-800 (adjust based on market research)
  - Currency: JPY (Japanese Yen)

### Distribution Settings
1. **Countries/regions**: 
   - Primary: Japan
   - Secondary: Consider other gymnastics-active countries

2. **Device categories**:
   - ✅ Phone
   - ✅ Tablet
   - ✅ Wear OS (optional)

3. **Content filtering**:
   - Enable content filtering for inappropriate content

### In-App Products Configuration
1. **Subscription Products**:
   - **Product ID**: `premium_monthly`
   - **Name**: プレミアム月額プラン
   - **Description**: AI分析、詳細レポート、広告非表示
   - **Price**: ¥600/month
   - **Billing period**: Monthly
   - **Free trial**: 7 days

2. **Managed Products** (if applicable):
   - One-time purchases for specific features

---

## 5. Content Rating and Age Restrictions

### Content Rating Questionnaire
1. **Does your app contain violence?** No
2. **Does your app contain sexual content?** No
3. **Does your app contain profanity?** No
4. **Does your app contain drug references?** No
5. **Does your app contain simulated gambling?** No
6. **Does your app contain user-generated content?** No (unless chat features)
7. **Does your app contain unrestricted web access?** No
8. **Does your app contain ads?** Yes (AdMob)

### Expected Ratings
- **ESRB**: Everyone
- **PEGI**: 3+
- **USK**: 0
- **CERO**: A (All ages)
- **DJCTQ**: L (Livre)

### Age-Based Restrictions
- **Designed for families**: No
- **Primarily child-directed**: No
- **Mixed audience**: Yes (appeals to children and adults)

---

## 6. Data Safety and Privacy Settings

### Data Collection (based on your app features)

#### Data Types Collected
1. **Personal Information**:
   - ✅ Name (for user accounts)
   - ✅ Email address (for authentication)
   - ✅ User IDs (for app functionality)

2. **Financial Information**:
   - ✅ Purchase history (for subscriptions)
   - ✅ Payment info (handled by Google Play)

3. **App Activity**:
   - ✅ App interactions (usage analytics)
   - ✅ In-app search history
   - ✅ Other user-generated content (training data)

4. **App Info and Performance**:
   - ✅ Crash logs
   - ✅ Diagnostics

### Data Usage Purpose
- **App functionality**: Core features operation
- **Analytics**: Performance improvement
- **Personalization**: User experience enhancement
- **Advertising**: AdMob integration

### Data Sharing
- **Third parties**: Yes (AdMob, analytics services)
- **Data encryption**: Yes (in transit and at rest)
- **User control**: Users can request data deletion

### Privacy Policy
**Required**: Create a comprehensive privacy policy at your domain:
- URL: `https://yourclub.com/privacy-policy`
- Content must cover:
  - Data collection practices
  - Data usage
  - Third-party services (AdMob, analytics)
  - User rights
  - Contact information

---

## 7. App Bundle Upload and Technical Requirements

### Build Configuration

#### Version Information
- **Version name**: 1.0.0
- **Version code**: 1
- **Target SDK**: 34 (Android 14)
- **Minimum SDK**: 21 (Android 5.0)

#### Build Commands
```bash
# Generate app bundle
flutter build appbundle --release

# Build location
./build/app/outputs/bundle/release/app-release.aab
```

### App Bundle Requirements
1. **File size**: Under 150MB (current limit)
2. **Format**: Android App Bundle (.aab)
3. **Signing**: Must be signed with upload key

### Play App Signing
1. **Enable Play App Signing**: Recommended
2. **Upload key**: Generate and keep secure
3. **App signing key**: Google manages automatically

### Technical Specifications
- **Supported architectures**: arm64-v8a, armeabi-v7a, x86_64
- **Permissions**: 
  - INTERNET (for API calls)
  - ACCESS_NETWORK_STATE (for connectivity)
  - BILLING (for in-app purchases)
  - AD_ID (for AdMob)

### App Bundle Optimization
1. **Dynamic delivery**: Enable for large resources
2. **Asset packs**: Consider for extensive skill databases
3. **Compression**: Enable for smaller download size

---

## 8. Testing and Review Process

### Internal Testing
1. **Setup Internal Testing Track**:
   - Upload your app bundle
   - Add internal testers (up to 100)
   - Test core functionality

2. **Test Checklist**:
   - ✅ D-score calculation accuracy
   - ✅ AI analysis functionality
   - ✅ Subscription purchase flow
   - ✅ AdMob integration
   - ✅ Offline functionality
   - ✅ User authentication

### Alpha Testing (Optional)
- **Limited audience**: 20-1000 testers
- **Feedback collection**: Use Google Play Console feedback
- **Duration**: 1-2 weeks

### Beta Testing
1. **Open Beta**: Public testing with opt-in
2. **Closed Beta**: Invite-only testing
3. **Test duration**: 2-4 weeks
4. **Feedback incorporation**: Address major issues

### Pre-Launch Report
Google Play Console provides:
- **Stability analysis**: Crash reports
- **Performance metrics**: ANR rates
- **Security vulnerabilities**: Automated security checks
- **Accessibility**: Accessibility audit

### Production Release
1. **Complete all required sections**
2. **Review and publish**
3. **Release timeline**: 1-3 days for review
4. **Staged rollout**: Start with 5-10% of users

---

## 9. Store Listing Optimization

### App Store Optimization (ASO)

#### Keywords (Japanese)
- Primary: 体操, Dスコア, 計算機, 体操競技
- Secondary: AI分析, トレーニング, コーチ, 審判
- Long-tail: 体操演技分析, 技術向上, 採点支援

#### Competitor Analysis
Research competing apps:
- Gymnastics scoring apps
- Sports training apps
- AI-powered fitness apps

### Visual Assets Optimization
1. **App icon**: 
   - Clear gymnastics imagery
   - Recognizable at small sizes
   - Consistent with brand

2. **Screenshots**:
   - Show key features clearly
   - Include Japanese text
   - Highlight unique selling points

3. **Feature graphic**:
   - Professional design
   - Clear value proposition
   - Consistent branding

### Localization
- **Primary language**: Japanese
- **Secondary languages**: English (for international users)
- **Cultural adaptation**: Use appropriate gymnastics terminology

---

## 10. Post-Launch Management

### Launch Strategy
1. **Soft launch**: Start with limited regions
2. **Gradual rollout**: Increase percentage over time
3. **Monitor metrics**: Watch for crashes and issues
4. **Collect feedback**: Respond to user reviews

### Analytics and Monitoring
1. **Google Play Console Analytics**:
   - Install metrics
   - User acquisition
   - Revenue tracking
   - Crash reporting

2. **Firebase Analytics** (if integrated):
   - User behavior tracking
   - Feature usage analysis
   - Conversion funnel optimization

### User Feedback Management
1. **Review Response Strategy**:
   - Respond within 24-48 hours
   - Address issues professionally
   - Thank users for feedback

2. **Common Issues to Monitor**:
   - Calculation accuracy complaints
   - Performance issues
   - Payment problems
   - Feature requests

### App Updates
1. **Regular Update Schedule**:
   - Monthly minor updates
   - Quarterly major updates
   - Emergency fixes as needed

2. **Update Content**:
   - Bug fixes
   - New features
   - Performance improvements
   - Code of Points updates

### Performance Optimization
1. **KPIs to Track**:
   - Daily/Monthly Active Users
   - Subscription conversion rate
   - User retention rate
   - App rating and reviews

2. **Optimization Strategies**:
   - A/B testing for UI changes
   - Feature usage analysis
   - User journey optimization
   - Performance monitoring

### Subscription Management
1. **Subscription Analytics**:
   - Conversion rates
   - Churn analysis
   - Revenue per user
   - Trial-to-paid conversion

2. **Retention Strategies**:
   - Onboarding improvements
   - Feature education
   - Regular content updates
   - User engagement campaigns

---

## Checklist for Google Play Console Setup

### Pre-Launch Checklist
- [ ] Developer account created and verified
- [ ] App created with correct basic information
- [ ] App icon (512x512) uploaded
- [ ] Screenshots for all device types uploaded
- [ ] Feature graphic (1024x500) uploaded
- [ ] App description written and optimized
- [ ] Content rating completed
- [ ] Data safety section completed
- [ ] Privacy policy created and linked
- [ ] Pricing and distribution configured
- [ ] App bundle built and uploaded
- [ ] Internal testing completed
- [ ] All required sections completed
- [ ] App reviewed and approved

### Post-Launch Checklist
- [ ] Monitor app performance metrics
- [ ] Respond to user reviews
- [ ] Track subscription performance
- [ ] Plan and execute updates
- [ ] Optimize store listing based on performance
- [ ] Monitor competitor activities
- [ ] Gather user feedback for improvements

---

## Additional Resources

### Documentation
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [Android App Bundle](https://developer.android.com/guide/app-bundle)
- [Play App Signing](https://developer.android.com/studio/publish/app-signing)

### Tools
- [Google Play Console](https://play.google.com/console)
- [Firebase Console](https://console.firebase.google.com)
- [AdMob Console](https://apps.admob.com)

### Support
- Google Play Developer Support
- Stack Overflow (android-app-bundle tag)
- Flutter Community Forums

---

This comprehensive guide should help you successfully set up and launch your gymnastics D-score calculator app on Google Play Store. Remember to thoroughly test each step and keep your app updated with the latest gymnastics rules and regulations.