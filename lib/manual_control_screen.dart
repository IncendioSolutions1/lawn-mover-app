import 'dart:async';
import 'dart:math';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_glow/flutter_glow.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Holds a polygon’s vertices and whether it’s closed.
class _Polygon {
  List<Offset> points;
  bool closed;
  _Polygon({required this.points, this.closed = false});
}

class ManualControlScreen extends StatefulWidget {
  const ManualControlScreen({super.key});
  @override
  ManualControlScreenState createState() => ManualControlScreenState();
}

class ManualControlScreenState extends State<ManualControlScreen> {
  // === Drawing state ===
  bool _drawingMain = true; // true: drawing the green boundary
  bool _noGoMode = false; // true: ready to draw red no-go areas
  final List<_Polygon> _polygons = []; // [0]=main, [1+]=no-go
  int _activePolygon = 0; // which polygon we’re editing

  // === Marker & joystick ===
  Offset _marker = Offset.zero; // current joystick-driven marker
  String _direction = 'IDLE';
  final double _step = 2.0;
  final double _joySize = 145.0;
  final double _iconSize = 16.0;

  // === Undo/Redo stacks for main boundary only ===
  final List<List<Offset>> _mainUndo = [];
  final List<List<Offset>> _mainRedo = [];

  bool _didInit = false;

  late WebSocketChannel channel;
  String response = "";
  ConnectionStatus connectionStatus = ConnectionStatus.connecting;
  Timer? _reconnectTimer;



  double _markerAngle = 0.0; // in radians
  // at top of your State:
  // static const double _maxTurnPerTick = pi / 8; // 22.5°
  bool _canTurn = true;
  final double _turnThreshold = 0.6;  // tweak to taste

  final _rng = Random();
  static const double _jitterAngleRadians = 0.3; // ±2.8°

