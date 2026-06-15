import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const EventCountdownApp());
}

class EventCountdownApp extends StatelessWidget {
  const EventCountdownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Event Countdown',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6B6B)),
        textTheme: GoogleFonts.dmSansTextTheme(),
      ),
      home: const EventHomePage(),
    );
  }
}

class CountdownEvent {
  CountdownEvent({
    required this.id,
    required this.title,
    required this.targetDate,
    required this.category,
  });

  final String id;
  final String title;
  final DateTime targetDate;
  final String category;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'targetDate': targetDate.toIso8601String(),
      'category': category,
    };
  }

  factory CountdownEvent.fromMap(Map<String, dynamic> map) {
    return CountdownEvent(
      id: map['id'] as String,
      title: map['title'] as String,
      targetDate: DateTime.parse(map['targetDate'] as String),
      category: map['category'] as String,
    );
  }
}

class EventHomePage extends StatefulWidget {
  const EventHomePage({super.key});

  @override
  State<EventHomePage> createState() => _EventHomePageState();
}

class _EventHomePageState extends State<EventHomePage> {
  static const String _eventsKey = 'events_json';
  static const String _widgetProviderName = 'EventCountdownWidgetProvider';

  static const List<Map<String, String>> _categories = [
    {'name': 'Vacation', 'emoji': '🏖️'},
    {'name': 'Wedding', 'emoji': '💍'},
    {'name': 'Birthday', 'emoji': '🎂'},
    {'name': 'Exam', 'emoji': '📝'},
    {'name': 'Custom', 'emoji': '⭐'},
  ];

  static const List<Map<String, dynamic>> _quickTemplates = [
    {'label': '🏖️ Vacation', 'title': 'Summer Vacation', 'category': 'Vacation', 'days': 90},
    {'label': '💍 Wedding', 'title': 'Wedding Day', 'category': 'Wedding', 'days': 120},
    {'label': '🎂 Birthday', 'title': 'Birthday Party', 'category': 'Birthday', 'days': 30},
    {'label': '📝 Exam', 'title': 'Final Exam', 'category': 'Exam', 'days': 21},
  ];

  final List<CountdownEvent> _events = [];
  String _activeCategory = 'All';
  String _sortMode = 'Soonest';
  bool _loading = true;

