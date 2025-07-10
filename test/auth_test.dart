import 'package:flutter_test/flutter_test.dart';
import 'package:gym/auth_screen.dart';
import 'package:flutter/material.dart';

void main() {
  group('AuthScreen Widget Tests', () {
    testWidgets('AuthScreen displays login form by default', (WidgetTester tester) async {
      bool isLoading = false;
      String? submittedUsername;
      String? submittedPassword;
      String? submittedEmail;
      String? submittedFullName;
      bool? submittedIsLogin;

      await tester.pumpWidget(MaterialApp(
        home: AuthScreen(
          isLoading: isLoading,
          onSubmit: (username, password, email, fullName, isLogin) {
            submittedUsername = username;
            submittedPassword = password;
            submittedEmail = email;
            submittedFullName = fullName;
            submittedIsLogin = isLogin;
          },
        ),
      ));

      // Check if login form is displayed
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Email Address'), findsNothing);
      expect(find.text('Full Name'), findsNothing);
      expect(find.text('Create new account'), findsOneWidget);
    });

    testWidgets('AuthScreen switches to sign up form', (WidgetTester tester) async {
      bool isLoading = false;

      await tester.pumpWidget(MaterialApp(
        home: AuthScreen(
          isLoading: isLoading,
          onSubmit: (username, password, email, fullName, isLogin) {},
        ),
      ));

      // Tap on "Create new account"
      await tester.tap(find.text('Create new account'));
      await tester.pumpAndSettle();

      // Check if sign up form is displayed
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);
    });

    testWidgets('AuthScreen validates username input', (WidgetTester tester) async {
      bool isLoading = false;

      await tester.pumpWidget(MaterialApp(
        home: AuthScreen(
          isLoading: isLoading,
          onSubmit: (username, password, email, fullName, isLogin) {},
        ),
      ));

      // Enter invalid username (too short)
      await tester.enterText(find.byKey(const ValueKey('username')), 'abc');
      await tester.enterText(find.byKey(const ValueKey('password')), 'password123');
      
      // Tap login button
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Check for validation error
      expect(find.text('Please enter at least 4 characters.'), findsOneWidget);
    });

    testWidgets('AuthScreen validates password input', (WidgetTester tester) async {
      bool isLoading = false;

      await tester.pumpWidget(MaterialApp(
        home: AuthScreen(
          isLoading: isLoading,
          onSubmit: (username, password, email, fullName, isLogin) {},
        ),
      ));

      // Enter valid username but invalid password (too short)
      await tester.enterText(find.byKey(const ValueKey('username')), 'testuser');
      await tester.enterText(find.byKey(const ValueKey('password')), '123456');
      
      // Tap login button
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Check for validation error
      expect(find.text('Password must be at least 7 characters long.'), findsOneWidget);
    });

    testWidgets('AuthScreen validates email input in sign up mode', (WidgetTester tester) async {
      bool isLoading = false;

      await tester.pumpWidget(MaterialApp(
        home: AuthScreen(
          isLoading: isLoading,
          onSubmit: (username, password, email, fullName, isLogin) {},
        ),
      ));

      // Switch to sign up mode
      await tester.tap(find.text('Create new account'));
      await tester.pumpAndSettle();

      // Enter invalid email
      await tester.enterText(find.byKey(const ValueKey('username')), 'testuser');
      await tester.enterText(find.byKey(const ValueKey('email')), 'invalidemail');
      await tester.enterText(find.byKey(const ValueKey('fullname')), 'Test User');
      await tester.enterText(find.byKey(const ValueKey('password')), 'password123');
      
      // Tap sign up button
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Check for validation error
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    });

    testWidgets('AuthScreen submits login form with valid data', (WidgetTester tester) async {
      bool isLoading = false;
      String? submittedUsername;
      String? submittedPassword;
      String? submittedEmail;
      String? submittedFullName;
      bool? submittedIsLogin;

      await tester.pumpWidget(MaterialApp(
        home: AuthScreen(
          isLoading: isLoading,
          onSubmit: (username, password, email, fullName, isLogin) {
            submittedUsername = username;
            submittedPassword = password;
            submittedEmail = email;
            submittedFullName = fullName;
            submittedIsLogin = isLogin;
          },
        ),
      ));

      // Enter valid login data
      await tester.enterText(find.byKey(const ValueKey('username')), 'testuser');
      await tester.enterText(find.byKey(const ValueKey('password')), 'password123');
      
      // Tap login button
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Check if form was submitted with correct data
      expect(submittedUsername, 'testuser');
      expect(submittedPassword, 'password123');
      expect(submittedEmail, null);
      expect(submittedFullName, null);
      expect(submittedIsLogin, true);
    });

    testWidgets('AuthScreen submits sign up form with valid data', (WidgetTester tester) async {
      bool isLoading = false;
      String? submittedUsername;
      String? submittedPassword;
      String? submittedEmail;
      String? submittedFullName;
      bool? submittedIsLogin;

      await tester.pumpWidget(MaterialApp(
        home: AuthScreen(
          isLoading: isLoading,
          onSubmit: (username, password, email, fullName, isLogin) {
            submittedUsername = username;
            submittedPassword = password;
            submittedEmail = email;
            submittedFullName = fullName;
            submittedIsLogin = isLogin;
          },
        ),
      ));

      // Switch to sign up mode
      await tester.tap(find.text('Create new account'));
      await tester.pumpAndSettle();

      // Enter valid sign up data
      await tester.enterText(find.byKey(const ValueKey('username')), 'testuser');
      await tester.enterText(find.byKey(const ValueKey('email')), 'test@example.com');
      await tester.enterText(find.byKey(const ValueKey('fullname')), 'Test User');
      await tester.enterText(find.byKey(const ValueKey('password')), 'password123');
      
      // Tap sign up button
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Check if form was submitted with correct data
      expect(submittedUsername, 'testuser');
      expect(submittedPassword, 'password123');
      expect(submittedEmail, 'test@example.com');
      expect(submittedFullName, 'Test User');
      expect(submittedIsLogin, false);
    });

    testWidgets('AuthScreen shows loading indicator when isLoading is true', (WidgetTester tester) async {
      bool isLoading = true;

      await tester.pumpWidget(MaterialApp(
        home: AuthScreen(
          isLoading: isLoading,
          onSubmit: (username, password, email, fullName, isLogin) {},
        ),
      ));

      // Check if loading indicator is displayed
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Login'), findsNothing);
    });
  });
}