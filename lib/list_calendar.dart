import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coinquiz/Roulette.dart';
import 'package:coinquiz/calendar.dart';
import 'package:coinquiz/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CalendarListScreen extends StatefulWidget {
  const CalendarListScreen({super.key});

  @override
  _CalendarListScreenState createState() => _CalendarListScreenState();
}

class _CalendarListScreenState extends State<CalendarListScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  List<QueryDocumentSnapshot> _calendars = [];
  QueryDocumentSnapshot? _selectedCalendar;
  String _nickname = "Caricamento...";

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchCalendars();
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    if (_currentUser != null) {
      try {
        final userDoc =
            await _firestore.collection('users').doc(_currentUser!.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          setState(() {
            _nickname = userDoc.data()!['nickname'] ?? 'Anonimo';
          });
        } else {
          setState(() {
            _nickname = 'Anonimo';
          });
        }
      } catch (e) {
        setState(() {
          _nickname = 'Errore';
        });
      }
    }
  }

  Future<void> _fetchCalendars() async {
    if (_currentUser != null) {
      final querySnapshot = await _firestore
          .collection('calendars')
          .where('userIds', arrayContains: _currentUser!.uid)
          .get();
      setState(() {
        _calendars = querySnapshot.docs;
        if (_calendars.isNotEmpty) {
          _selectedCalendar = _calendars.first;
        }
      });
    }
  }

  Future<void> _removeUserFromCalendar(String calendarId) async {
    try {
      final calendarRef = _firestore.collection('calendars').doc(calendarId);
      final calendarDoc = await calendarRef.get();
      List<dynamic> userIds = calendarDoc['userIds'];

      userIds.remove(_currentUser!.uid);

      await calendarRef.update({'userIds': userIds});
      await _fetchCalendars();
    } catch (e) {
      _showErrorDialog('Non è stato possibile rimuovere il calendario.');
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  Future<void> _addNewCalendar() async {
    final TextEditingController calendarController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Crea un nuovo calendario',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: calendarController,
                decoration: InputDecoration(
                  labelText: 'Nome del calendario',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                style: TextStyle(color: Colors.white),
              ),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Password del calendario',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                obscureText: true,
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annulla', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
              onPressed: () async {
                if (calendarController.text.isNotEmpty &&
                    passwordController.text.isNotEmpty) {
                  await _firestore.collection('calendars').add({
                    'userIds': [_currentUser!.uid],
                    'name': calendarController.text,
                    'password': passwordController.text,
                  });
                  await _fetchCalendars();
                  Navigator.pop(context);
                }
              },
              child: Text(
                'Crea',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addCalendarWithPassword() async {
    final TextEditingController passwordController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Aggiungi calendario con password',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: passwordController,
            decoration: InputDecoration(
              labelText: 'Inserisci la password del calendario',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            obscureText: true,
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annulla', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
              onPressed: () async {
                final password = passwordController.text;
                if (password.isNotEmpty) {
                  final calendarDoc = await _firestore
                      .collection('calendars')
                      .where('password', isEqualTo: password)
                      .limit(1)
                      .get();

                  if (calendarDoc.docs.isNotEmpty) {
                    await _firestore
                        .collection('calendars')
                        .doc(calendarDoc.docs.first.id)
                        .update({
                      'userIds': FieldValue.arrayUnion([_currentUser!.uid]),
                    });
                    await _fetchCalendars();
                    Navigator.pop(context);
                  } else {
                    _showErrorDialog('Password errata.');
                  }
                }
              },
              child: Text(
                'Aggiungi',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Errore', style: TextStyle(color: Colors.red)),
          content: Text(message, style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: Colors.blueGrey)),
            ),
          ],
        );
      },
    );
  }

  void _showAccountSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Impostazioni account',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit, color: Colors.white),
                title: Text('Cambia nickname',
                    style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.pop(context); // Chiude il menu principale
                  _showNicknameDialog(); // Apre il dialog del nickname
                },
              ),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.white),
                title: Text('Logout', style: TextStyle(color: Colors.white70)),
                onTap: () async {
                  Navigator.pop(context); // Chiudi il dialog
                  await _logout(); // Effettua il logout
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Chiudi', style: TextStyle(color: Colors.blueGrey)),
            ),
          ],
        );
      },
    );
  }

