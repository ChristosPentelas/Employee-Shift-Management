import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/api_providers.dart';
import '../models/leave_request_model.dart';
import '../models/page_model.dart';
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

  // The requests loaded so far, page 0 first (B26). Kept in fields rather
  // than a FutureBuilder: loading more adds to the list, and a FutureBuilder
  // handed a new future shows its spinner instead of the rows on screen.
  List<LeaveRequest> _leaves = [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true; // the first load, before there is anything to show
  bool _loadingMore = false;
  Object? _error; // only for the first load; a later page has its SnackBar
  // Raised by every reload. A page that was on its way when the list started
  // again belongs to the old list, and is dropped instead of appended.
  int _generation = 0;

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

  /// Loads the list again from page 0, dropping any older pages. The rows on
  /// screen stay until the new ones arrive.
  Future<void> _reload() async {
    final generation = ++_generation;
    try {
      final first = await _fetch(0);
      if (!mounted || generation != _generation) return;
      setState(() {
        _leaves = first.items;
        _page = first.page;
        _hasMore = first.hasMore;
        _loading = false;
        _loadingMore = false; // a page on its way is dropped, see _loadMore
        _error = null;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e;
      });
    }
  }

  /// Adds the next page below the rows on screen.
  Future<void> _loadMore() async {
    // A second tap before the page came back would add it twice.
    if (_loadingMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final next = await _fetch(_page + 1);
      if (!mounted || generation != _generation) return;
      setState(() {
        // By id: a request filed since the last page pushes one already
        // shown onto this one (B69).
        final shown = _leaves.map((l) => l.id).toSet();
        _leaves = [..._leaves, ...next.items.where((l) => !shown.contains(l.id))];
        _page = next.page;
        _hasMore = next.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      // The rows already loaded stay, and so does the button.
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Δεν ήταν δυνατή η φόρτωση. Δοκιμάστε ξανά.")));
    }
  }

  @override
  void initState() {
    super.initState();
    // No setState: nothing is built yet, and _loading already shows the spinner.
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isSupervisor = ref.watch(isSupervisorProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Αιτήματα Αδείας"),
        backgroundColor: Colors.orange,
      ),
      body: Builder(
        builder: (context) {
          if (_loading){
            return Center(child: CircularProgressIndicator());
          } else if (_error != null) {
            return Center(child: Text("Σφάλμα: $_error"));
          } else if (_leaves.isEmpty) {
            return Center(child: Text("Δεν υπάρχουν αιτήματα."));
          }

          // No filtering here any more: an employee is sent only their own
          // requests, so other people's reasons never reach the phone (F7).
          List<LeaveRequest> list = _leaves;

          return ListView.builder(
            // One row more while the server has older requests: the button.
            itemCount: list.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == list.length) {
                return Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: TextButton(
                      // Disabled while a page is on its way.
                      onPressed: _loadingMore ? null : _loadMore,
                      child: Text("Φόρτωση παλαιότερων"),
                    ),
                  ),
                );
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
    final result = await _apiService.updateLeaveStatus(id, status);
    if (!mounted) return;

    final message = _updateErrorText(result);
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
    // Reload unless nothing changed: after a 409 or 404 the list on screen is
    // out of date, and the reload shows what is really stored (B42).
    if (result != UpdateLeaveStatusResult.failed) {
      _reload();
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
                  _reload();
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