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

/// Simple polygon holder: stores a list of points and whether it's closed.
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

  //============================================================
  // Constants & Saved Boundaries
  //============================================================

  // your main (green) boundary, already closed:
  final List<Offset> mainBoundary = [
    Offset(205.71, 253.71),
    Offset(205.71, 253.71),
    Offset(205.40, 251.74),
    Offset(205.36, 249.74),
    Offset(205.05, 247.76),
    Offset(205.40, 245.79),
    Offset(205.13, 243.81),
    Offset(205.13, 241.81),
    Offset(205.35, 239.82),
    Offset(205.63, 237.84),
    Offset(205.82, 235.85),
    Offset(205.97, 233.86),
    Offset(205.82, 231.86),
    Offset(206.33, 229.93),
    Offset(206.20, 227.93),
    Offset(206.63, 225.98),
    Offset(207.17, 224.06),
    Offset(206.86, 222.08),
    Offset(207.23, 220.11),
    Offset(207.32, 218.11),
    Offset(207.37, 216.11),
    Offset(207.95, 214.20),
    Offset(207.82, 212.21),
    Offset(208.33, 210.27),
    Offset(207.99, 208.30),
    Offset(207.51, 206.36),
    Offset(206.97, 204.44),
    Offset(207.08, 202.44),
    Offset(206.76, 200.46),
    Offset(206.41, 198.50),
    Offset(206.47, 196.50),
    Offset(206.96, 194.56),
    Offset(207.22, 192.57),
    Offset(206.80, 190.62),
    Offset(206.83, 188.62),
    Offset(206.97, 186.62),
    Offset(207.45, 184.68),
    Offset(207.95, 182.75),
    Offset(207.60, 180.78),
    Offset(207.89, 178.80),
    Offset(207.69, 176.81),
    Offset(207.87, 174.82),
    Offset(208.16, 172.84),
    Offset(208.18, 170.84),
    Offset(208.11, 168.84),
    Offset(207.78, 166.87),
    Offset(207.36, 164.92),
    Offset(206.84, 162.98),
    Offset(206.48, 161.02),
    Offset(205.89, 159.11),
    Offset(206.46, 157.19),
    Offset(206.95, 155.25),
    Offset(207.51, 153.33),
    Offset(207.05, 151.38),
    Offset(207.25, 149.39),
    Offset(206.82, 147.44),
    Offset(207.20, 145.48),
    Offset(206.79, 143.52),
    Offset(206.92, 141.52),
    Offset(207.44, 139.59),
    Offset(207.76, 137.62),
    Offset(205.77, 137.68),
    Offset(203.83, 137.17),
    Offset(201.89, 137.66),
    Offset(199.90, 137.86),
    Offset(197.98, 137.31),
    Offset(195.99, 137.55),
    Offset(194.04, 137.12),
    Offset(192.04, 137.24),
    Offset(190.05, 137.39),
    Offset(188.13, 137.97),
    Offset(186.14, 137.80),
    Offset(184.18, 138.20),
    Offset(182.18, 138.28),
    Offset(180.23, 137.84),
    Offset(178.25, 138.11),
    Offset(176.29, 137.74),
    Offset(174.29, 137.86),
    Offset(172.33, 138.26),
    Offset(170.38, 138.71),
    Offset(168.46, 138.15),
    Offset(166.54, 137.61),
    Offset(164.54, 137.48),
    Offset(162.54, 137.61),
    Offset(160.54, 137.63),
    Offset(158.59, 137.19),
    Offset(156.59, 137.25),
    Offset(154.61, 137.01),
    Offset(152.62, 137.22),
    Offset(150.62, 137.33),
    Offset(148.62, 137.26),
    Offset(146.69, 137.77),
    Offset(144.69, 137.82),
    Offset(142.72, 137.49),
    Offset(140.80, 136.92),
    Offset(138.83, 136.56),
    Offset(136.89, 137.03),
    Offset(134.89, 137.19),
    Offset(132.95, 137.66),
    Offset(130.96, 137.89),
    Offset(128.99, 138.21),
    Offset(127.04, 137.77),
    Offset(125.08, 138.16),
    Offset(123.09, 138.36),
    Offset(121.15, 137.86),
    Offset(119.19, 138.24),
    Offset(117.20, 138.51),
    Offset(115.24, 138.88),
    Offset(113.31, 138.36),
    Offset(111.35, 138.77),
    Offset(109.35, 138.83),
    Offset(107.44, 138.27),
    Offset(105.52, 138.83),
    Offset(103.55, 139.17),
    Offset(101.55, 139.30),
    Offset(99.61, 139.77),
    Offset(97.63, 139.48),
    Offset(95.70, 138.96),
    Offset(95.58, 140.95),
    Offset(95.21, 142.92),
    Offset(94.86, 144.89),
    Offset(95.08, 146.88),
    Offset(94.55, 148.80),
    Offset(94.22, 150.78),
    Offset(93.93, 152.76),
    Offset(93.88, 154.76),
    Offset(93.66, 156.74),
    Offset(93.34, 158.72),
    Offset(93.48, 160.71),
    Offset(93.30, 162.70),
    Offset(93.34, 164.70),
    Offset(93.09, 166.69),
    Offset(93.13, 168.69),
    Offset(93.71, 170.60),
    Offset(93.27, 172.55),
    Offset(93.83, 174.47),
    Offset(93.54, 176.45),
    Offset(93.34, 178.44),
    Offset(93.87, 180.37),
    Offset(93.84, 182.37),
    Offset(93.59, 184.35),
    Offset(94.17, 186.27),
    Offset(94.57, 188.23),
    Offset(95.00, 190.18),
    Offset(94.53, 192.12),
    Offset(94.40, 194.12),
    Offset(94.50, 196.12),
    Offset(95.06, 198.04),
    Offset(95.44, 200.00),
    Offset(95.84, 201.96),
    Offset(95.35, 203.90),
    Offset(94.89, 205.85),
    Offset(94.62, 207.83),
    Offset(94.95, 209.80),
    Offset(95.22, 211.78),
    Offset(94.65, 213.70),
    Offset(94.86, 215.69),
    Offset(94.99, 217.68),
    Offset(95.56, 219.60),
    Offset(95.10, 221.55),
    Offset(94.91, 223.54),
    Offset(95.44, 225.47),
    Offset(95.13, 227.44),
    Offset(95.46, 229.41),
    Offset(95.89, 231.37),
    Offset(95.79, 233.37),
    Offset(95.66, 235.36),
    Offset(95.36, 237.34),
    Offset(95.05, 239.31),
    Offset(95.17, 241.31),
    Offset(94.60, 243.23),
    Offset(94.47, 245.22),
    Offset(94.97, 247.16),
    Offset(94.69, 249.14),
    Offset(94.10, 251.05),
    Offset(94.19, 253.05),
    Offset(94.48, 255.03),
    Offset(96.47, 255.18),
    Offset(98.46, 255.35),
    Offset(100.41, 254.87),
    Offset(102.38, 255.15),
    Offset(104.34, 254.72),
    Offset(106.26, 255.26),
    Offset(108.26, 255.33),
    Offset(110.25, 255.53),
    Offset(112.22, 255.19),
    Offset(114.15, 255.73),
    Offset(116.09, 256.18),
    Offset(118.09, 256.22),
    Offset(120.08, 256.49),
    Offset(122.04, 256.11),
    Offset(124.02, 255.81),
    Offset(125.93, 256.39),
    Offset(127.93, 256.36),
    Offset(129.93, 256.46),
    Offset(131.92, 256.33),
    Offset(133.88, 256.75),
    Offset(135.82, 257.22),
    Offset(137.82, 257.09),
    Offset(139.80, 257.34),
    Offset(141.77, 257.68),
    Offset(143.71, 258.17),
    Offset(145.70, 257.96),
    Offset(147.69, 257.72),
    Offset(149.65, 257.37),
    Offset(151.59, 256.86),
    Offset(153.58, 256.73),
    Offset(155.55, 257.07),
    Offset(157.54, 257.34),
    Offset(159.46, 257.90),
    Offset(161.44, 258.17),
    Offset(163.36, 257.61),
    Offset(165.28, 257.07),
    Offset(167.25, 256.68),
    Offset(169.21, 256.28),
    Offset(171.21, 256.37),
    Offset(173.20, 256.34),
    Offset(175.17, 256.70),
    Offset(177.16, 256.93),
    Offset(179.14, 256.66),
    Offset(181.10, 257.07),
    Offset(183.01, 256.49),
    Offset(185.01, 256.63),
    Offset(187.01, 256.56),
    Offset(188.99, 256.32),
    Offset(190.98, 256.13),
    Offset(192.97, 255.87),
    Offset(194.89, 255.32),
  ];

  // your first red no‑go zone:
  final List<Offset> noGo1 = [
    Offset(166.68, 204.45),
    Offset(166.68, 204.45),
    Offset(166.33, 202.48),
    Offset(166.89, 200.56),
    Offset(167.15, 198.58),
    Offset(166.80, 196.61),
    Offset(166.39, 194.65),
    Offset(166.77, 192.69),
    Offset(167.17, 190.73),
    Offset(167.23, 188.73),
    Offset(167.07, 186.74),
    Offset(166.62, 184.79),
    Offset(166.56, 182.79),
    Offset(166.62, 180.79),
    Offset(166.70, 178.79),
    Offset(166.50, 176.80),
    Offset(166.11, 174.84),
    Offset(166.28, 172.85),
    Offset(165.70, 170.94),
    Offset(165.30, 168.98),
    Offset(163.34, 169.34),
    Offset(161.36, 169.63),
    Offset(159.36, 169.67),
    Offset(157.40, 169.29),
    Offset(155.47, 168.77),
    Offset(153.52, 168.29),
    Offset(151.54, 168.06),
    Offset(149.57, 168.41),
    Offset(147.61, 168.83),
    Offset(145.64, 168.52),
    Offset(143.70, 168.01),
    Offset(143.81, 170.01),
    Offset(144.13, 171.99),
    Offset(144.01, 173.98),
    Offset(143.58, 175.93),
    Offset(143.75, 177.93),
    Offset(144.10, 179.90),
    Offset(144.25, 181.89),
    Offset(144.27, 183.89),
    Offset(144.16, 185.89),
    Offset(143.72, 187.84),
    Offset(143.94, 189.83),
    Offset(143.81, 191.82),
    Offset(143.61, 193.81),
    Offset(143.47, 195.81),
    Offset(143.23, 197.79),
    Offset(143.78, 199.71),
    Offset(143.48, 201.69),
    Offset(145.40, 202.25),
    Offset(147.38, 201.98),
    Offset(149.37, 201.88),
    Offset(151.37, 201.89),
    Offset(153.33, 202.33),
    Offset(155.32, 202.14),
  ];


  //============================================================
  // 1) DRAWING / BOUNDARY STATE
  //============================================================

  bool _drawingMain = true;      // still drawing the main green polygon?
  bool _noGoMode    = false;     // now drawing no‑go areas?
  final List<_Polygon> _polygons = [];
  int _activePolygon = 0;        // index in _polygons of the one being drawn

  //============================================================
  // 2) JOYSTICK / MARKER STATE
  //============================================================

  Offset _marker     = Offset.zero; // current mower/arrow position
  String _direction  = 'IDLE';      // last direction command (L, R, IDLE)
  double _markerAngle = 0.0;        // heading in radians

  static const double _joySize = 145.0;    // on‑screen joystick diameter
  static const double _iconSize = 16.0;    // mower icon size

  /// how many logical “pixels” to move per joystick tick
  static const double _normalStep     = 2.0;   // your existing mower speed
  static const double _planningStep   = 4.0;   // black cursor
  static const double _startingStep   = 3.0;   // white cursor


  bool _canTurn = true;                   // rate‑limit turns
  static const double _turnThreshold = 0.6;

  final _rng = Random();
  static const double _jitterRad = 0.0;   // simulate imperfect straight lines

  //============================================================
  // 3) UNDO / REDO FOR MAIN BOUNDARY
  //============================================================

  final List<List<Offset>> _mainUndo = [];
  final List<List<Offset>> _mainRedo = [];

  //============================================================
  // 4) WEBSOCKET STATE
  //============================================================

  late WebSocketChannel channel;
  ConnectionStatus connectionStatus = ConnectionStatus.connecting;
  String response = '';
  Timer? _reconnectTimer;

  //============================================================
  // 4.1) Plan and Start Mow
  //============================================================

  bool _planningMode  = false;   // “Mow Planning” button pressed
  bool _startingMode  = false;   // “Start Planning” button pressed
  final List<Offset> _planTrail     = [];
  final List<Offset> _startTrail    = [];

  //============================================================
  // 5) LIFECYCLE
  //============================================================

  bool _didInit = false;
  @override
  void initState() {
    super.initState();
    // hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // after first frame, seed center & load saved polygons:
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      final center = Offset(size.width/2, size.height*0.6/2);

      // build your saved main+hole into polygons list:
      final mainPoly = _Polygon(points: mainBoundary, closed: true);
      final hole1   = _Polygon(points: noGo1,       closed: true);

      setState(() {
        // _polygons
        //   ..clear()
        //   ..add(mainPoly)
        //   ..add(hole1);
        // _drawingMain   = false;            // drawing is finished
        // _activePolygon = 0;
        // _marker        = mainBoundary.first;
        // _didInit       = true;

        _polygons.clear();
        // Start with an empty main boundary; user can trace it in “drawingMain” mode:
        _polygons.add(_Polygon(points: [center], closed: false));
        _drawingMain   = true;
        _activePolygon = 0;
        _marker        = center;
        _didInit       = true;
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

  //============================================================
  // 6) WEBSOCKET HELPERS
  //============================================================

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

  //============================================================
  // 7) JOYSTICK & MOVEMENT
  //============================================================

  void _onJoystick(StickDragDetails d) {
    final dx = d.x, dy = d.y;

    // dead‑zone & reset turning
    if (dx.abs() < _turnThreshold && dy.abs() < 0.3) {
      _canTurn = true;
      setState(() => _direction = 'IDLE');
      return;
    }

    // 90° turns only once per flick
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

    if (d.y < -0.5) {
      // compute your next position exactly as before…
      final jitter = (_rng.nextDouble()*2 - 1) * _jitterRad;
      final noisy  = _markerAngle + jitter;
      final forward= Offset(sin(noisy), -cos(noisy));
      final size   = MediaQuery.of(context).size;

      // pick the right step size
      final double step = _planningMode
          ? _planningStep
          : _startingMode
          ? _startingStep
          : _normalStep;

      var next = _marker + forward * step;
      next = Offset(
        next.dx.clamp(_iconSize/2, size.width  - _iconSize/2),
        next.dy.clamp(_iconSize/2, size.height*0.6 - _iconSize/2),
      );

      final poly = _polygons[_activePolygon];
      // auto‑close logic
      if (_drawingMain
          && !poly.closed
          && poly.points.length >= 10               // ← only if you've drawn ≥10 points
          && (next - poly.points.first).distance < 10) {
          next = poly.points.first;
          poly.closed = true;
          _drawingMain = false;
          Fluttertoast.showToast(msg: 'Main auto‑closed!');

      } else if (_noGoMode
          && !poly.closed
          && poly.points.length >= 10               // ← also require ≥10
          && (next - poly.points.first).distance < 10) {
          next = poly.points.first;
          poly.closed = true;
          _noGoMode = false;
          Fluttertoast.showToast(msg: 'No‑go #$_activePolygon auto‑closed!');

      }


      bool inMain = _pointInPoly(next, _polygons[0].points);
      bool inHole = _polygons
          .skip(1)                                    // all of your “red” holes
          .any((h) => h.closed && _pointInPoly(next, h.points));

      // only allow moves inside the green boundary
      // if (_drawingMain || _pointInPoly(next, _polygons[0].points)) {
        if (_drawingMain || (inMain && !inHole)) {
        setState(() {

          // ✏️ If we're drawing the main boundary, record the current marker
          if (_drawingMain) {
            final poly = _polygons[_activePolygon];
            poly.points.add(_marker);
          }else if (_noGoMode) {
            final poly = _polygons[_activePolygon];
            poly.points.add(_marker);
          }

          _marker = next;
          _sendMessage(_direction);

          // record into the active trail
          if (_planningMode) {
            _planTrail.add(next);
          } else if (_startingMode) {
            _startTrail.add(next);
          }
        });
      }
    }

    _markerAngle %= 2*pi;

    // forward motion: two paths depending on _recording
    // if (dy < -0.5) {
    //   // compute your next position
    //   final jitter = (_rng.nextDouble()*2 - 1) * _jitterRad;
    //   final noisy  = _markerAngle + jitter;
    //   final forward= Offset(sin(noisy), -cos(noisy));
    //   final size   = MediaQuery.of(context).size;
    //   var next = _marker + forward*_step;
    //   next = Offset(
    //     next.dx.clamp(_iconSize/2, size.width  - _iconSize/2),
    //     next.dy.clamp(_iconSize/2, size.height*0.6 - _iconSize/2),
    //   );
    //
    //   // **only** allow moves if you’re either still drawing the main boundary
    //   // or if it’s already closed and you’re inside it
    //   if (_drawingMain ||
    //       (!_drawingMain && _pointInPoly(next, _polygons[0].points))) {
    //
    //     setState(() {
    //       // ✏️ record this vertex in the active polygon
    //       final poly = _polygons[_activePolygon];
    //       if (!poly.closed) {
    //         poly.points.add(_marker);
    //       }
    //
    //       // now actually move the marker
    //       _marker = next;
    //       _sendMessage(_direction);
    //     });
    //   }
    // }
    //
    // _markerAngle %= 2*pi;
  }

  /// Even–odd rule point‑in‑polygon test
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

  //============================================================
  // 8) BOUNDARY CONTROLS
  //============================================================

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
      _drawingMain   = true;
      _noGoMode      = false;
      _activePolygon = 0;
      _marker        = center;
      _direction     = 'IDLE';
      _mainUndo.clear();
      _mainRedo.clear();
      _markerAngle = 0.0;
      _planningMode  = false;   // “Mow Planning” button pressed
      _startingMode  = false;   // “Start Planning” button pressed
       _planTrail.clear();
       _startTrail.clear();
    });
  }

  //============================================================
  // 9) Export Boundaries & Plan Trail
  //============================================================

  /// Dumps your drawn/loaded polygons to the log in Dart literal form.
  void _exportBoundaries() {
    final buffer = StringBuffer();
    for (int i = 0; i < _polygons.length; i++) {
      final poly = _polygons[i];
      final name = i == 0 ? 'mainBoundary' : 'noGo$i';
      buffer.writeln('/// $name ${poly.closed ? "(closed)" : ""}');
      buffer.write('final List<Offset> $name = [\n');
      for (final p in poly.points) {
        buffer.writeln('  Offset(${p.dx.toStringAsFixed(2)}, ${p.dy.toStringAsFixed(2)}),');
      }
      buffer.writeln('];\n');
    }
    dev.log(buffer.toString());
  }

  //============================================================
  // 10) BUILD UI
  //============================================================

  @override
  Widget build(BuildContext context) {
    if (!_didInit) return const SizedBox.shrink();

    final bool specialEnabled = !_drawingMain || (_polygons.length > 1);

    final statusColor = {
      ConnectionStatus.disconnected: Colors.red,
      ConnectionStatus.connecting:  Colors.orange,
      ConnectionStatus.connected:   Colors.green,
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
            // ——— drawing & replay area ——————————————————
            Expanded(
              flex: 6,
              child: Container(
                color: const Color(0xFF0F1A1C),
                child: Stack(
                  children: [
                    // Custom painter draws boundary + replay trail
                    CustomPaint(
                      size: MediaQuery.of(context).size,
                      painter: _BoundaryPainter(
                        _polygons,
                        _planTrail,
                        _startTrail
                      ),
                    ),

                    // the mower arrow icon:
                    Positioned(
                      left: _marker.dx - _iconSize/2,
                      top:  _marker.dy - _iconSize/2,
                      child: Transform.rotate(
                        angle: _markerAngle,
                        child: Icon(
                          Icons.circle,
                          size: _iconSize,
                          color: _planningMode ? Colors.black
                              : _startingMode ? Colors.white
                              : (_drawingMain ? Colors.green : Colors.red),
                        ),
                      ),
                    ),

                    // Top‑left status, Plan/Record buttons:
                    Positioned(
                      top: 16, left: 16, right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Status dot + record toggle:
                              InkWell(
                                onTap: _exportBoundaries,
                                child: Row(
                                    children: [
                                  Container(
                                    width:16, height:16,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width:8),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal:12,vertical:8),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                       _direction,
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ]),
                              ),

                              Spacer(),
                              // Replay Plan button:
                              ElevatedButton(
                                onPressed: (){
                                  setState(() {
                                    _planningMode = true;
                                    _startingMode = false;
                                    _planTrail.clear();
                                    _planTrail.add(_marker);
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A2E35),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal:16,vertical:12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                        color: specialEnabled ? Colors.green : Colors.red,
                                        width: 2
                                    ),
                                  ),
                                ),
                                child: Text('Mow Planning'),
                              ),
                              SizedBox(width: 10,),
                              ElevatedButton(
                                onPressed: (){
                                  setState(() {
                                    _startingMode = true;
                                    _planningMode = false;
                                    _marker = mainBoundary.first;      // jump to start
                                    _startTrail.clear();
                                    _startTrail.add(_marker);
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A2E35),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal:16,vertical:12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                        color: specialEnabled ? Colors.green : Colors.red,
                                        width: 2
                                    ),
                                  ),
                                ),
                                child: Text('Start Planning'),
                              ),
                            ],
                          ),

                          SizedBox(height:10),
                          // ESP32 response box (tap also replays)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal:12,vertical:8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text("ESP32: $response",
                                style: TextStyle(color:Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ——— joystick & boundary buttons —————————————
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors:[Color(0xFF1A2E35), Color(0xFF0F1A1C)]
                  ),
                ),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      ElevatedButton(
                        onPressed: _closePolygon,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        child: Text(_drawingMain ? 'Close Main' : 'Close No-Go'),
                      ),
                      SizedBox(width:15),
                      ElevatedButton(
                        onPressed: _startNoGo,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
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
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
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
      ),
    );
  }
}

