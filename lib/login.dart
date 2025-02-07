import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coinquiz/list_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? errorMessage;
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      errorMessage = null;
    });

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => CalendarListScreen()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = _getAuthErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Si è verificato un errore inatteso.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
      }
    } catch (e) {
      _showErrorDialog('Errore durante l\'aggiornamento del nickname.');
    }
  }

  Future<void> _register() async {
  final TextEditingController nicknameController = TextEditingController();

    setState(() {
      _isLoading = true;
      errorMessage = null;
      
    });

    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
       await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Inserisci un nickname'),
          content: TextField(
            controller: nicknameController,
            decoration: InputDecoration(
              labelText: 'nickname',
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final newNickname = nicknameController.text.trim();
                if (newNickname.isNotEmpty) {
                  Navigator.pop(context);  // Chiudi il dialog
                  await _updateNickname(newNickname);
                } else {
                  _showErrorDialog('Il nickname non può essere vuoto.');
                }
              },
              child: Text('Salva'),
            )
          ],
        );
      },
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => CalendarListScreen()),
    );
  } on FirebaseAuthException catch (e) {
    setState(() {
      errorMessage = _getAuthErrorMessage(e.code);
    });
  } catch (e) {
    setState(() {
      errorMessage = 'Si è verificato un errore inatteso.';
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'invalid-email':
        return 'L\'email inserita non è valida.';
      case 'user-disabled':
        return 'Questo account è stato disabilitato.';
      case 'user-not-found':
        return 'Nessun account trovato con questa email.';
      case 'wrong-password':
        return 'Password errata.';
      case 'email-already-in-use':
        return 'L\'email è già in uso da un altro account.';
      case 'weak-password':
        return 'La password è troppo debole.';
      default:
        return 'Credenziali non valide';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF121212), Color(0xFF1F1F1F)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Card(
              color: const Color(0xFF1E1E1E).withOpacity(0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              elevation: 20.0,
              shadowColor:
                  const Color.fromARGB(255, 141, 137, 137).withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(25.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Benvenuto!',
                      style: TextStyle(
                        fontSize: 26.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (errorMessage != null) ...[
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                    ],
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF2C2C2C),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF2C2C2C),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 30),
                    if (_isLoading)
                      const Center(
                          child: CircularProgressIndicator(color: Colors.white))
                    else ...[
                      ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3D5AFE),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15.0),
                        ),
                        child: const Text(
                          'Accedi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _register,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          side: const BorderSide(color: Colors.blueAccent),
                          padding: const EdgeInsets.symmetric(vertical: 15.0),
                        ),
                        child: const Text('Registrati',
                            style: TextStyle(color: Colors.blueAccent)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
