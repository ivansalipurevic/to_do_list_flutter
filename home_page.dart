import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class Task {
  int? id;
  String title;
  bool isDone;

  Task({this.id, required this.title, this.isDone = false});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isDone': isDone ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      isDone: map['isDone'] == 1,
    );
  }

  Task copyWith({int? id, String? title, bool? isDone}) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }
}

class TaskDatabase {
  static final TaskDatabase instance = TaskDatabase._init();
  static Database? _database;

  TaskDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        isDone INTEGER NOT NULL
      )
    ''');
  }

  Future<Task> create(Task task) async {
    final db = await instance.database;
    final id = await db.insert('tasks', task.toMap());
    return task.copyWith(id: id);
  }

  Future<List<Task>> readAllTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks');
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<int> update(Task task) async {
    final db = await instance.database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _wordsSpoken = "";
  double _confidenceLevel = 0;
  List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();
    initSpeech();
    _loadTasks();
  }

  void initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize();
    } catch (e) {
      debugPrint("Greška pri inicijalizaciji govora: $e");
      _speechEnabled = false;
    }
    setState(() {});
  }

  void _loadTasks() async {
    final tasks = await TaskDatabase.instance.readAllTasks();
    setState(() {
      _tasks = tasks;
      _sortTasks();
    });
  }

  void _startListening() async {
    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: 'sr-RS',
      listenFor: Duration(seconds: 30),
      pauseFor: Duration(seconds: 5),
      partialResults: true,
    );
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) async {
    setState(() {
      _wordsSpoken = result.recognizedWords;
      _confidenceLevel = result.confidence;
    });

    if (result.finalResult && _wordsSpoken.isNotEmpty) {
      final newTask = Task(title: _wordsSpoken);
      final inserted = await TaskDatabase.instance.create(newTask);
      setState(() {
        _tasks.add(inserted);
        _sortTasks();
        _wordsSpoken = "";
      });
    }
  }

  void _editTaskDialog(BuildContext context, int index) {
    final TextEditingController _controller =
        TextEditingController(text: _tasks[index].title);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Ispravi"),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: "Unesi novi tekst"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Otkaži"),
            ),
            TextButton(
              onPressed: () async {
                if (_controller.text.trim().isNotEmpty) {
                  final updatedTask =
                      _tasks[index].copyWith(title: _controller.text.trim());
                  await TaskDatabase.instance.update(updatedTask);
                  setState(() {
                    _tasks[index] = updatedTask;
                  });
                }
                Navigator.of(context).pop();
              },
              child: const Text("Sačuvaj"),
            ),
          ],
        );
      },
    );
  }

  void _deleteTask(int index) async {
    await TaskDatabase.instance.delete(_tasks[index].id!);
    setState(() {
      _tasks.removeAt(index);
    });
  }

  void _sortTasks() {
    _tasks.sort((a, b) {
      if (a.isDone == b.isDone) return 0;
      return a.isDone ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TO DO LIST',
          style: TextStyle(
              color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 33),
        ),
        backgroundColor: Colors.blueGrey,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              _speechToText.isListening
                  ? "Slušam..."
                  : _speechEnabled
                      ? "Dodirni mikrofon da kažeš nešto..."
                      : "GREŠKA!",
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ),
          if (_speechToText.isNotListening && _confidenceLevel > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                "Podudaranje: ${(_confidenceLevel * 100).toStringAsFixed(1)}%",
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return ListTile(
                  leading: Checkbox(
                    value: task.isDone,
                    onChanged: (value) async {
                      final updatedTask = task.copyWith(isDone: value);
                      await TaskDatabase.instance.update(updatedTask);
                      setState(() {
                        _tasks[index] = updatedTask;
                        _sortTasks();
                      });
                    },
                  ),
                  title: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 18,
                      decoration: task.isDone
                          ? TextDecoration.lineThrough
                          : TextDecoration.underline,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          _editTaskDialog(context, index);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_sharp),
                        onPressed: () {
                          _deleteTask(index);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            _speechToText.isListening ? _stopListening : _startListening,
        backgroundColor: Colors.blueGrey,
        child: Icon(
          _speechToText.isNotListening ? Icons.mic : Icons.mic_off,
          color: Colors.white,
        ),
      ),
    );
  }
}
