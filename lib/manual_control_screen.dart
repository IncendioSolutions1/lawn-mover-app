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

/// Simple polygon holder.
class _Polygon {
  List<Offset> points;
  bool closed;
  _Polygon({required this.points, this.closed = false});
}

enum ConnectionStatus { disconnected, connecting, connected }

class ManualControlScreen extends StatefulWidget {
  const ManualControlScreen({super.key});
  @override
  ManualControlScreenState createState() => ManualControlScreenState();
}

class ManualControlScreenState extends State<ManualControlScreen> {
  //================================================================
  // 1) DRAWING / BOUNDARY STATE
  //================================================================
  bool _drawingMain = true;      // still drawing the main green polygon?
  bool _noGoMode = false;        // now drawing no‑go areas?
  final List<_Polygon> _polygons = [];
  int _activePolygon = 0;        // index in _polygons

  //================================================================
  // 2) JOYSTICK / MARKER STATE
  //================================================================
  Offset _marker = Offset.zero;
  String _direction = 'IDLE';
  double _markerAngle = 0.0;     // current heading, in radians

  // joystick rendering size (diameter)
  static const double _joySize = 145.0;

  // movement config
  static const double _step = 2.0;
  static const double _iconSize = 16.0;

  // rate‑limit turning so each flick = one 90° turn
  bool _canTurn = true;
  static const double _turnThreshold = 0.6;

  // jitter to simulate imperfect straight lines
  final _rng = Random();
  static const double _jitterRad = 0.3;

  //================================================================
  // 3) UNDO / REDO FOR MAIN BOUNDARY
  //================================================================
  final List<List<Offset>> _mainUndo = [];
  final List<List<Offset>> _mainRedo = [];

  //================================================================
  // 4) WEBSOCKET STATE
  //================================================================
  late WebSocketChannel channel;
  ConnectionStatus connectionStatus = ConnectionStatus.connecting;
  String response = '';
  Timer? _reconnectTimer;