// Mostra il dialog per personalizzare il nickname
  void _showNicknameDialog() {
    final TextEditingController nicknameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Personalizza nickname',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: nicknameController,
            decoration: InputDecoration(
              labelText: 'Nuovo nickname',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annulla', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
              onPressed: () async {
                final newNickname = nicknameController.text.trim();
                if (newNickname.isNotEmpty) {
                  Navigator.pop(context); // Chiude il dialog
                  await _updateNickname(newNickname);
                  _loadNickname(); // Salva il nickname
                } else {
                  _showErrorDialog('Il nickname non può essere vuoto.');
                }
              },
              child: Text(
                'Salva',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

// Aggiorna il nickname nel database
  Future<void> _updateNickname(String newNickname) async {
    try {
      final user = _auth.currentUser;

      if (user != null) {
        final userRef = _firestore.collection('users').doc(user.uid);

        // Controlla se il documento esiste, altrimenti lo crea
        final userDoc = await userRef.get();
        if (!userDoc.exists) {
          await userRef.set({'nickname': newNickname});
        } else {
          await userRef.update({'nickname': newNickname});
        }

        _showSuccessDialog('Nickname aggiornato con successo!');
      }
    } catch (e) {
      _showErrorDialog('Errore durante l\'aggiornamento del nickname.');
    }
  }

// Mostra un messaggio di successo
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Successo', style: TextStyle(color: Colors.green)),
          content: Text(message, style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: Colors.blueGrey)),
            ),
          ],
        );
      },
    );
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: const Color.fromARGB(255, 97, 146, 171),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.end, // Allinea a destra
        children: [
          Text(
            _nickname, // Mostra il nickname
            style: TextStyle(color: Colors.black, fontSize: 18),
          ),
        ],
      ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.account_circle_sharp,
              color: Colors.black,
            ),
            onPressed: _showAccountSettings,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.grey[900],
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color.fromARGB(255, 105, 162, 190),
              padding: EdgeInsets.all(30.0),
              child: Text(
                'I tuoi calendari',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ..._calendars.map((calendar) {
                    return ListTile(
                      title: Text(
                        calendar['name'],
                        style: TextStyle(color: Colors.white70),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedCalendar = calendar;
                        });
                        Navigator.pop(context);
                      },
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              backgroundColor: Colors.grey[900],
                              title: Text('Conferma rimozione',
                                  style: TextStyle(color: Colors.white)),
                              content: Text(
                                'Sei sicuro di voler rimuovere questo calendario?',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Annulla',
                                      style: TextStyle(color: Colors.red)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueGrey),
                                  onPressed: () {
                                    _removeUserFromCalendar(calendar.id);
                                    Navigator.pop(context);
                                  },
                                  child: Text('Rimuovi',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  }).toList(),
                  ListTile(
                    leading: Icon(Icons.add, color: Colors.white),
                    title: Text('Crea un nuovo calendario',
                        style: TextStyle(color: Colors.white70)),
                    onTap: _addNewCalendar,
                  ),
                  ListTile(
                    leading: Icon(Icons.lock, color: Colors.white),
                    title: Text('Aggiungi calendario con password',
                        style: TextStyle(color: Colors.white70)),
                    onTap: _addCalendarWithPassword,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(10.0),
              color: Colors.blueGrey[800],
              child: ListTile(
                title: Text('Turni Roulette',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => RouletteScreen()));
                },
              ),
            ),
          ],
        ),
      ),
      body: _selectedCalendar != null
          ? CalendarScreen(calendarName: _selectedCalendar!['name'])
          : Center(
              child: Text(
                'Non ci sono calendari. Aggiungine uno dalla tendina.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
    );
  }
}
