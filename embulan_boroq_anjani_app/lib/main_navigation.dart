import 'package:flutter/material.dart';
import 'kasir_page.dart';   
import 'admin_page.dart';   
import 'history_page.dart'; 

class MainNavigation extends StatefulWidget {
  final String token;
  final String name;

  const MainNavigation({
    super.key, 
    required this.token, 
    required this.name,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0; 

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return KasirPage(token: widget.token);
      case 1:
        return AdminPage(token: widget.token, name: widget.name);
      case 2:
        return HistoryPage(token: widget.token);
      default:
        return KasirPage(token: widget.token);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildPage(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.orange.shade800, 
        unselectedItemColor: Colors.grey,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale), 
            label: 'Kasir',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings), 
            label: 'Admin',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history), 
            label: 'Riwayat',
          ),
        ],
      ),
    );
  }
}