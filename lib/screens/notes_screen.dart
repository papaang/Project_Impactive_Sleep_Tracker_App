import 'package:flutter/material.dart';
import '../log_service.dart';

class NotesScreen extends StatefulWidget {
  final DateTime date;
  const NotesScreen({super.key, required this.date});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _controller = TextEditingController();
  final LogService _logService = LogService();
  bool _isLoading = true;
  String _originalText = "";

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      setState(() => _isLoading = true);
      final log = await _logService.getDailyLog(widget.date);
      final notes = log.notes ?? "";
      setState(() {
        _controller.text = notes;
        _originalText = notes;
      });
    } catch (e) {
       // handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNotes() async {
    if (_controller.text == _originalText) return;
     try {
      final log = await _logService.getDailyLog(widget.date);
      log.notes = _controller.text;
      await _logService.saveDailyLog(widget.date, log);
      // print("Notes auto-saved");
    } catch (e) { // print("Error auto-saving notes: $e");
    }
   }

  @override
  void dispose() {
    _saveNotes();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notes'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _controller,
                      decoration: const InputDecoration(
                      hintText: "Write your notes here...",
                        hintStyle: TextStyle(
                        color: Color(0xffDDDADA),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                    maxLines: 20,
                    autofocus: true,
                  ),
                ),
              ),
            ),
    );
  }
}
