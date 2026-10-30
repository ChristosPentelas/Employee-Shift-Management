import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/api_providers.dart';
import '../models/leave_request_model.dart';
import '../models/page_model.dart';
import '../utils/date_limits.dart';
import '../state/auth_session.dart';
import '../state/paged_list.dart';
import '../widgets/paged_list_footer.dart';

class LeaveRequestsScreen extends ConsumerStatefulWidget {
  // Tests pass an ApiService with a fake client; the app uses the default.
  final ApiService? apiService;

  const LeaveRequestsScreen({this.apiService});

  @override
  _LeaveRequestsScreenState createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends ConsumerState<LeaveRequestsScreen> {
  late final ApiService _apiService = widget.apiService ?? ref.read(apiServiceProvider);

  // The requests loaded so far, a page at a time (B26). Not a FutureBuilder:
  // loading more adds to the list, and a FutureBuilder handed a new future
  // shows its spinner instead of the rows on screen. `late`: without it, a
  // field's initialiser may not use `this`, and _fetch is a method of this State.
  late final PagedList<LeaveRequest> _leaves =
      PagedList(fetch: _fetch, idOf: (l) => l.id);

  /// A supervisor reviews everyone's requests; an employee loads only their
  /// own from the server, instead of downloading everyone's and hiding the
  /// rest on the phone (F7).
  Future<ListPage<LeaveRequest>> _fetch(int page) {
    final me = ref.read(authProvider);
    if (me == null) { // logged out: screen is closing
      return Future.value(const ListPage(items: [], page: 0, totalPages: 0));
    }

    return ref.read(isSupervisorProvider)
        ? _apiService.getAllLeaveRequests(page: page)
        : _apiService.getMyLeaveRequests(me.user.id, page: page);
  }

  @override
  void initState() {
    super.initState();
    // No setState: nothing is built yet, and the list starts out loading.
    _leaves.reload();
  }

  @override
  void dispose() {
    // Before super: after dispose, a page still on its way is ignored
    // instead of telling a screen that is gone.
    _leaves.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSupervisor = ref.watch(isSupervisorProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Αιτήματα Αδείας"),
        backgroundColor: Colors.orange,
      ),
      // Rebuilt each time the list tells its listeners it changed.
      body: ListenableBuilder(
        listenable: _leaves,
        builder: (context, _) {
          if (_leaves.loading){
            return Center(child: CircularProgressIndicator());
          } else if (_leaves.error != null) {
            return Center(child: Text("Σφάλμα: ${_leaves.error}"));
          } else if (_leaves.items.isEmpty) {
            return Center(child: Text("Δεν υπάρχουν αιτήματα."));
          }

          // No filtering here any more: an employee is sent only their own
          // requests, so other people's reasons never reach the phone (F7).
          List<LeaveRequest> list = _leaves.items;

          return ListView.builder(
            // One row more while the server has older requests: the footer,
            // which loads them once it is scrolled into view (26c3).
            itemCount: list.length + (_leaves.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == list.length) {
                return PagedListFooter(list: _leaves);
              }
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
    final (:result, :removedShifts) = await _apiService.updateLeaveStatus(id, status);
    if (!mounted) return;

    final message = _updateErrorText(result) ?? _removedShiftsText(removedShifts);
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
    // Reload unless nothing changed: after a 409 or 404 the list on screen is
    // out of date, and the reload shows what is really stored (B42).
    if (result != UpdateLeaveStatusResult.failed) {
      _leaves.reload();
    }
  }

  /// What to tell the supervisor, or null when the answer was saved.
  String? _updateErrorText(UpdateLeaveStatusResult result) {
    switch (result) {
      case UpdateLeaveStatusResult.updated:
        return null;
      case UpdateLeaveStatusResult.alreadyAnswered:
        return "Η αίτηση έχει ήδη απαντηθεί.";
      case UpdateLeaveStatusResult.notFound:
        return "Η αίτηση δεν υπάρχει πια.";
      case UpdateLeaveStatusResult.failed:
        return "Η αλλαγή απέτυχε. Δοκιμάστε ξανά.";
    }
  }

  /// After an answer that worked: the shifts the approval removed (B31), or
  /// null when there were none - the list's new status says enough then.
  /// Greek has one form for 1 and another for every other count.
  String? _removedShiftsText(int removedShifts) {
    if (removedShifts == 0) return null;
    if (removedShifts == 1) return "Εγκρίθηκε. Αφαιρέθηκε 1 βάρδια.";
    return "Εγκρίθηκε. Αφαιρέθηκαν $removedShifts βάρδιες.";
  }

  void _showAddLeaveDialog() {
    DateTimeRange? selectedRange;
    final _reasonController = TextEditingController();
    // Why the server refused, shown under the reason. The dialog stays open
    // so nothing typed is lost (B19).
    String? saveError;
    // True while the request is on its way: Submit is off, so a double tap
    // cannot file the same leave twice (B32).
    bool saving = false;

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
              onPressed: (selectedRange == null ||
                      _reasonController.text.trim().isEmpty ||
                      saving)
                  ? null
                  : () async {
                // Read before the await: the session can end while the
                // request is on its way (B16).
                final me = ref.read(authProvider);
                if (me == null) return;
                // After the return above, which would leave Submit off for
                // good; before the await, which would be too late (B32).
                setDialogState(() => saving = true);

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
                  _leaves.reload();
                } else if (dialogContext.mounted) {
                  setDialogState(() {
                    saving = false;
                    saveError = _submitErrorText(result);
                  });
                }
            },
              child: saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text("Υποβολή"),
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