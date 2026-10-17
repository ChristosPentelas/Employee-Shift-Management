import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/api_providers.dart';
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
  late final ApiService _apiService = widget.apiService ?? ref.read(apiServiceProvider);
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
      if (!mounted) return;
      setState(() {
        _leavesFuture = _loadLeaves();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Σφάλμα: $e")));
    }
  }

  void _showAddLeaveDialog() {
    DateTimeRange? selectedRange;
    final _reasonController = TextEditingController();
    // Why the server refused, shown under the reason. The dialog stays open
    // so nothing typed is lost (B19).
    String? saveError;

    showDialog(
      context: context,
      // `_`: this outer context is not used. Named `context`, it would hide the
      // screen's, and every `context` below would quietly mean the dialog (F25).
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text("Αίτηση Αδείας"),
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
                    context: dialogContext,
                    firstDate: DateTime.now(),
                    lastDate: latestPickableDate(DateTime.now()),
                  );
                  // setDialogState belongs to the dialog, so ask about the
                  // dialog, not the screen (F25).
                  if (!dialogContext.mounted) return;
                  if (picked != null) setDialogState(() => selectedRange = picked);
                },
              ),
              SizedBox(height: 10),
              TextField(
                controller: _reasonController,
                // Required: the server's CreateLeaveRequest.reason is
                // @NotBlank, and the supervisor decides by it (B19).
                decoration: InputDecoration(labelText: "Λόγος"),
                // FieldLimits.TEXT on the server.
                maxLength: 255,
                // Typing does not rebuild a StatefulBuilder by itself; without
                // this the submit button would not notice the reason.
                onChanged: (_) => setDialogState(() {}),
              ),
              if (saveError != null)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(saveError!, style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text("Ακύρωση")),
            ElevatedButton(
              // trim(): spaces only is not empty, but @NotBlank refuses it.
              onPressed: (selectedRange == null || _reasonController.text.trim().isEmpty)
                  ? null
                  : () async {
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

                final result = await _apiService.submitLeaveRequest(newRequest);
                // The dialog and the screen are checked separately: the dialog
                // can be closed (tap outside) while the screen stays (F25).
                if (result == SubmitLeaveResult.created) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (!mounted) return;
                  setState(() {
                    _leavesFuture = _loadLeaves();
                  });
                } else if (dialogContext.mounted) {
                  setDialogState(() => saveError = _submitErrorText(result));
                }
            },
              child: Text("Υποβολή"),
            ),
          ],
        ),
      ),
    );
  }

  String _submitErrorText(SubmitLeaveResult result) {
    switch (result) {
      case SubmitLeaveResult.invalid:
        return "Ελέγξτε τις ημερομηνίες και τον λόγο.";
      case SubmitLeaveResult.failed:
      // Never shown - created closes the dialog - but Dart wants every case
      // named, so a value added to the enum later cannot be forgotten here.
      case SubmitLeaveResult.created:
        return "Η αποθήκευση απέτυχε. Δοκιμάστε ξανά.";
    }
  }
}