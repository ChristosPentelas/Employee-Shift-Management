import 'package:employee_shift_management_ui/screens/employee_list_screen.dart';
import 'package:employee_shift_management_ui/screens/news_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/leave_requests_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/shifts_screen.dart';
import '../screens/messages_list_screen.dart';
import '../state/auth_session.dart';
import '../utils/navigation.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 10,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: (){
              // Logging out means forgetting the user and the token. Only
              // leaving the screen (the old Navigator.pop) kept both in memory.
              ref.read(authProvider.notifier).logOut();
              Navigator.of(context).returnToLogin();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          children:[
            _buildMenuCard(context, "Υπάλληλοι", Icons.people, Colors.orange, const EmployeeListScreen()),
            _buildMenuCard(context, "Βάρδιες", Icons.calendar_month, Colors.green, const ShiftsScreen()),
            _buildMenuCard(context, "Μηνύματα", Icons.message, Colors.purple, const MessagesListScreen()),
            _buildMenuCard(context, "Αιτήματα Αδείας", Icons.event_note, Colors.red, const LeaveRequestsScreen()),
            _buildMenuCard(context, "Νέα", Icons.newspaper, Colors.blue, const NewsScreen()),
            _buildMenuCard(context, "Προφίλ", Icons.account_circle, Colors.blueGrey, const ProfileScreen()),
          ],
        ),
      ),
    );
  }

  // Each card is given the screen it opens (B53). The title is only the text
  // on the card; before, it was also compared with a string to pick the
  // screen, so changing the text in one place silently broke the card.
  Widget _buildMenuCard(BuildContext context, String title, IconData icon,
      Color color, Widget destination) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destination),
      ),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,size: 50,color: color),
            SizedBox(height: 10),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}