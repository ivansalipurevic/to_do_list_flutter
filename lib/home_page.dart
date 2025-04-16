import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';


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
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}
class Task {
  String title;
  bool isDone;
  Task({required this.title, this.isDone = false});
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

  void _startListening() async {
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: Duration(seconds: 30),
      pauseFor: Duration(seconds: 5),
      partialResults: true,
    );
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _wordsSpoken = result.recognizedWords;
      _confidenceLevel = result.confidence;

      if (_wordsSpoken.isNotEmpty) {
        _tasks.add(Task(title: _wordsSpoken));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TO DO LIST',
          style: TextStyle(color: Colors.white70,fontWeight: FontWeight.bold,fontSize: 33,
          ),
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
                      ? "Dodirni mikrofon da kazes nesto..."
                      : "GRESKA!",
              style: const TextStyle(fontSize: 16, color:Colors.black54),
              textAlign: TextAlign.center,
              
            ),
          ),
          if (_speechToText.isNotListening && _confidenceLevel > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                "Podudaranje: ${(_confidenceLevel * 100).toStringAsFixed(1)}%",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                ),
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
                    onChanged: (value) {
                      setState(() {
                        task.isDone = value!;
                      });
                    },
                  ),
                  title: Text(
                    task.title,
                    style: TextStyle(fontSize: 18,decoration: task.isDone
                          ? TextDecoration.lineThrough
                          : TextDecoration.underline,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_sharp),
                    onPressed: () {
                      setState(() {
                        _tasks.removeAt(index);
                      });
                    },
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
