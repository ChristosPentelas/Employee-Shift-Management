import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/api_providers.dart';
import '../models/news_model.dart';
import '../state/auth_session.dart';
import '../state/paged_list.dart';
import '../widgets/add_news_dialog.dart';
import '../widgets/paged_list_footer.dart';

/// One tab: its label, and the NewsType it shows as the server spells it,
/// or null for every post.
typedef _NewsTab = ({String label, String? type});

class NewsScreen extends ConsumerStatefulWidget {
  @override
  _NewsScreenState createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  late final ApiService _apiService = ref.read(apiServiceProvider);

  // In the order shown. The TabBar and the lists are both built from this,
  // so they cannot get out of step.
  static const List<_NewsTab> _tabs = [
    (label: "Ολα", type: null),
    (label: "Ανακοινώσεις", type: 'ANNOUNCEMENT'),
    (label: "Στόχοι", type: 'GOAL'),
    (label: "Εργασίες", type: 'TASK'),
  ];

  // Each tab's posts, a page at a time (B26). The server filters by type, so
  // the Goals tab shows the newest goals - not the goals that happen to be
  // among the newest 20 posts, as it did when every tab filtered one list.
  // `late`: the closures use _apiService, a member of this State.
  late final List<PagedList<NewsItem>> _lists = [
    // Each closure keeps its own `tab`: a Dart for loop gives every pass a
    // fresh variable.
    for (final tab in _tabs)
      PagedList(
        fetch: (page) => _apiService.getNews(type: tab.type, page: page),
        idOf: (n) => n.id,
      ),
  ];

  // All four, after a post or a delete: a post is in "all" and in its own
  // type's tab, and reloading only those would need its type here too.
  void _reloadAll() {
    for (final list in _lists) {
      list.reload();
    }
  }

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  @override
  void dispose() {
    for (final list in _lists) {
      list.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSupervisor = ref.watch(isSupervisorProvider);

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Νέα & Ενημερώσεις"),
          backgroundColor: Colors.orange,
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final tab in _tabs) Tab(text: tab.label)],
          ),
        ),
        // No filtering here any more: each tab's list is already its type.
        body: TabBarView(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              _buildNewsList(_lists[i], _tabs[i], isSupervisor),
          ],
        ),
        floatingActionButton: isSupervisor
          ? FloatingActionButton(
              onPressed: () => _showAddNewsDialog(),
              child: Icon(Icons.add),
              backgroundColor: Colors.blue,
            )
          : null,
      ),
    );
  }

  // Rebuilt each time this tab's list tells its listeners it changed.
  Widget _buildNewsList(PagedList<NewsItem> list, _NewsTab tab, bool isSupervisor) =>
      ListenableBuilder(
        listenable: list,
        builder: (context, _) => _buildNewsPage(list, tab, isSupervisor),
      );

  Widget _buildNewsPage(PagedList<NewsItem> list, _NewsTab tab, bool isSupervisor){
    if (list.loading) {
      return Center(child: CircularProgressIndicator());
    } else if (list.error != null) {
      return Center(child: Text("Σφάλμα: ${list.error}"));
    } else if (list.items.isEmpty) {
      return Center(child: Text(tab.type == null
          ? "Δεν υπάρχουν νέα."
          : "Καμία εγγραφή σε αυτή την κατηγορία."));
    }

    final items = list.items;
    return ListView.builder(
      // A TabBarView destroys the tabs it is not showing. The posts survive
      // in _lists, but the scroll offset only survives saved under this key.
      key: PageStorageKey(tab.label),
      // One row more while the server has older posts: this tab's footer,
      // which loads them once it is scrolled into view (26c3).
      itemCount: items.length + (list.hasMore ? 1 : 0),
      itemBuilder: (context,index){
        if (index == items.length) {
          return PagedListFooter(list: list);
        }
        final item = items[index];
        return Card(
          margin: EdgeInsets.all(10),
          elevation: 4,
          child: ExpansionTile(
            // An ExpansionTile saves whether it is open in the same storage,
            // under the nearest PageStorageKey above it. Without its own key
            // that is the list's, and it would read the scroll offset back as
            // "open" and throw. Its own key also keeps each post open or shut.
            key: PageStorageKey(item.id),
            leading: Icon(
              item.type == 'TASK' ? Icons.assignment : (item.type == 'GOAL' ? Icons.flag : Icons.campaign),
              color: item.type == 'TASK' ? Colors.orange : (item.type == 'GOAL' ? Colors.green : Colors.blue),
            ),
            title: Text(item.title, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Από: ${item.author?.name ?? 'Άγνωστος'}"),
            trailing: isSupervisor
              ? IconButton(
                  icon: Icon(Icons.delete, color: Colors.red[300]),
                  onPressed: () => _confirmDelete(item.id),
                )
              : null,
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.description),
                    Divider(),
                    if (item.type == 'TASK' && item.deadline != null)
                      Text("Προθεσμία: ${item.deadline!.day}/${item.deadline!.month}/${item.deadline!.year}",style: TextStyle(color: Colors.red)),
                    if (item.type == 'GOAL' && item.targetValue !=null)
                      Text("Στόχος: ${item.targetValue}", style: TextStyle(color: Colors.green,fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text("Δημιουργήθηκε: ${item.createdAt.day}/${item.createdAt.month}", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _showAddNewsDialog() {
    // Read when the dialog opens. The session cannot end while it is open
    // without closing it: an expired login closes every screen (B16).
    final me = ref.read(authProvider);
    if (me == null) return;

    showDialog(
      context: context,
      builder: (_) => AddNewsDialog(
        apiService: _apiService,
        author: me.user,
        // Both run even if the dialog was closed while posting; only the
        // screen needs to be there. The post was saved either way, so a
        // missing dialog must not skip the refresh (F25).
        onPosted: () {
          if (!mounted) return;
          _reloadAll();
        },
        onFailed: (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Σφάλμα: $e")));
        },
      ),
    );
  }

  void _confirmDelete(int newsId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Διαγραφή Ανάρτησης"),
        content: Text("Είστε σίγουροι ότι θέλετε να διαγράψετε αυτή την ενημέρωση;"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text("Ακύρωση")),
          TextButton(
            onPressed: () async {
              // Close the question first: after the await only the screen
              // matters, and it must not pop again - `Navigator.pop` removes
              // whatever is on top, which would then be this screen (F25).
              Navigator.pop(dialogContext);
              try{
                await _apiService.deleteNews(newsId);
                if (!mounted) return;
                _reloadAll();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Η ανάρτηση διαγράφηκε")),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Σφάλμα διαγραφής: $e")),
                );
              }
            },
            child: Text("Διαγραφή", style: TextStyle(color: Colors.red)),
          ),
        ],
      )
    );
  }
}