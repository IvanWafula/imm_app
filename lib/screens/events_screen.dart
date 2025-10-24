import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'event_player_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<Map<String, dynamic>> events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }

  Future<void> fetchEvents() async {
    try {
      final response = await http.get(Uri.parse(Config.eventsEndpoint));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          events = data.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        throw Exception("Failed to load events");
      }
    } catch (e) {
      debugPrint("Error fetching events: $e");
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📅 Events")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final title = event['title'] ?? 'Untitled';
                final speaker = event['speaker'] ?? '';
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(title),
                    subtitle: Text(speaker),
                    trailing: const Icon(Icons.play_circle_fill, color: Colors.deepPurple),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventPlayerScreen(event: event),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
