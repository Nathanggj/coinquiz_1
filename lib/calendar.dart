import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coinquiz/shopping_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:table_calendar/table_calendar.dart';
import 'splitwise.dart';

class CalendarScreen extends StatefulWidget {
  final String calendarName;

  const CalendarScreen({super.key, required this.calendarName});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final TextEditingController _eventController = TextEditingController();
  List<Map<String, dynamic>> _events = []; // Lista per memorizzare gli eventi
  Map<DateTime, List> _eventMarkers = {}; // Mappa per i giorni con eventi

  @override
  void initState() {
    super.initState();
    _loadEventsForCalendar();
    _selectedDay = _focusedDay;
    _loadEventsForDay(_focusedDay);
  }

  // Funzione per aprire la lista della spesa
  void _openShoppingList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShoppingListScreen(
          calendarName: widget.calendarName,
        ), // Passa gli eventi
      ),
    );
  }

  void _openSplitwise() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AddExpenseScreen(calendarId: widget.calendarName),
    ),
  );
}

  Future<void> _loadEventsForCalendar() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('events')
        .where('calendarName', isEqualTo: widget.calendarName)
        .get();

    setState(() {
      _eventMarkers = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final eventDate = DateTime.parse(data['date']);
        final normalizedDate =
            DateTime(eventDate.year, eventDate.month, eventDate.day);

        if (_eventMarkers[normalizedDate] == null) {
          _eventMarkers[normalizedDate] = [];
        }
        _eventMarkers[normalizedDate]?.add(data['event']);
      }
    });
  }

  // Funzione per caricare gli eventi da Firestore
  Future<void> _loadEventsForDay(DateTime day) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('events')
        .where('calendarName', isEqualTo: widget.calendarName)
        .where('date',
            isEqualTo: DateTime(day.year, day.month, day.day)
                .toIso8601String()
                .split('T')[0])
        .get();

    setState(() {
      _events = querySnapshot.docs
          .map((doc) => {'id': doc.id, 'data': doc.data()})
          .toList();

      // Aggiungi gli eventi al calendario
      for (var event in _events) {
        DateTime eventDate = DateTime.parse(event['data']['date']);
        eventDate = DateTime(eventDate.year, eventDate.month, eventDate.day);

        // Evita duplicati controllando se il marker esiste già
        if (_eventMarkers[eventDate] == null) {
          _eventMarkers[eventDate] = [];
        }
        if (!_eventMarkers[eventDate]!.contains(event['data']['event'])) {
          _eventMarkers[eventDate]?.add(event['data']['event']);
        }
      }
    });
  }

  Future<void> _addTurns() async {
    if (_eventController.text.isNotEmpty) {
      final event = _eventController.text;
      final selectedDate = _selectedDay ?? _focusedDay;

      // Mostra un dialogo per scegliere la frequenza dell'evento
      String? repeatFrequency = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Ripetizione turno'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('Ogni giorno'),
                  onTap: () => Navigator.pop(context, 'giorno'),
                ),
                ListTile(
                  title: Text('Ogni settimana'),
                  onTap: () => Navigator.pop(context, 'settimana'),
                ),
                ListTile(
                  title: Text('Ogni mese'),
                  onTap: () => Navigator.pop(context, 'mese'),
                ),
                ListTile(
                  title: Text('Ogni anno'),
                  onTap: () => Navigator.pop(context, 'anno'),
                ),
                ListTile(
                  title: Text('Non ripetere'),
                  onTap: () => Navigator.pop(context, 'none'),
                ),
                ListTile(
                  title: Text('Ripetizione personalizzata'),
                  onTap: () => Navigator.pop(context, 'personalizzato'),
                ),
              ],
            ),
          );
        },
      );

      if (repeatFrequency != null) {
        if (repeatFrequency == 'personalizzato') {
          // Dichiarare customValue prima di utilizzarlo
          int? customValue;

          // Chiedi all'utente il numero di giorni/settimanale/mensile/annuale
          customValue = await showDialog<int>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text('Ripetizione personalizzata'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Inserisci il numero di giorni:'),
                    TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        // Controlla se è un numero valido
                        customValue = int.tryParse(value);
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, customValue),
                    child: Text('OK'),
                  ),
                ],
              );
            },
          );

          if (customValue != null && customValue! > 0) {
            // Aggiungi gli eventi ripetuti per il numero di giorni inseriti
            for (int i = 0; i < 12; i++) {
              DateTime nextEventDate =
                  selectedDate.add(Duration(days: customValue! * i));

              await FirebaseFirestore.instance.collection('events').add({
                'calendarName': widget.calendarName,
                'date': nextEventDate.toIso8601String().split('T')[0],
                'event': event,
              });
            }
          }
        } else if (repeatFrequency == 'none') {
          // Evento non ripetuto, aggiungi solo per la data selezionata
          await FirebaseFirestore.instance.collection('events').add({
            'calendarName': widget.calendarName,
            'date': selectedDate.toIso8601String().split('T')[0],
            'event': event,
          });
        } else {
          // Altre ripetizioni (giorno, settimana, mese, anno)
          for (int i = 0; i < 12; i++) {
            DateTime nextEventDate;

            if (repeatFrequency == 'giorno') {
              nextEventDate = selectedDate.add(Duration(days: i));
            } else if (repeatFrequency == 'settimana') {
              nextEventDate = selectedDate.add(Duration(days: i * 7));
            } else if (repeatFrequency == 'mese') {
              nextEventDate = DateTime(
                  selectedDate.year, selectedDate.month + i, selectedDate.day);
            } else if (repeatFrequency == 'anno') {
              nextEventDate = DateTime(
                  selectedDate.year + i, selectedDate.month, selectedDate.day);
            } else {
              continue;
            }

            await FirebaseFirestore.instance.collection('events').add({
              'calendarName': widget.calendarName,
              'date': nextEventDate.toIso8601String().split('T')[0],
              'event': event,
            });
          }
        }
      }

      _eventController.clear();
      Navigator.pop(context);

      // Ricarica gli eventi
      _loadEventsForDay(selectedDate);
      _loadEventsForCalendar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Evento aggiunto con successo!')),
      );
    }
  }

  // Funzione per aggiungere un evento
  Future<void> _addEvent() async {
    if (_eventController.text.isNotEmpty) {
      final event = _eventController.text;
      final selectedDate = _selectedDay ?? _focusedDay;

      // Aggiungi direttamente l'evento senza chiedere ripetizione
      await FirebaseFirestore.instance.collection('events').add({
        'calendarName': widget.calendarName,
        'date': selectedDate.toIso8601String().split('T')[0],
        'event': event,
      });

      _eventController.clear();
      Navigator.pop(context);

      // Ricarica gli eventi
      _loadEventsForDay(selectedDate);
      _loadEventsForCalendar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Evento aggiunto con successo!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212), // Sfondo scuro
      appBar: AppBar(
        backgroundColor: Color(0xFF1F1F1F), // Colore della barra superiore
        title: Text(
          widget.calendarName,
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.today, color: Colors.white),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = _focusedDay;
              });
              _loadEventsForDay(_focusedDay);
              _loadEventsForCalendar();
            },
          ),
          IconButton(
            icon: Icon(Icons.shopping_cart, color: Colors.white),
            onPressed: _openShoppingList,
          ),
          IconButton(
            icon: Icon(Icons.euro, color: Colors.white),
            onPressed: _openSplitwise,
          ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TableCalendar(
                  focusedDay: _focusedDay,
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _loadEventsForDay(selectedDay);
                    _loadEventsForCalendar();
                  },
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    isTodayHighlighted: true,
                    selectedDecoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.tealAccent,
                      shape: BoxShape.circle,
                    ),
                    weekendTextStyle: TextStyle(color: Colors.redAccent),
                    defaultTextStyle: TextStyle(color: Colors.white),
                  ),
                  headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      leftChevronIcon:
                          Icon(Icons.chevron_left, color: Colors.white),
                      rightChevronIcon: Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                      )),
                  eventLoader: (day) {
                    final normalizedDay =
                        DateTime(day.year, day.month, day.day);
                    return _eventMarkers[normalizedDay] ?? [];
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isNotEmpty) {
                        return Positioned(
                          bottom: 4,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: Colors.deepOrange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }
                      return SizedBox();
                    },
                  ),
                ),
              ),
              Divider(color: Colors.grey),
              _events.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'Nessun evento per questo giorno.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        return Card(
                          color: Color(0xFF1F1F1F),
                          margin: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 16.0),
                          child: ListTile(
                            title: Text(
                              event['data']['event'],
                              style: TextStyle(color: Colors.white),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('events')
                                    .doc(event['id'])
                                    .delete();

                                // Rimuovi l'evento dai marker
                                final eventDate =
                                    DateTime.parse(event['data']['date']);
                                final normalizedDate = DateTime(eventDate.year,
                                    eventDate.month, eventDate.day);

                                setState(() {
                                  _events.removeAt(index);
                                  _eventMarkers[normalizedDate]
                                      ?.remove(event['data']['event']);
                                  // Rimuovi il giorno dalla mappa se non ci sono più eventi
                                  if (_eventMarkers[normalizedDate]?.isEmpty ??
                                      false) {
                                    _eventMarkers.remove(normalizedDate);
                                  }
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Evento eliminato con successo!')),
                                );

                                _loadEventsForDay(_selectedDay!);
                                _loadEventsForCalendar();
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
      floatingActionButton: SpeedDial(
        backgroundColor: Colors.blueAccent,
        icon: Icons.add,
        overlayOpacity: 0.1,
        activeIcon: Icons.close,
        children: [
          SpeedDialChild(
            child: Icon(Icons.star),
            label: 'Evento',
            labelStyle: TextStyle(color: Colors.black),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    backgroundColor: Color(0xFF1F1F1F),
                    title: Text(
                      'Aggiungi evento',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: TextField(
                      controller: _eventController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Descrizione evento',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.blueAccent),
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Annulla',
                            style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        onPressed: _addEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                        ),
                        child: Text(
                          'Aggiungi',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          SpeedDialChild(
              child: Icon(Icons.local_laundry_service_sharp),
              label: 'Turni',
              labelStyle: TextStyle(color: Colors.black),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      backgroundColor: Color(0xFF1F1F1F),
                      title: Text(
                        'Aggiungi Turno',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: TextField(
                        controller: _eventController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Descrizione evento',
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white54),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.blueAccent),
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Annulla',
                              style: TextStyle(color: Colors.white)),
                        ),
                        ElevatedButton(
                          onPressed: _addTurns,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                          ),
                          child: Text(
                            'Aggiungi',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    );
                  },
                );
              }),
        ],
      ),
    );
  }
}
