import 'package:flutter/material.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auto_control_screen.dart';
import 'manual_control_screen.dart';

class SidebarPage extends StatefulWidget {
  const SidebarPage({super.key});
  @override
  State<SidebarPage> createState() => _SidebarPageState();
}

class _SidebarPageState extends State<SidebarPage> {
  final _controller = SidebarXController(selectedIndex: 1, extended: true);
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // your two screens
  final List<Widget> _pages = [
    AutoControlScreen(),
    ManualControlScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 600;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final idx = _controller.selectedIndex.clamp(0, _pages.length - 1);
        return Scaffold(
          key: _scaffoldKey,
          appBar: isSmall
              ? AppBar(
            backgroundColor: _appBarColor,
            title: Text(
              _getTitle(idx),
              style: GoogleFonts.robotoMono(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          )
              : null,
          drawer: isSmall ? _buildSidebar() : null,
          body: Row(
            children: [
              if (!isSmall) _buildSidebar(),
              Expanded(child: _pages[idx]),
            ],
          ),
          backgroundColor: _scaffoldBackground,
        );
      },
    );
  }


  Widget _buildSidebar() {
    return SidebarX(
      controller: _controller,

      // ----- MAIN THEME -----
      theme: SidebarXTheme(
        width: 75,
        margin: const EdgeInsets.only(left: 12, top: 12, bottom: 12),
        decoration: BoxDecoration(
          // darker blue-grey gradient instead of green
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2B2D42), Color(0xFF1F1F2E)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        hoverColor: Colors.white24,
        textStyle: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 16),
        selectedTextStyle: GoogleFonts.robotoMono(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),

        // make icon a different accent, and slightly larger
        iconTheme: const IconThemeData(color: Color(0xFFFFA500), size: 24),
        selectedIconTheme: const IconThemeData(color: Colors.white, size: 26),

        // add spacing between icon and text
        itemPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemTextPadding: const EdgeInsets.only(left: 16),
        selectedItemTextPadding: const EdgeInsets.only(left: 16),
      ),

      // ----- EXTENDED THEME -----
      extendedTheme: SidebarXTheme(
        width: 240,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3A405A), Color(0xFF2B2E3E)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // smaller logo now
      headerBuilder: (context, extended) => Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/logo-bg.png',
            width: 150,   // ← reduced from 140
            height: 70,
            fit: BoxFit.contain,
          ),
        ),
      ),

      items: [
        SidebarXItem(
          icon: Icons.smart_toy,
          label: 'Auto Control',
        ),
        SidebarXItem(
          icon: Icons.gamepad,
          label: 'Manual Control',
        ),
      ],
    );
  }

  String _getTitle(int idx) {
    switch (idx) {
      case 0:
        return 'Auto Control';
      case 1:
        return 'Manual Control';
      default:
        return '';
    }
  }
}

// colors
const Color _appBarColor = Color(0xFF52734D);
const Color _scaffoldBackground = Color(0xFF2F3E46);