import 'dart:math';
import 'package:flutter/material.dart';

class RouletteScreen extends StatefulWidget {
  @override
  _RouletteScreenState createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _people = [];
  String? _selectedPerson;
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  bool _isSpinning = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 35 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addPerson() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Aggiungi persona',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Nome della persona',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.teal),
              ),
            ),
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annulla', style: TextStyle(color: Colors.teal)),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _people.add(controller.text);
                  });
                }
                Navigator.pop(context);
              },
              child: Text('Aggiungi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
              ),
            ),
          ],
        );
      },
    );
  }

  void _runRoulette() async {
    if (_people.isNotEmpty && !_isSpinning) {
      setState(() {
        _isSpinning = true;
      });

      final random = Random();
      _controller.reset();
      await _controller.forward();

      setState(() {
        _selectedPerson = _people[random.nextInt(_people.length)];
        _isSpinning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: Text('Turni Roulette', style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.black,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: Colors.white
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationAnimation.value,
                        child: CustomPaint(
                          size: Size(300, 300),
                          painter: _ModernRoulettePainter(people: _people),
                        ),
                      );
                    },
                  ),
                  if (_selectedPerson != null)
                    AnimatedOpacity(
                      opacity: _selectedPerson != null ? 1 : 0,
                      duration: Duration(milliseconds: 500),
                      child: Text(
                        _selectedPerson!,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.tealAccent,
                          shadows: [
                            Shadow(
                              blurRadius: 10.0,
                              color: Colors.black,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _addPerson,
                  icon: Icon(Icons.person_add),
                  label: Text('Aggiungi Persona'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _runRoulette,
                  icon: Icon(Icons.casino),
                  label: Text('Tira a sorte'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: TextStyle(fontSize: 16),
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

class _ModernRoulettePainter extends CustomPainter {
  final List<String> people;

  _ModernRoulettePainter({required this.people});

  @override
  void paint(Canvas canvas, Size size) {
    if (people.isEmpty) {
      final paint = Paint()
        ..color = Colors.grey[700]!
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width / 2,
        paint,
      );
      return;
    }

    final radius = size.width / 2;
    final angle = 2 * pi / people.length;
    final colors = _generateRouletteColors(people.length);
    final paint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < people.length; i++) {
      paint.shader = RadialGradient(
        colors: [colors[i], Colors.black],
        center: Alignment.center,
        radius: 1.2,
      ).createShader(Rect.fromCircle(
        center: Offset(radius, radius),
        radius: radius,
      ));

      canvas.drawArc(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius),
        angle * i,
        angle,
        true,
        paint,
      );

      final textAngle = angle * (i + 0.5);
      final x = radius + radius * 0.6 * cos(textAngle);
      final y = radius + radius * 0.6 * sin(textAngle);

      final textSpan = TextSpan(
        text: people[i].substring(0, min(3, people[i].length)).toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.text = textSpan;
      textPainter.layout();
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(textAngle - pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    paint.color = Colors.black;
    canvas.drawCircle(Offset(radius, radius), radius * 0.3, paint);

    paint.color = Colors.white;
    canvas.drawCircle(Offset(radius, radius), radius * 0.28, paint);
  }

  List<Color> _generateRouletteColors(int count) {
    final colors = <Color>[];
    for (int i = 0; i < count; i++) {
      if (i == 0) {
        colors.add(Colors.green);
      } else if (i % 2 == 0) {
        colors.add(Colors.red);
      } else {
        colors.add(Colors.blueGrey);
      }
    }
    return colors;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
