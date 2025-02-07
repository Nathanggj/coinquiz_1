import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Importa il pacchetto intl

class ShoppingListScreen extends StatefulWidget {
  final String calendarName;

  ShoppingListScreen({Key? key, required this.calendarName}) : super(key: key);

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final TextEditingController _itemController = TextEditingController();
  String _nickname = 'Anonimo'; // Default nickname
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadNickname(); // Carica il nickname dell'utente corrente
  }

  Future<void> _loadNickname() async {
    final currentUser = _auth.currentUser;

    if (currentUser != null) {
      try {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();

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

  // Funzione per formattare la data
  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final DateFormat dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    return dateFormat.format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Spesa ${widget.calendarName}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2C2F3A),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFF1F2125),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('shopping_list')
                  .where('calendarName', isEqualTo: widget.calendarName)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final timestamp = item['timestamp'] as Timestamp;

                    return Card(
                      color: const Color(0xFF2A2D32),
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          item['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Aggiunto da: ${item['nickname'] ?? 'Anonimo'}\n in data: ${_formatTimestamp(timestamp)}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _firestore.collection('shopping_list').doc(item.id).delete();
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemController,
                    decoration: InputDecoration(
                      labelText: 'Aggiungi elemento',
                      labelStyle: const TextStyle(color: Colors.white),
                      filled: true,
                      fillColor: const Color(0xFF33393B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    if (_itemController.text.isNotEmpty) {
                      await _firestore.collection('shopping_list').add({
                        'calendarName': widget.calendarName,
                        'name': _itemController.text,
                        'timestamp': FieldValue.serverTimestamp(), // Salva il timestamp
                        'nickname': _nickname, // Salva il nickname dell'utente
                      });

                      _itemController.clear();
                    }
                  },
                  child: const Text(
                    'Aggiungi',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D7C9B),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
