import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddExpenseScreen extends StatefulWidget {
  final String calendarId;

  const AddExpenseScreen({super.key, required this.calendarId});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  List<Map<String, String>> userIdWithNicknames = [];
  Map<String, String> userIdToNickname = {};
  List<Map<String, dynamic>> debts = [];
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> expenses = []; // Lista per le spese

  // Variabili per il form di inserimento della spesa
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String? selectedUserdId;
  List<String> selectedSplitWith = [];

  int anonymousCounter = 1; // Contatore per gli utenti anonimi

  @override
  void initState() {
    super.initState();
    _fetchUserIdsAndNicknames();
    _fetchExpenses(); // Carica le spese
    _loadDebts();
  }

  Future<void> _loadDebts() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('debiti')
          .where('calendarId', isEqualTo: widget.calendarId)
          .get();

      final List<Map<String, dynamic>> fetchedDebts =
          querySnapshot.docs.map((doc) {
        final debtData = doc.data();
        // Verifica che 'debts' sia presente e che sia una mappa
        final Map<String, dynamic> debtsMap =
            Map<String, dynamic>.from(debtData['debts'] ?? {});
        return {
          'userId': debtData['userId'],
          'debts': debtsMap, // Mappa degli utenti con il debito
        };
      }).toList();

      setState(() {
        debts = fetchedDebts;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  Future<void> _fetchUserIdsAndNicknames() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('calendars')
          .where('name', isEqualTo: widget.calendarId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final calendarData = querySnapshot.docs.first.data();

        if (calendarData.containsKey('userIds') &&
            calendarData['userIds'] is List) {
          final List<String> userIds =
              List<String>.from(calendarData['userIds']);
          final List<Map<String, String>> mappedUsers = [];

          for (final userId in userIds) {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();

            final nickname = userDoc.exists &&
                    userDoc.data()!.containsKey('nickname')
                ? userDoc['nickname'] as String
                : 'Anonimo ${anonymousCounter++}'; // Usa il contatore per gli anonimi

            mappedUsers.add({'userId': userId, 'nickname': nickname});
            userIdToNickname[userId] = nickname; // Mappa ID -> Nickname
          }

          setState(() {
            userIdWithNicknames = mappedUsers;
            isLoading = false;
          });
        } else {
          throw Exception('Il campo "userIds" non è presente o non è valido.');
        }
      } else {
        throw Exception('Calendario non trovato.');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // Funzione per caricare le spese
  Future<void> _fetchExpenses() async {
    try {
      final expenseSnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('calendarId', isEqualTo: widget.calendarId)
          .get();

      final List<Map<String, dynamic>> fetchedExpenses = expenseSnapshot.docs
          .map((doc) => {
                'title': doc['title'],
                'amount': doc['amount'],
                'date': doc['date'],
                'paidBy': doc['paidBy'],
                'splitWith': List<String>.from(doc['splitWith']),
              })
          .toList();

      setState(() {
        expenses = fetchedExpenses;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  // Funzione per aggiungere una spesa
  Future<void> _addExpense() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        // Creazione della nuova spesa
        final newExpense = {
          'calendarId': widget.calendarId,
          'title': _titleController.text,
          'amount': double.parse(_amountController.text),
          'date': Timestamp.now(),
          'paidBy': selectedUserdId, // Chi ha pagato
          'splitWith': selectedSplitWith // Chi divide la spesa
        };

        // Aggiungi la spesa nella collezione 'expenses'
        await FirebaseFirestore.instance.collection('expenses').add(newExpense);

        // Calcolare la parte di debito per ogni utente
        final amount = double.parse(_amountController.text);
        final numOfUsers =
            selectedSplitWith.length; // Numero di utenti che dividono la spesa
        final splitAmount =
            (amount / numOfUsers).toStringAsFixed(2); // Formattato a 2 cifre

        // Aggiornare i debiti per ogni utente che non ha pagato
        for (final userId in selectedSplitWith) {
          if (userId != selectedUserdId) {
            // Escludi l'utente che ha pagato
            await _updateDebt(
                userId,
                double.parse(
                    splitAmount)); // Aggiorna il debito per gli utenti che dividono la spesa
          }
        }

        // Ricarica le spese e i debiti
        _fetchExpenses();
        _loadDebts();

        // Pulisci i campi del form
        _titleController.clear();
        _amountController.clear();
        selectedUserdId = null;
        selectedSplitWith.clear();

        // Chiudi il form
        Navigator.pop(context);
      } catch (e) {
        setState(() {
          errorMessage = e.toString();
        });
      }
    }
  }

  // Funzione per aggiornare il debito (usata in _addExpense)
  Future<void> _updateDebt(String userId, double amount) async {
    try {
      final debtDoc = await FirebaseFirestore.instance
          .collection('debiti')
          .where('calendarId', isEqualTo: widget.calendarId)
          .where('userId', isEqualTo: userId)
          .get();

      if (debtDoc.docs.isNotEmpty) {
        final debtRef = debtDoc.docs.first.reference;
        final debtData = debtDoc.docs.first.data();
        final debtsMap = Map<String, dynamic>.from(debtData['debts'] ?? {});

        // Aggiungi l'importo del debito per l'utente che ha pagato
        final otherUserId = selectedUserdId;
        if (otherUserId != null) {
          debtsMap[otherUserId] = (debtsMap[otherUserId] ?? 0) + amount;
        }

        await debtRef.update({
          'debts': debtsMap,
        });
      } else {
        await FirebaseFirestore.instance.collection('debiti').add({
          'calendarId': widget.calendarId,
          'userId': userId,
          'debts': {
            selectedUserdId: amount,
          },
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  // Funzione per mostrare il form di inserimento della spesa
  void _showAddExpenseForm() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Aggiungi Spesa"),
            contentPadding:
                const EdgeInsets.only(top: 20, bottom: 10, left: 24, right: 24),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedUserdId,
                      decoration:
                          const InputDecoration(labelText: 'Chi ha pagato?'),
                      items: userIdWithNicknames.map((user) {
                        return DropdownMenuItem<String>(
                          value: user['userId'],
                          child: Text(user['nickname'] ?? 'Anonimo'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedUserdId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Seleziona un utente';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Titolo'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Il titolo è obbligatorio';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(labelText: 'Importo'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'L\'importo è obbligatorio';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Inserisci un importo valido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    const Text("Dividere con:"),
                    Wrap(
                      spacing: 8,
                      children: userIdWithNicknames.map((user) {
                        final isSelected =
                            selectedSplitWith.contains(user['userId']);
                        return ChoiceChip(
                          label: Text(user['nickname'] ?? 'Anonimo'),
                          selected: isSelected,
                          selectedColor: Colors.blueAccent,
                          backgroundColor: Colors.grey[300],
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedSplitWith.add(user['userId']!);
                              } else {
                                selectedSplitWith.remove(user['userId']);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.only(bottom: 10),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Annulla"),
              ),
              TextButton(
                onPressed: _addExpense,
                child: const Text("Aggiungi"),
              ),
            ],
          );
        });
      },
    );
  }

  // ===============================
  // Sezione "Pareggia debiti"
  // ===============================
  // Mostra il dialogo per pareggiare i debiti
  void _showMatchDebtDialog() {
    showDialog(
      context: context,
      builder: (context) {
        // Variabili locali per il dialogo
        String? selectedPayerId;
        String? selectedReceiverId;
        TextEditingController matchAmountController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Pareggia Debiti"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Seleziona l'utente che paga
                    DropdownButtonFormField<String>(
                      value: selectedPayerId,
                      decoration:
                          const InputDecoration(labelText: 'Utente che paga'),
                      items: userIdWithNicknames.map((user) {
                        return DropdownMenuItem<String>(
                          value: user['userId'],
                          child: Text(user['nickname'] ?? 'Anonimo'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedPayerId = value;
                        });
                      },
                    ),
                    // Inserisci l'importo
                    TextFormField(
                      controller: matchAmountController,
                      decoration:
                          const InputDecoration(labelText: 'Importo da pagare'),
                      keyboardType: TextInputType.number,
                    ),
                    // Seleziona l'utente che riceve il pagamento
                    DropdownButtonFormField<String>(
                      value: selectedReceiverId,
                      decoration: const InputDecoration(
                          labelText: 'Destinatario del pagamento'),
                      items: userIdWithNicknames.map((user) {
                        return DropdownMenuItem<String>(
                          value: user['userId'],
                          child: Text(user['nickname'] ?? 'Anonimo'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedReceiverId = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annulla"),
                ),
                TextButton(
                  onPressed: () async {
                    // Verifica che tutti i campi siano compilati
                    if (selectedPayerId != null &&
                        selectedReceiverId != null &&
                        matchAmountController.text.isNotEmpty) {
                      double amount = double.parse(matchAmountController.text);
                      await _updateDebtMatch(
                          selectedPayerId!, selectedReceiverId!, amount);
                      // Ricarica i debiti aggiornati
                      _loadDebts();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Conferma"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Funzione per aggiornare il debito nel database in seguito al pareggio.
  // Se l'importo pagato azzera (o supera) il debito, il campo viene rimosso.
  Future<void> _updateDebtMatch(
      String payerId, String receiverId, double amount) async {
    try {
      // Aggiorna il documento del pagatore: riduce il debito verso il ricevente
      final payerDebtQuery = await FirebaseFirestore.instance
          .collection('debiti')
          .where('calendarId', isEqualTo: widget.calendarId)
          .where('userId', isEqualTo: payerId)
          .get();

      if (payerDebtQuery.docs.isNotEmpty) {
        final payerDebtRef = payerDebtQuery.docs.first.reference;
        final payerDebtData = payerDebtQuery.docs.first.data();
        final Map<String, dynamic> payerDebts =
            Map<String, dynamic>.from(payerDebtData['debts'] ?? {});
        if (payerDebts.containsKey(receiverId)) {
          double currentDebt = (payerDebts[receiverId] as num).toDouble();
          double newDebt = currentDebt - amount;
          if (newDebt <= 0) {
            // Debito saldato o ecceduto: rimuovo il campo
            payerDebts.remove(receiverId);
          } else {
            payerDebts[receiverId] = newDebt;
          }
          await payerDebtRef.update({'debts': payerDebts});
        }
      }

      // Aggiorna il documento del ricevente: riduce il credito verso il pagatore
      final receiverDebtQuery = await FirebaseFirestore.instance
          .collection('debiti')
          .where('calendarId', isEqualTo: widget.calendarId)
          .where('userId', isEqualTo: receiverId)
          .get();

      if (receiverDebtQuery.docs.isNotEmpty) {
        final receiverDebtRef = receiverDebtQuery.docs.first.reference;
        final receiverDebtData = receiverDebtQuery.docs.first.data();
        final Map<String, dynamic> receiverDebts =
            Map<String, dynamic>.from(receiverDebtData['debts'] ?? {});
        if (receiverDebts.containsKey(payerId)) {
          double currentCredit = (receiverDebts[payerId] as num).toDouble();
          double newCredit = currentCredit - amount;
          if (newCredit <= 0) {
            receiverDebts.remove(payerId);
          } else {
            receiverDebts[payerId] = newCredit;
          }
          await receiverDebtRef.update({'debts': receiverDebts});
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  // ===============================
  // Costruzione dell'interfaccia
  // ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title:
            const Text("Gestione spese", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spese del gruppo ${widget.calendarId}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        // Card per gli utenti (debiti)
                        Center(
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 5,
                            shadowColor: Colors.white.withOpacity(1),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 400,
                                minWidth: 300,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: debts.length,
                                  itemBuilder: (context, index) {
                                    final debt = debts[index];
                                    final userId = debt['userId'];
                                    final userNickname =
                                        userIdToNickname[userId] ?? 'Anonimo';

                                    // Mappa dei debiti dell'utente corrente
                                    final debtMap =
                                        debt['debts'] as Map<String, dynamic>;

                                    List<Widget> debtWidgets = [];
                                    debtMap.forEach((otherUserId, amount) {
                                      final otherUserNickname =
                                          userIdToNickname[otherUserId] ??
                                              'Anonimo';
                                      // Mostra l'importo con 2 cifre decimali
                                      debtWidgets.add(Text(
                                        '$otherUserNickname: €${(amount as num).toDouble().toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 12),
                                      ));
                                    });

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$userNickname deve a:',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 4),
                                          ...debtWidgets,
                                          const Divider(),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Pulsante "Pareggia" tra le due card
                        Center(
                            child: SizedBox(
                          width: double
                              .infinity, // Occupa tutta la larghezza disponibile
                          child: ElevatedButton(
                            onPressed: _showMatchDebtDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 105, 106, 108),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 2,
                              shadowColor: Colors.white,
                            ),
                            child: const Text(
                              "Pareggia",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white
                              ),
                            ),
                          ),
                        )),

                        const SizedBox(height: 2),
                        // Card per le spese
                        Center(
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 5,
                            shadowColor: Colors.white.withOpacity(1),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: expenses.length,
                                      itemBuilder: (context, index) {
                                        final expense = expenses[index];
                                        final title = expense['title'];
                                        final amount = expense['amount'] as num;
                                        final date =
                                            (expense['date'] as Timestamp)
                                                .toDate();
                                        final dateFormat =
                                            DateFormat('yyyy/MM/dd HH:mm');
                                        final formattedDate =
                                            dateFormat.format(date);
                                        final paidBy = userIdToNickname[
                                                expense['paidBy']] ??
                                            'Anonimo';
                                        final splitWith = (expense['splitWith']
                                                as List<String>)
                                            .map((id) =>
                                                userIdToNickname[id] ??
                                                'Anonimo')
                                            .join(', ');

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '$title',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Importo: €${amount.toDouble().toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Data: $formattedDate',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Pagato da: $paidBy',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Diviso con: $splitWith',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              const Divider(),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}