/// Paints all polygons **and** the replay trail.
class _BoundaryPainter extends CustomPainter {
  final List<_Polygon> polys;
  final List<Offset>   planTrail;
  final List<Offset>   startTrail;

  _BoundaryPainter(this.polys, this.planTrail, this.startTrail);

  @override
  void paint(Canvas c, Size s) {

    // if user is still drawing the main boundary:
    final mainPoly = polys[0];
    if (!mainPoly.closed && mainPoly.points.length > 1) {
      final paint = Paint()
        ..color       = Colors.green
        ..strokeWidth = 3
        ..style       = PaintingStyle.stroke;
      final path = Path()..moveTo(mainPoly.points[0].dx, mainPoly.points[0].dy);
      for (var pt in mainPoly.points.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
      c.drawPath(path, paint);
    }

    // live no‑go holes
    for (int i = 1; i < polys.length; i++) {
      final hole = polys[i];
      if (!hole.closed && hole.points.length > 1) {
        final paint = Paint()
          ..color       = Colors.green
          ..strokeWidth = 3
          ..style       = PaintingStyle.stroke;
        final path = Path()..moveTo(mainPoly.points[0].dx, mainPoly.points[0].dy);
        for (var pt in mainPoly.points.skip(1)) {
          path.lineTo(pt.dx, pt.dy);
        }
        c.drawPath(path, paint);
      }
    }


    // — build the allowed‐area: main boundary minus any holes —
    bool didClip = false;
    if (polys.isNotEmpty && polys[0].points.length > 2 && polys[0].closed) {
      // 1) build main outline
      final mainPath = Path()
        ..moveTo(polys[0].points[0].dx, polys[0].points[0].dy);
      for (var pt in polys[0].points.skip(1)) {
        mainPath.lineTo(pt.dx, pt.dy);
      }
      mainPath.close();

      // 2) subtract each closed hole
      Path allowed = mainPath;
      for (int i = 1; i < polys.length; i++) {
        final hole = polys[i];
        if (!hole.closed || hole.points.length < 3) continue;
        final holePath = Path()..moveTo(hole.points[0].dx, hole.points[0].dy);
        for (var pt in hole.points.skip(1)) {
          holePath.lineTo(pt.dx, pt.dy);
        }
        holePath.close();
        allowed = Path.combine(PathOperation.difference, allowed, holePath);
      }

      // 3) clip to that difference
      c.save();
      c.clipPath(allowed);
      didClip = true;
    }

    // — draw mow‑planning trail in black —
    if (planTrail.length > 1) {
      final p = Paint()
        ..color       = Colors.black
        ..strokeWidth = 30  // you already defined constants
        ..strokeCap   = StrokeCap.round
        ..style       = PaintingStyle.stroke;
      final path = Path()..moveTo(planTrail.first.dx, planTrail.first.dy);
      for (var pt in planTrail.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
      c.drawPath(path, p);
    }

    // — draw start‑planning trail in white —
    if (startTrail.length > 1) {
      final p = Paint()
        ..color       = Colors.white
        ..strokeWidth = 14
        ..strokeCap   = StrokeCap.round
        ..style       = PaintingStyle.stroke;
      final path = Path()..moveTo(startTrail.first.dx, startTrail.first.dy);
      for (var pt in startTrail.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
      c.drawPath(path, p);
    }

    // — restore if we clipped —
    if (didClip) {
      c.restore();
    }


    // 2) Draw each polygon (green main + red holes):
    for (var i = 0; i < polys.length; i++) {
      final poly  = polys[i];
      final color = (i==0 ? Colors.green : Colors.red).withAlpha(179);
      final paint = Paint()
        ..color       = color
        ..strokeWidth = 3
        ..style       = PaintingStyle.stroke;
      if (poly.points.length > 1) {
        final path = Path()..moveTo(poly.points[0].dx, poly.points[0].dy);
        for (var p in poly.points.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        if (poly.closed) path.close();
        c.drawPath(path, paint);
        if (poly.closed) {
          c.drawPath(path, Paint()
            ..color = color.withAlpha(52)
            ..style = PaintingStyle.fill
          );
        }
      }
      // label each hole with its index
      if (i > 0 && poly.closed) {
        final avg = poly.points.fold(Offset.zero, (a,p)=>a+p) / poly.points.length.toDouble();
        final tp = TextPainter(
          text: TextSpan(text: '$i', style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold
          )),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, avg - Offset(tp.width/2, tp.height/2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}
