import 'package:employee_shift_management_ui/screens/employee_list_screen.dart';
import 'package:employee_shift_management_ui/screens/news_screen.dart';
import 'package:flutter/material.dart';
import '../screens/leave_requests_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/shifts_screen.dart';
import '../screens/messages_list_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
              Navigator.pop(context);
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
            _buildMenuCard(context,"Υπάλληλοι", Icons.people, Colors.orange),
            _buildMenuCard(context,"Βάρδιες", Icons.calendar_month,Colors.green),
            _buildMenuCard(context,"Μηνύματα", Icons.message, Colors.purple),
            _buildMenuCard(context, "Αιτήματα Αδείας", Icons.event_note, Colors.red),
            _buildMenuCard(context, "Νέα", Icons.newspaper, Colors.blue),
            _buildMenuCard(context, "Προφίλ", Icons.account_circle, Colors.blueGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context,String title,IconData icon,Color color){
    return InkWell(
      onTap:() async {
        if(title == "Υπάλληλοι") {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EmployeeListScreen()),
          );
        }
        if(title == "Νέα") {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NewsScreen()),
          );
        }
        if(title == "Αιτήματα Αδείας") {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => LeaveRequestsScreen()),
          );
        }
        if(title == "Προφίλ") {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfileScreen()),
          );
        }
        if(title == "Βάρδιες") {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ShiftsScreen()),
          );
        }
        if(title == "Μηνύματα") {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MessagesListScreen()),
          );
        }
      },
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