  List<CountdownEvent> _visibleEvents(DateTime now) {
    final filtered = _activeCategory == 'All'
        ? List<CountdownEvent>.from(_events)
        : _events.where((event) => event.category == _activeCategory).toList();

    switch (_sortMode) {
      case 'Latest':
        filtered.sort((a, b) => b.targetDate.compareTo(a.targetDate));
        break;
      case 'A-Z':
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'Z-A':
        filtered.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case 'Soonest':
      default:
        filtered.sort((a, b) {
          final aDays = _daysUntil(a.targetDate, now);
          final bDays = _daysUntil(b.targetDate, now);
          final aRank = aDays < 0 ? 100000 + aDays.abs() : aDays;
          final bRank = bDays < 0 ? 100000 + bDays.abs() : bDays;
          return aRank.compareTo(bRank);
        });
        break;
    }

    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_eventsKey);
    if (raw == null || raw.isEmpty) {
      setState(() => _loading = false);
      await _updateHomeWidget();
      return;
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    final loaded = decoded
        .map((item) => CountdownEvent.fromMap(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate));

    setState(() {
      _events
        ..clear()
        ..addAll(loaded);
      _loading = false;
    });

    await _updateHomeWidget();
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_events.map((e) => e.toMap()).toList(growable: false));
    await prefs.setString(_eventsKey, raw);
    await _updateHomeWidget();
  }

  Future<void> _updateHomeWidget() async {
    if (_events.isEmpty) {
      await HomeWidget.saveWidgetData<String>('title', 'Add your first event');
      await HomeWidget.saveWidgetData<String>('days', 'Start counting today');
      await HomeWidget.updateWidget(androidName: _widgetProviderName);
      return;
    }

    final now = DateTime.now();
    _events.sort((a, b) => a.targetDate.compareTo(b.targetDate));
    final next = _events.firstWhere(
      (event) => _daysUntil(event.targetDate, now) >= 0,
      orElse: () => _events.first,
    );
    await HomeWidget.saveWidgetData<String>('title', '${_categoryEmoji(next.category)} ${next.title}');
    await HomeWidget.saveWidgetData<String>('days', _daysLabel(next, now));
    await HomeWidget.updateWidget(androidName: _widgetProviderName);
  }

  String _categoryEmoji(String category) {
    for (final item in _categories) {
      if (item['name'] == category) {
        return item['emoji']!;
      }
    }
    return '⭐';
  }

  int _daysUntil(DateTime target, DateTime now) {
    final baseNow = DateTime(now.year, now.month, now.day);
    final baseTarget = DateTime(target.year, target.month, target.day);
    return baseTarget.difference(baseNow).inDays;
  }

  String _daysLabel(CountdownEvent event, DateTime now) {
    final days = _daysUntil(event.targetDate, now);
    if (days > 0) {
      return '$days days left';
    }
    if (days == 0) {
      return 'Today';
    }
    return '${days.abs()} days ago';
  }

  Future<void> _showAddEventDialog({CountdownEvent? editing}) async {
    final titleController = TextEditingController(text: editing?.title ?? '');
    var selectedDate = editing?.targetDate ?? DateTime.now().add(const Duration(days: 7));
    var selectedCategory = editing?.category ?? 'Vacation';
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(editing == null ? 'Add Event' : 'Edit Event'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (editing == null) ...[
                        Text(
                          'Quick templates',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _quickTemplates
                              .map(
                                (template) => ActionChip(
                                  label: Text(template['label'] as String),
                                  onPressed: () {
                                    setDialogState(() {
                                      titleController.text = template['title'] as String;
                                      selectedCategory = template['category'] as String;
                                      selectedDate = DateTime.now().add(
                                        Duration(days: template['days'] as int),
                                      );
                                    });
                                  },
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Title is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: _categories
                            .map(
                              (item) => DropdownMenuItem(
                                value: item['name'],
                                child: Text('${item['emoji']} ${item['name']}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedCategory = value ?? selectedCategory);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Date: ${DateFormat.yMMMd().format(selectedDate)}'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                initialDate: selectedDate,
                              );
                              if (picked != null) {
                                setDialogState(() => selectedDate = picked);
                              }
                            },
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    final navigator = Navigator.of(context);

                    final event = CountdownEvent(
                      id: editing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleController.text.trim(),
                      targetDate: selectedDate,
                      category: selectedCategory,
                    );

                    setState(() {
                      if (editing == null) {
                        _events.add(event);
                      } else {
                        final index = _events.indexWhere((e) => e.id == editing.id);
                        if (index != -1) {
                          _events[index] = event;
                        }
                      }
                      _events.sort((a, b) => a.targetDate.compareTo(b.targetDate));
                    });

                    await _saveEvents();
                    if (mounted) {
                      navigator.pop();
                    }
                  },
                  child: Text(editing == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEvent(String id) async {
    setState(() {
      _events.removeWhere((e) => e.id == id);
    });
    await _saveEvents();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final visibleEvents = _visibleEvents(now);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Countdown'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _sortMode,
            tooltip: 'Sort',
            onSelected: (value) {
              setState(() => _sortMode = value);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'Soonest', child: Text('Sort: Soonest first')),
              PopupMenuItem(value: 'Latest', child: Text('Sort: Latest first')),
              PopupMenuItem(value: 'A-Z', child: Text('Sort: Title A-Z')),
              PopupMenuItem(value: 'Z-A', child: Text('Sort: Title Z-A')),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF4F2), Color(0xFFF6FAFF)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _events.isEmpty
                ? const _EmptyState()
                : Column(
                    children: [
                      SizedBox(
                        height: 48,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: [
                            ChoiceChip(
                              label: const Text('All'),
                              selected: _activeCategory == 'All',
                              onSelected: (_) {
                                setState(() => _activeCategory = 'All');
                              },
                            ),
                            const SizedBox(width: 8),
                            ..._categories.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text('${item['emoji']} ${item['name']}'),
                                  selected: _activeCategory == item['name'],
                                  onSelected: (_) {
                                    setState(() => _activeCategory = item['name']!);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: visibleEvents.isEmpty
                            ? const Center(
                                child: Text('No events in this category yet.'),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: visibleEvents.length,
                                itemBuilder: (context, index) {
                                  final event = visibleEvents[index];
                                  final days = _daysUntil(event.targetDate, now);
                                  final accent = days < 0
                                      ? const Color(0xFF9CA3AF)
                                      : days == 0
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF3B82F6);

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: accent.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Center(
                                              child: Text(
                                                _categoryEmoji(event.category),
                                                style: const TextStyle(fontSize: 26),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  event.title,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(fontWeight: FontWeight.w700),
                                                ),
                                                Text(
                                                  '${event.category} · ${DateFormat.yMMMd().format(event.targetDate)}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(color: Colors.black54),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _daysLabel(event, now),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: accent,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _showAddEventDialog(editing: event);
                                              }
                                              if (value == 'delete') {
                                                _deleteEvent(event.id);
                                              }
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEventDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Event'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📅', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 14),
            Text(
              'Start your first countdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Track vacations, weddings, birthdays, and exams.\nEverything stays local on your device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
