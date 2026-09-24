import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/leave_request_model.dart';
import '../utils/date_limits.dart';
import '../state/auth_session.dart';

class LeaveRequestsScreen extends ConsumerStatefulWidget {
  // Tests pass an ApiService with a fake client; the app uses the default.
  final ApiService? apiService;

  const LeaveRequestsScreen({this.apiService});

  @override
  _LeaveRequestsScreenState createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends ConsumerState<LeaveRequestsScreen> {
  late final ApiService _apiService = widget.apiService ?? ApiService();
  late Future<List<LeaveRequest>> _leavesFuture;

  /// A supervisor reviews everyone's requests; an employee loads only their
  /// own from the server, instead of downloading everyone's and hiding the
  /// rest on the phone (F7).
  Future<List<LeaveRequest>> _loadLeaves() {
    final me = ref.read(authProvider);
    if (me == null) return Future.value(const []); // logged out: screen is closing

    return ref.read(isSupervisorProvider)
        ? _apiService.getAllLeaveRequests()
        : _apiService.getMyLeaveRequests(me.user.id);
  }

  @override
  void initState() {
    super.initState();
    setState(() {
      _leavesFuture = _loadLeaves();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSupervisor = ref.watch(isSupervisorProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Αιτήματα Αδείας"),
        backgroundColor: Colors.orange,
      ),
      body: FutureBuilder<List<LeaveRequest>>(
        future: _leavesFuture,
        builder: (context,snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting){
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Σφάλμα: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("Δεν υπάρχουν αιτήματα."));
          }

          // No filtering here any more: an employee is sent only their own
          // requests, so other people's reasons never reach the phone (F7).
          List<LeaveRequest> list = snapshot.data!;

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final req = list[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(Icons.calendar_month, color: Colors.indigo),
                  title: Text(isSupervisor
                      ? "Υπάλληλος: ${req.employee.name}"
                      : "Αίτημα"
                    ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${req.startDate.day}/${req.startDate.month} έως ${req.endDate.day}/${req.endDate.month}"),
                      if (req.reason != null) Text("Λόγος: ${req.reason}",style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: _buildStatusWidget(req, isSupervisor),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: !isSupervisor
        ? FloatingActionButton(
          onPressed: () => _showAddLeaveDialog(),
          child: Icon(Icons.add),
          backgroundColor: Colors.orange,
        )
        : null,
    );
  }

  Widget _buildStatusWidget(LeaveRequest req, bool isSupervisor) {
    if (isSupervisor && req.status == 'PENDING') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.check_circle, color: Colors.green),
            onPressed: () => _updateStatus(req.id, 'APPROVED'),
          ),
          IconButton(
            icon: Icon(Icons.cancel, color: Colors.red),
            onPressed: () => _updateStatus(req.id, 'REJECTED'),
          ),
        ],
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getStatusColor(req.status).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          req.status,
          style: TextStyle(color: _getStatusColor(req.status), fontWeight: FontWeight.bold),
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED' : return Colors.green;
      case 'REJECTED' : return Colors.red;
      default: return Colors.orange;
    }
  }

  Future<void> _updateStatus(int id,String status) async {
    try{
      await _apiService.updateLeaveStatus(id, status);
      setState(() {
        _leavesFuture = _loadLeaves();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Σφάλμα: $e")));
    }
  }

  void _showAddLeaveDialog() {
    DateTimeRange? selectedRange;
    final _reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Αίτηση Αδειας"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                icon: Icon(Icons.date_range),
                label: Text(selectedRange == null
                  ? "Επιλέξτε Ημερομηνίες"
                  : "${selectedRange!.start.day}/${selectedRange!.start.month} - ${selectedRange!.end.day}/${selectedRange!.end.month}"
                  ),
                onPressed: () async {
                  final DateTimeRange? picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: latestPickableDate(DateTime.now()),
                  );
                  if (picked != null) setDialogState(() => selectedRange = picked);
                },
              ),
              SizedBox(height: 10),
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(labelText: "Λόγος (Προαιρετικά"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Ακύρωση")),
            ElevatedButton(
              onPressed: (selectedRange == null) ? null : () async {
                // Read before the await: the session can end while the
                // request is on its way (B16).
                final me = ref.read(authProvider);
                if (me == null) return;

                LeaveRequest newRequest = LeaveRequest(
                  id: 0,
                  employee: me.user,
                  startDate: selectedRange!.start,
                  endDate: selectedRange!.end,
                  status: 'PENDING',
                  reason: _reasonController.text,
                );

                await _apiService.submitLeaveRequest(newRequest);
                Navigator.pop(context);
                setState(() {
                  _leavesFuture = _loadLeaves();
                });
            },
              child: Text("Υποβολή"),
            ),
          ],
        ),
      ),
    );
  }
}