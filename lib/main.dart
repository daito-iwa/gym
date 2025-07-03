import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'd_score_calculator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gymnastics AI Chat',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF0f0f1e),
        ),
        // Add other theme properties as needed
      ),
      home: const HomePage(title: 'Gymnastics AI Chat'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

enum AppMode { chat, dScore }

class _HomePageState extends State<HomePage> {
  AppMode _currentMode = AppMode.chat;
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  String _session_id = Uuid().v4();
  bool _isLoading = false;
  String _currentLang = '日本語';

  // Dスコア計算用
  String? _selectedApparatus;
  final Map<String, Map<String, String>> _apparatusData = {
    "FX": {"ja": "床", "en": "Floor Exercise"},
    "PH": {"ja": "あん馬", "en": "Pommel Horse"},
    "SR": {"ja": "つり輪", "en": "Still Rings"},
    "VT": {"ja": "跳馬", "en": "Vault"},
    "PB": {"ja": "平行棒", "en": "Parallel Bars"},
    "HB": {"ja": "鉄棒", "en": "Horizontal Bar"},
  };
  List<Skill> _skillList = [];
  bool _isSkillLoading = false;
  List<List<Skill>> _routine = []; // 演技構成
  DScoreResult? _dScoreResult; // 計算結果を保持
  Skill? _selectedSkill; // ドロップダウンで選択された技

  @override
  void initState() {
    super.initState();
    _resetChat(); 
  }

  void _connectLastSkills() {
    if (_routine.length >= 2) {
      setState(() {
        final lastGroup = _routine.removeLast();
        _routine.last.addAll(lastGroup);
        _dScoreResult = null; // 構成が変わったら結果をリセット
      });
    }
  }

  Future<void> _loadSkills(String apparatus) async {
    setState(() {
      _isSkillLoading = true;
      _skillList = [];
    });

    final lang = _currentLang == '日本語' ? 'ja' : 'en';
    final path = 'data/skills_$lang.csv';
    try {
      final rawCsv = await rootBundle.loadString(path);
      final List<List<dynamic>> listData = const CsvToListConverter().convert(rawCsv);
      
      if (listData.isEmpty) {
        setState(() => _isSkillLoading = false);
        return;
      }
      
      final headers = listData[0].map((e) => e.toString()).toList();
      final skills = listData
          .skip(1)
          .map((row) {
            final map = Map<String, dynamic>.fromIterables(headers, row);
            return map;
          })
          .where((map) => map['apparatus'] == apparatus)
          .map((map) => Skill.fromMap(map))
          .toList();

      skills.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _skillList = skills;
        _isSkillLoading = false;
      });
    } catch (e) {
      print('Error loading skills: $e');
      setState(() {
        _isSkillLoading = false;
      });
    }
  }

  // メッセージを送信し、APIから応答を受け取る
  void _handleSendPressed() async {
    final userInput = _textController.text;
    if (userInput.trim().isEmpty) return;

    // ユーザーメッセージを追加
    setState(() {
      _messages.insert(0, ChatMessage(text: userInput, isUser: true));
      _isLoading = true;
    });
    _textController.clear();

    // APIにリクエストを送信
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': _session_id,
          'question': userInput,
          'lang': _currentLang == '日本語' ? 'ja' : 'en',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        // AIの応答を追加
        setState(() {
          _messages.insert(0, ChatMessage(text: data['answer'], isUser: false));
        });
      } else {
        // エラーメッセージを表示
        setState(() {
          _messages.insert(0, ChatMessage(text: 'エラー: ${response.body}', isUser: false));
        });
      }
    } catch (e) {
       setState(() {
          _messages.insert(0, ChatMessage(text: 'エラー: サーバーに接続できませんでした。', isUser: false));
        });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // チャットをリセットする
  void _resetChat() {
    setState(() {
      _messages.clear();
      _session_id = Uuid().v4();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // キーボードフォーカスを外す
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.only(top: 80.0),
                color: Theme.of(context).drawerTheme.backgroundColor,
                child: Center(
                  child: Image.asset(
                    'assets/logo.png',
                    height: 200,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('設定', style: Theme.of(context).textTheme.titleLarge),
              ),
              ListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text('ルールブックの言語:', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    DropdownButton<String>(
                      value: _currentLang,
                      onChanged: (String? newValue) {
                        setState(() {
                          _currentLang = newValue!;
                          _resetChat();
                        });
                      },
                      items: <String>['日本語', 'English']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
               Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Text('モード選択', style: Theme.of(context).textTheme.titleSmall),
              ),
              RadioListTile<AppMode>(
                title: const Text('ルールブックAIチャット'),
                value: AppMode.chat,
                groupValue: _currentMode,
                onChanged: (AppMode? value) {
                  setState(() {
                    _currentMode = value!;
                  });
                },
              ),
              RadioListTile<AppMode>(
                title: const Text('Dスコア計算'),
                value: AppMode.dScore,
                groupValue: _currentMode,
                onChanged: (AppMode? value) {
                  setState(() {
                    _currentMode = value!;
                  });
                },
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_currentMode == AppMode.chat)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: TextButton(
                    onPressed: _resetChat,
                    child: const Text('チャットをリセット'),
                  ),
                ),
              ),
            Expanded(
              child: _currentMode == AppMode.chat
                  ? _buildChatInterface()
                  : _buildDScoreInterface(),
            ),
          ],
        ),
      ),
    );
  }

  // Dスコア計算用のUI
  Widget _buildDScoreInterface() {
    final langCode = _currentLang == '日本語' ? 'ja' : 'en';
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownButton<String>(
            value: _selectedApparatus,
            hint: Text('種目を選択してください'),
            isExpanded: true,
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedApparatus = newValue;
                  _routine = []; // 種目を変更したら演技構成をリセット
                  _dScoreResult = null; // 同時に計算結果もリセット
                  _selectedSkill = null; // 技選択もリセット
                });
                _loadSkills(newValue);
              }
            },
            items: _apparatusData.keys.map<DropdownMenuItem<String>>((String key) {
              return DropdownMenuItem<String>(
                value: key,
                child: Text(_apparatusData[key]![langCode]!),
              );
            }).toList(),
          ),
          const SizedBox(height: 16.0),
          if (_selectedApparatus != null)
            _buildSkillSelector(),
          const SizedBox(height: 24.0),
          Text('現在の演技構成 (${_routine.length} 技)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8.0),
          Container(
            height: 120,
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: _routine.isEmpty
                ? const Center(child: Text('下のリストから技を選択してください。'))
                : ListView.separated(
                    itemCount: _routine.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.grey),
                    itemBuilder: (context, index) {
                      final skillGroup = _routine[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                        child: Wrap(
                          spacing: 6.0,
                          runSpacing: 4.0,
                          children: skillGroup.map((skill) {
                            return Chip(
                              label: Text(skill.name),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onDeleted: () {
                                setState(() {
                                  // グループから特定のスキルを削除
                                  skillGroup.remove(skill);
                                  // グループが空になったら、そのグループ自体を演技構成から削除
                                  if (skillGroup.isEmpty) {
                                    _routine.removeWhere((g) => g.isEmpty);
                                  }
                                  _dScoreResult = null; // 構成が変わったら結果をリセット
                                });
                              },
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _routine.length >= 2 ? _connectLastSkills : null,
                child: const Text('前の技とつなげる'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _routine.isNotEmpty && _selectedApparatus != null
                  ? () {
                      final result = calculateDScore(_selectedApparatus!, _routine);
                      setState(() {
                        _dScoreResult = result;
                      });
                    }
                  : null,
                child: const Text('Dスコアを計算'),
              ),
            ],
          ),
          if (_dScoreResult != null)
            _buildDScoreResultDetails(_dScoreResult!),
          const Divider(),
          const SizedBox(height: 8.0),
          if (_isSkillLoading)
            const Center(child: CircularProgressIndicator())
          else if (_selectedApparatus != null && _skillList.isEmpty)
             Expanded(
              child: Center(
                child: Text('${_apparatusData[_selectedApparatus]![langCode]} の技データが見つかりません。'),
              ),
            )
          else if (_selectedApparatus == null)
             const Expanded(
                child: Center(child: Text('まずは種目を選択してください。')),
            ),
        ],
      ),
    );
  }

  Widget _buildSkillSelector() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownSearch<Skill>(
            items: (filter, loadProps) {
              // フィルタリング処理
              if (filter.isEmpty) {
                return _skillList;
              }
              return _skillList.where((skill) => 
                skill.name.toLowerCase().contains(filter.toLowerCase())
              ).toList();
            },
            selectedItem: _selectedSkill,
            itemAsString: (Skill? s) => s?.name ?? '',
            onChanged: (Skill? newValue) {
              setState(() {
                _selectedSkill = newValue;
              });
            },
            popupProps: PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: const TextFieldProps(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  hintText: "技を検索...",
                ),
              ),
              itemBuilder: (context, skill, isSelected, isHighlighted) {
                return ListTile(
                  title: Text(skill.name),
                  subtitle: Text('Group: ${skill.group}, D: ${skill.valueLetter} (${skill.value.toStringAsFixed(1)})'),
                );
              },
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _selectedSkill != null
              ? () {
                  setState(() {
                    _routine.add([_selectedSkill!]);
                    _selectedSkill = null;
                    _dScoreResult = null; // 構成が変わったら結果をリセット
                  });
                }
              : null,
          child: const Text('追加'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDScoreResultDetails(DScoreResult result) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'D-Score: ${result.totalDScore.toStringAsFixed(3)}',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16.0),
            const Divider(),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('難度点合計:'),
                Text(result.difficultyValue.toStringAsFixed(3)),
              ],
            ),
            const SizedBox(height: 8.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('グループ要求 (${result.fulfilledGroups} / ${result.requiredGroups}):'),
                Text(result.groupBonus.toStringAsFixed(3)),
              ],
            ),
            const SizedBox(height: 8.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('連続技ボーナス:'),
                Text(result.connectionBonus.toStringAsFixed(3)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // チャット用のUI
  Widget _buildChatInterface() {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (_, int index) => _messages[index],
            ),
          ),
          if (_isLoading) const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: CircularProgressIndicator(),
          ),
          Container(
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }

  // テキスト入力欄
  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(25.0),
        ),
        child: Row(
          children: [
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: (text) => _handleSendPressed(),
                decoration: const InputDecoration.collapsed(hintText: 'メッセージを送信'),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _isLoading ? null : () => _handleSendPressed(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// チャットメッセージを表すウィジェット
class ChatMessage extends StatelessWidget {
  const ChatMessage({super.key, required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(child: Text(isUser ? 'You' : 'AI')),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isUser ? 'You' : 'AI', style: Theme.of(context).textTheme.titleMedium),
                Container(
                  margin: const EdgeInsets.only(top: 5.0),
                  child: Text(text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