  @override
  void initState() {
    super.initState();
    // Hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // Schedule a callback for *after* the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size; // get real size
      final center = Offset(size.width / 2, (size.height * 0.6) / 2);
      setState(() {
        _polygons.add(_Polygon(points: [center])); // seed your main polygon
        _marker = center;
        _didInit = true;
      });
    });

    _connectWebSocket();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    channel.sink.close();
    super.dispose();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    setState(() => connectionStatus = ConnectionStatus.disconnected);
    // try again in 3 seconds:
    _reconnectTimer = Timer(Duration(seconds: 3), () {
      if (mounted) _connectWebSocket();
    });
  }

  void _connectWebSocket() async {
      setState(() {
        connectionStatus = ConnectionStatus.connecting;
      });

      try {
        channel = WebSocketChannel.connect(
          Uri.parse('ws://192.168.4.1:81'), // or your static IP
        );

        channel.stream.listen(
          (message) {
            dev.log("Received from ESP32: $message");
            setState(() {
              response = message;
              connectionStatus = ConnectionStatus.connected;
            });
          },
          onDone: () {
            dev.log("WebSocket closed");
            setState(() {
              connectionStatus = ConnectionStatus.disconnected;
            });
            _scheduleReconnect();
          },
          onError: (error) {
            dev.log("WebSocket error: $error");
            setState(() {
              connectionStatus = ConnectionStatus.disconnected;
            });
            _scheduleReconnect();
          },
        );

      } catch (e) {
        dev.log("WebSocket connection failed: $e");
        setState(() {
          connectionStatus = ConnectionStatus.disconnected;
        });
      }
  }

  /// Joystick callback — `details.x`/`details.y` in [-1..1].
  // void _onJoystick(StickDragDetails details) {
  //   final input = Offset(details.x, details.y);
  //   // final input = Offset(details.x, -details.y);
  //
  //   if (input.distance == 0) {
  //     setState(() => _direction = 'IDLE');
  //     return;
  //   }
  //
  //   // Quantize to 8 directions.
  //   final dir = _get8dir(input);
  //
  //   // 3) Compute the base angle from +X axis
  //   final baseAngle = atan2(dir.dy, dir.dx);
  //   // offset by 90° so arrow_upward (which points -Y) aligns correctly
  //   final angle = baseAngle + pi/2;
  //
  //
  //
  //   // Compute new tentative position.
  //   var tent = _marker + dir * _step;
  //   final size = MediaQuery.of(context).size;
  //   tent = Offset(
  //     tent.dx.clamp(_iconSize / 2, size.width - _iconSize / 2),
  //     tent.dy.clamp(_iconSize / 2, size.height * 0.6 - _iconSize / 2),
  //   );
  //
  //   // If drawing a no-go area, ensure we never leave the main boundary.
  //   if (!_drawingMain && !_pointInPoly(tent, _polygons[0].points)) {
  //     return;
  //   }
  //
  //   // Record undo snapshot for main boundary only.
  //   if (_drawingMain && !_polygons[0].closed) {
  //     _mainUndo.add(List.from(_polygons[0].points));
  //     _mainRedo.clear();
  //   }
  //
  //   // Add the current vertex.
  //   final poly = _polygons[_activePolygon];
  //   if (!poly.closed) {
  //     poly.points.add(_marker);
  //   }
  //
  //   // Attempt to close if back near the start.
  //   const snapThreshold = 10.0;
  //   final closing = !poly.closed &&
  //       poly.points.length > 10 &&
  //       (tent - poly.points.first).distance < snapThreshold;
  //
  //   if (closing) {
  //     tent = poly.points.first; // snap exactly
  //     poly.closed = true;
  //     Fluttertoast.showToast(
  //       msg: _drawingMain
  //           ? "Click on 'Close Main' button for confirm closing Main boundary!"
  //           : 'No-go area #$_activePolygon closed!',
  //       backgroundColor: Colors.green[700],
  //       textColor: Colors.white,
  //     );
  //     // Don’t auto-start no-go; user must tap “Start No-Go”.
  //   }
  //
  //   setState(() {
  //     _marker = tent;
  //     _direction = _dirName(dir);
  //
  //     _markerAngle = angle;
  //   });
  //   _sendMessage(_direction);
  // }
  // void _onJoystick(StickDragDetails details) {
  //   final dx = details.x;
  //   // final dx = details.x.clamp(-1.0, 1.0);
  //   final dy = details.y;
  //
  //   // dead‑zone
  //   if (dx.abs() < 0.3 && dy.abs() < 0.3) {
  //     setState(() => _direction = 'IDLE');
  //     return;
  //   }
  //
  //
  //   // === 1) Handle rotation ===
  //   if (dx > 0.5) {
  //     _markerAngle += pi/2;
  //     _direction = 'R';
  //   } else if (dx < -0.5) {
  //     _markerAngle -= pi/2;
  //     _direction = 'L';
  //   }
  //
  //   // // 1) Compute a turn delta instead of a full 90° jump
  //   // if (dx.abs() > 0.3) {
  //   //   // turn rate scaled by how far you push right/left
  //   //   final turn = dx.sign * _maxTurnPerTick * (dx.abs());
  //   //   _markerAngle += turn;
  //   //   _direction = dx > 0 ? 'R' : 'L';
  //   // }
  //
  //   // === 2) Handle “forward” (dy < -0.5) ===
  //   if (dy < -0.5) {
  //     // compute forward vector from current heading
  //     final forward = Offset(
  //       sin(_markerAngle),     // x
  //       -cos(_markerAngle),    // y (because our arrow_up is -Y)
  //     );
  //
  //     var tent = _marker + forward * _step;
  //     final size = MediaQuery.of(context).size;
  //     tent = Offset(
  //       tent.dx.clamp(_iconSize/2, size.width  - _iconSize/2),
  //       tent.dy.clamp(_iconSize/2, size.height*0.6 - _iconSize/2),
  //     );
  //
  //     // if drawing a no‑go area, enforce inside main boundary
  //     if (!_drawingMain &&
  //         !_polygons[0].points.contains(tent) && // crude check; you likely have your own
  //         !_pointInPoly(tent, _polygons[0].points)) {
  //       // ignore
  //     } else {
  //       if (_drawingMain || _noGoMode) {
  //         // **DRAWING MODE**: record a vertex before moving
  //         final poly = _polygons[_activePolygon];
  //         if (!poly.closed) {
  //           poly.points.add(_marker);
  //         }
  //         // detect closing:
  //         if (!poly.closed &&
  //             poly.points.length > 10 &&
  //             (tent - poly.points.first).distance < 10) {
  //           tent = poly.points.first;
  //           poly.closed = true;
  //           Fluttertoast.showToast(
  //             msg: _drawingMain
  //                 ? 'Main boundary closed!'
  //                 : 'No‑go area #$_activePolygon closed!',
  //             backgroundColor: Colors.green[700],
  //             textColor: Colors.white,
  //           );
  //           if (_drawingMain) {
  //             _drawingMain = false;
  //             _noGoMode    = false;
  //           }
  //         }
  //       } else {
  //         // **RUN MODE**: nothing to record—just move
  //       }
  //
  //       _marker = tent;
  //       _direction = 'U';
  //     }
  //   }
  //
  //   // normalize angle
  //   _markerAngle %= 2*pi;
  //
  //   setState(() {});
  //   _sendMessage(_direction);
  // }
  void _onJoystick(StickDragDetails details) {
    final dx = details.x;
    final dy = details.y;

    // dead‑zone for center‑return
    if (dx.abs() < _turnThreshold && dy.abs() < 0.3) {
      _canTurn = true;               // stick is back “home”
      setState(() => _direction = 'IDLE');
      return;
    }

    // only allow a new turn if the stick is back to center since last turn
    if (_canTurn) {
      if (dx > _turnThreshold) {
        // turn RIGHT
        _markerAngle += pi/2;
        _direction = 'R';
        _canTurn = false;
      } else if (dx < -_turnThreshold) {
        // turn LEFT
        _markerAngle -= pi/2;
        _direction = 'L';
        _canTurn = false;
      }
    }

    // if stick is pushed up beyond its own threshold, do a forward step
    if (dy < -0.5) {
      _moveForward();   // factor out your forward‐movement logic for clarity
    }

    // normalize
    _markerAngle %= 2*pi;
    setState(() {});
    _sendMessage(_direction);
  }

  void _moveForward() {
    // 1) pick a tiny random offset in [-_jitterAngle, +_jitterAngle]
    final jitter = (_rng.nextDouble() * 2 - 1) * _jitterAngleRadians;
    final noisyAngle = _markerAngle + jitter;

    // 2) compute forward vector from this slightly‑wrong heading
    final forward = Offset(
      sin(noisyAngle),
      -cos(noisyAngle),
    );


    // 3) tentative new point
    var tent = _marker + forward * _step;
    final size = MediaQuery.of(context).size;
    tent = Offset(
      tent.dx.clamp(_iconSize/2, size.width - _iconSize/2),
      tent.dy.clamp(_iconSize/2, size.height*0.6 - _iconSize/2),
    );

    // 4) existing boundary‑drawing logic
    final poly = _polygons[_activePolygon];
    if (!poly.closed) poly.points.add(_marker);

    // auto‑close, etc.
    _marker = tent;
  }


  /// quantize analog input to 8 compass directions
  Offset _get8dir(Offset inP) {
    // final a = atan2(inP.dy, inP.dx) * 180 / pi;
    // final deg = (a + 360) % 360;
    // if (deg < 22.5 || deg >= 337.5) return Offset(1, 0);
    // if (deg < 67.5) return Offset(1, -1);
    // if (deg < 112.5) return Offset(0, -1);
    // if (deg < 157.5) return Offset(-1, -1);
    // if (deg < 202.5) return Offset(-1, 0);
    // if (deg < 247.5) return Offset(-1, 1);
    // if (deg < 292.5) return Offset(0, 1);
    // return Offset(1, 1);

    // if vertical pull is stronger than horizontal and it's upwards, go UP
    if (inP.dy < 0 && inP.dy.abs() > inP.dx.abs()) {
      return const Offset(0, -1);
    }
    // otherwise if horizontal dominates, go LEFT or RIGHT
    if (inP.dx.abs() > inP.dy.abs()) {
      return Offset(inP.dx.sign, 0);
    }
    // all other cases (including any DOWN) => idle
    return Offset.zero;
  }


  String _dirName(Offset d) {
    var m = {
      Offset(0, -1): 'U', // UP
      // Offset(0, 1): 'D', // DOWN
      Offset(1, 0): 'R', // RIGHT
      Offset(-1, 0): 'L', // LEFT
      // Offset(1, -1): 'W', // UP RIGHT
      // Offset(-1, -1): 'A', // UP LEFT
      // Offset(1, 1): 'S', // DOWN RIGHT
      // Offset(-1, 1): 'D', // DOWN LEFT
    };
    return m[d] ?? 'IDLE';
  }

  /// Fire when “Close Main” or “Close No-Go” tapped.
  void _closePolygon() {
    final poly = _polygons[_activePolygon];
    if (poly.points.length < 10) {
      Fluttertoast.showToast(msg: 'Draw at least 10 points first');
      return;
    }
    setState(() {
      _marker = poly.points.first;
      poly.closed = true;
      Fluttertoast.showToast(
        msg: _drawingMain
            ? 'Main boundary closed!'
            : 'No-go area #$_activePolygon closed!',
        backgroundColor: Colors.green[700],
        textColor: Colors.white,
      );
      if (_drawingMain) {
        _drawingMain = false;
        _noGoMode = true;
      }
    });
  }

  /// Fire when “Start No-Go” tapped.
  void _startNoGo() {
    if (_drawingMain || !_polygons[0].closed) {
      Fluttertoast.showToast(
        msg: 'You must close the main boundary first',
        toastLength: Toast.LENGTH_SHORT,
      );
      return;
    }
    setState(() {
      _activePolygon = _polygons.length;
      _noGoMode = true;
      _polygons.add(_Polygon(points: [_marker]));
    });
  }

  /// True if p lies inside poly (non-even-odd rule).
  bool _pointInPoly(Offset p, List<Offset> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].dx, yi = poly[i].dy;
      final xj = poly[j].dx, yj = poly[j].dy;
      final intersect = ((yi > p.dy) != (yj > p.dy)) &&
          (p.dx < (xj - xi) * (p.dy - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  /// Undo last main-boundary stroke.
  void _undoMain() {
    if (!_drawingMain || _polygons[0].closed) return;
    if (_mainUndo.isEmpty) {
      Fluttertoast.showToast(msg: 'Nothing to undo on main boundary');
      return;
    }
    final last = _mainUndo.removeLast();
    _mainRedo.add(List.from(_polygons[0].points));
    setState(() {
      _polygons[0].points = last;
      _marker = last.last;
    });
  }

  /// Redo main-boundary stroke.
  void _redoMain() {
    if (!_drawingMain || _polygons[0].closed) return;
    if (_mainRedo.isEmpty) {
      Fluttertoast.showToast(msg: 'Nothing to redo on main boundary');
      return;
    }
    final next = _mainRedo.removeLast();
    _mainUndo.add(List.from(_polygons[0].points));
    setState(() {
      _polygons[0].points = next;
      _marker = next.last;
    });
  }

  /// Reset entire drawing.
  void _reset() {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height * 0.6 / 2);
    setState(() {
      _polygons
        ..clear()
        ..add(_Polygon(points: [center], closed: false));
      _drawingMain = true;
      _noGoMode = false;
      _activePolygon = 0;
      _marker = center;
      _direction = 'IDLE';
      _mainUndo.clear();
      _mainRedo.clear();
    });
  }

  void _sendMessage(String message) {
    if (message != "IDLE") {
      channel.sink.add(message);
    }
  }


  @override
  Widget build(BuildContext context) {
    Color color;

    switch (connectionStatus) {
      case ConnectionStatus.disconnected:
        color = Colors.red;
        break;
      case ConnectionStatus.connecting:
        color = Colors.orange;
        break;
      case ConnectionStatus.connected:
        color = Colors.green;
        break;
    }

    if (!_didInit) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      floatingActionButton: SizedBox(
        width: 90,
        height: 70,
        child: FloatingActionButton(
          onPressed: _reset,
          backgroundColor: Color(0xFF1A2E35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.red, width: 2),
          ),
          child: Text('Reset',
              style: GoogleFonts.orbitron(color: Colors.white, fontSize: 12)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Column(
        children: [
          // 60% mapping area
          Expanded(
            flex: 6,
            child: Container(
              color: Color(0xFF0F1A1C),
              child: Stack(
                children: [
                  CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: _BoundaryPainter(_polygons),
                  ),
                  Positioned(
                    left: _marker.dx - _iconSize/2,
                    top:  _marker.dy - _iconSize/2,
                    child: Transform.rotate(
                      angle: _markerAngle, // rotate the arrow
                      child: Icon(
                        Icons.arrow_upward,
                        size: _iconSize,
                        color: _drawingMain ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(
                              width: 8,
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(_direction,
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text("ESP32 Response: $response",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 40% joystick + controls
          Expanded(
            flex: 4,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF1A2E35), Color(0xFF0F1A1C)]),
              ),
              child: Column(
                children: [
                  // Close / Start No-Go buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _closePolygon,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 15, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                        child: Text(
                          _drawingMain ? 'Close Main' : 'Close No-Go',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(width: 15),
                      ElevatedButton(
                        onPressed: _startNoGo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 15, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                        child: Text(
                          'Start No-Go',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                  // Joystick
                  Expanded(
                    child: Center(
                      child: GlowContainer(
                        color: _drawingMain
                            ? Colors.green[700]!
                            : Colors.red[700]!,
                        glowColor: _drawingMain
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        borderRadius: BorderRadius.circular(_joySize / 2),
                        child: Container(
                          width: _joySize,
                          height: _joySize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: Joystick(
                            mode: JoystickMode.horizontalAndVertical,
                            listener: _onJoystick,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders all polygons (main in green, no-go in red).
class _BoundaryPainter extends CustomPainter {
  final List<_Polygon> polys;
  _BoundaryPainter(this.polys);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < polys.length; i++) {
      final poly = polys[i];
      final color = (i == 0 ? Colors.green : Colors.red).withAlpha(179);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      if (poly.points.length > 1) {
        final path = Path()..moveTo(poly.points[0].dx, poly.points[0].dy);
        for (var p in poly.points.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        if (poly.closed) path.close();
        canvas.drawPath(path, paint);
        if (poly.closed) {
          final fill = Paint()
            ..color = color.withAlpha(52)
            ..style = PaintingStyle.fill;
          canvas.drawPath(path, fill);
        }
      }
      // Label closed no-go areas
      if (i > 0 && poly.closed) {
        final center = _centroid(poly.points);
        final tp = TextPainter(
          text: TextSpan(
            text: '$i',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  Offset _centroid(List<Offset> pts) {
    var x = 0.0, y = 0.0;
    for (var p in pts) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / pts.length, y / pts.length);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
}