  //================================================================
  // 5) LIFECYCLE
  //================================================================
  bool _didInit = false;
  @override
  void initState() {
    super.initState();
    // hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // seed main boundary center after first layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      final center = Offset(size.width/2, size.height*0.6/2);
      setState(() {
        _polygons.add(_Polygon(points: [center]));
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

  //================================================================
  // 6) WEBSOCKET HELPERS
  //================================================================
  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    setState(() => connectionStatus = ConnectionStatus.disconnected);
    _reconnectTimer = Timer(Duration(seconds: 3), _connectWebSocket);
  }

  void _connectWebSocket() {
    setState(() => connectionStatus = ConnectionStatus.connecting);
    try {
      channel = WebSocketChannel.connect(Uri.parse('ws://192.168.4.1:81'));
      channel.stream.listen((msg) {
        dev.log("Received: $msg");
        setState(() {
          response = msg;
          connectionStatus = ConnectionStatus.connected;
        });
      }, onError: (_) => _scheduleReconnect(), onDone: _scheduleReconnect);
    } catch (e) {
      dev.log("WebSocket failed: $e");
      _scheduleReconnect();
    }
  }

  void _sendMessage(String m) {
    if (m != 'IDLE') channel.sink.add(m);
  }

  //================================================================
  // 7) JOYSTICK & MOVEMENT
  //================================================================
  void _onJoystick(StickDragDetails d) {
    final dx = d.x, dy = d.y;

    // center dead‑zone
    if (dx.abs() < _turnThreshold && dy.abs() < 0.3) {
      _canTurn = true;
      setState(() => _direction = 'IDLE');
      return;
    }

    // handle 90° turns
    if (_canTurn) {
      if (dx > _turnThreshold) {
        _markerAngle += pi/2;
        _direction = 'R';
        _canTurn = false;
      } else if (dx < -_turnThreshold) {
        _markerAngle -= pi/2;
        _direction = 'L';
        _canTurn = false;
      }
    }

    // forward motion (up)
    if (dy < -0.5) {
      _moveForward();
    }

    // keep angle in [0,2π)
    _markerAngle %= 2*pi;

    setState(() {});
    _sendMessage(_direction);
  }

  /// Move one step forward along current heading, plus random jitter.
  void _moveForward() {
    // small random heading offset
    final jitter = (_rng.nextDouble()*2 - 1) * _jitterRad;
    final noisy = _markerAngle + jitter;

    final forward = Offset(sin(noisy), -cos(noisy));
    var tent = _marker + forward * _step;

    final size = MediaQuery.of(context).size;
    tent = Offset(
      tent.dx.clamp(_iconSize/2, size.width - _iconSize/2),
      tent.dy.clamp(_iconSize/2, size.height*0.6 - _iconSize/2),
    );

    // **NEW: if main boundary is closed, don't allow moving outside of it**
    if (!_drawingMain && !_pointInPoly(tent, _polygons[0].points)) {
      return; // ignore this step
    }

    // record vertex if still drawing
    final poly = _polygons[_activePolygon];
    if (!poly.closed) poly.points.add(_marker);

    // snap‑close if near start
    const snap = 10.0;
    if (!poly.closed &&
        poly.points.length > 10 &&
        (tent - poly.points.first).distance < snap) {
      tent = poly.points.first;
      poly.closed = true;
      Fluttertoast.showToast(
        msg: _drawingMain ? 'Main boundary closed!' : 'No‑go #$_activePolygon closed!',
        backgroundColor: Colors.green[700],
        textColor: Colors.white,
      );
      if (_drawingMain) _drawingMain = false;
    }

    _marker = tent;
  }

  //================================================================
  // 8) BOUNDARY CONTROLS (Close / Start No‑Go / Reset)
  //================================================================
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
        msg: _drawingMain ? 'Main closed!' : 'No‑go #$_activePolygon closed!',
        backgroundColor: Colors.green[700],
        textColor: Colors.white,
      );
      if (_drawingMain) _drawingMain = false;
    });
  }

  /// Returns true if [point] lies inside the polygon defined by [poly] (even–odd rule).
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

  void _startNoGo() {
    if (_drawingMain || !_polygons[0].closed) {
      Fluttertoast.showToast(msg: 'Close main boundary first');
      return;
    }
    setState(() {
      _activePolygon = _polygons.length;
      _polygons.add(_Polygon(points: [_marker]));
      _noGoMode = true;
    });
  }

  void _reset() {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width/2, size.height*0.6/2);
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

  //================================================================
  // 9) BUILD UI
  //================================================================
  @override
  Widget build(BuildContext context) {
    if (!_didInit) return const SizedBox.shrink();

    final bool specialEnabled = !_drawingMain || (_polygons.length > 1);

    // connection status dot
    final statusColor = {
      ConnectionStatus.disconnected: Colors.red,
      ConnectionStatus.connecting: Colors.orange,
      ConnectionStatus.connected: Colors.green,
    }[connectionStatus]!;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _reset,
        backgroundColor: const Color(0xFF1A2E35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.red, width: 2),
        ),
        child: Text('Reset', style: GoogleFonts.orbitron(color: Colors.white, fontSize: 12)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: SafeArea(
        child: Column(
          children: [
            // ——— drawing area —————————————————————————————
            Expanded(
              flex: 6,
              child: Container(
                color: const Color(0xFF0F1A1C),
                child: Stack(
                  children: [
                    CustomPaint(
                      size: MediaQuery.of(context).size,
                      painter: _BoundaryPainter(_polygons),
                    ),
                    // mower arrow
                    Positioned(
                      left: _marker.dx - _iconSize/2,
                      top:  _marker.dy - _iconSize/2,
                      child: Transform.rotate(
                        angle: _markerAngle,
                        child: Icon(Icons.arrow_upward, size: _iconSize, color: _drawingMain ? Colors.green : Colors.red),
                      ),
                    ),
                    // status & response
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16, // ← now this Column (and its children) can use full width
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                  children: [
                                Container(width:16, height:16, decoration: BoxDecoration(color:statusColor, shape:BoxShape.circle)),
                                SizedBox(width:8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal:12, vertical:8),
                                  decoration: BoxDecoration(color:Colors.black54, borderRadius: BorderRadius.circular(8)),
                                  child: Text(_direction, style: TextStyle(color:Colors.white)),
                                ),
                              ]),
                              ElevatedButton(
                                onPressed: () {
                                  if(specialEnabled){
                                    Fluttertoast.showToast(msg: 'Start Mowing button pressed!');
                                  }else{
                                    Fluttertoast.showToast(msg: 'Please make and complete main boundary first!');
                                  }

                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A2E35),
                                  padding: EdgeInsets.symmetric(horizontal:16, vertical:12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: specialEnabled ? Colors.green : Colors.red, width: 2),
                                  ),
                                ),
                                child: Text('Start Mowing'),
                              ),
                            ],
                          ),
                          SizedBox(height:10),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal:12, vertical:8),
                            decoration: BoxDecoration(color:Colors.black54, borderRadius: BorderRadius.circular(8)),
                            child: Text("ESP32: $response", style: TextStyle(color:Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ——— joystick & buttons ——————————————————————————
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF1A2E35), Color(0xFF0F1A1C)]),
                ),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      ElevatedButton(
                        onPressed: _closePolygon,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: Text(_drawingMain ? 'Close Main' : 'Close No-Go'),
                      ),
                      SizedBox(width:15),
                      ElevatedButton(
                        onPressed: _startNoGo,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: Text('Start No‑Go'),
                      ),
                    ]),
                    Expanded(
                      child: Center(
                        child: GlowContainer(
                          color: _drawingMain ? Colors.green[700]! : Colors.red[700]!,
                          glowColor: _drawingMain ? Colors.greenAccent : Colors.redAccent,
                          borderRadius: BorderRadius.circular(_joySize/2),
                          child: Container(
                            width: _joySize, height: _joySize,
                            decoration: BoxDecoration(shape:BoxShape.circle, border: Border.all(color:Colors.white24)),
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
      ),
    );
  }
}

/// Paints all polygons.
class _BoundaryPainter extends CustomPainter {
  final List<_Polygon> polys;
  _BoundaryPainter(this.polys);

  @override
  void paint(Canvas c, Size s) {
    for (var i = 0; i < polys.length; i++) {
      final poly = polys[i];
      final color = (i==0 ? Colors.green : Colors.red).withAlpha(179);
      final paint = Paint()..color = color..strokeWidth = 3..style = PaintingStyle.stroke;
      if (poly.points.length > 1) {
        final path = Path()..moveTo(poly.points[0].dx, poly.points[0].dy);
        for (var p in poly.points.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        if (poly.closed) path.close();
        c.drawPath(path, paint);
        if (poly.closed) {
          c.drawPath(path, Paint()..color = color.withAlpha(52)..style = PaintingStyle.fill);
        }
      }
      if (i>0 && poly.closed) {
        // draw area label
        final avg = poly.points.fold(Offset.zero, (a,p)=>a+p) / poly.points.length.toDouble();
        final tp = TextPainter(
          text: TextSpan(text: '$i', style: TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, avg - Offset(tp.width/2, tp.height/2));
      }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter _) => true;
}
