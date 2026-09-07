import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/news_model.dart';
import '../utils/session.dart';

class NewsScreen extends StatefulWidget {
  @override
  _NewsScreenState createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<NewsItem>> _newsFuture;

  @override
  void initState() {
    super.initState();
    _newsFuture = _apiService.getNews();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Νέα & Ενημερώσεις"),
          backgroundColor: Colors.orange,
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: "Ολα"),
              Tab(text: "Ανακοινώσεις"),
              Tab(text: "Στόχοι"),
              Tab(text: "Εργασίες"),
            ],
          ),
        ),
        body: FutureBuilder<List<NewsItem>>(
          future: _newsFuture,
          builder: (context, snapshot) {
            if(snapshot.connectionState == ConnectionState.waiting){
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Σφάλμα: ${snapshot.error}"));
            }else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text("Δεν υπάρχουν νέα."));
            }

            List<NewsItem> allNews = snapshot.data!;

            return TabBarView(
              children: [
                _buildNewsList(allNews),
                _buildNewsList(allNews.where((n) => n.type == 'ANNOUNCEMENT').toList()),
                _buildNewsList(allNews.where((n) => n.type == 'GOAL').toList()),
                _buildNewsList(allNews.where((n) => n.type == 'TASK').toList()),
              ],
            );
          },
        ),
        floatingActionButton: Session.isSupervisor()
          ? FloatingActionButton(
              onPressed: () => _showAddNewsDialog(context),
              child: Icon(Icons.add),
              backgroundColor: Colors.blue,
            )
          : null,
      ),
    );
  }

  Widget _buildNewsList(List<NewsItem> items){
    if (items.isEmpty) return Center(child: Text("Καμία εγγραφή σε αυτή την κατηγορία."));

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context,index){
        final item = items[index];
        return Card(
          margin: EdgeInsets.all(10),
          elevation: 4,
          child: ExpansionTile(
            leading: Icon(
              item.type == 'TASK' ? Icons.assignment : (item.type == 'GOAL' ? Icons.flag : Icons.campaign),
              color: item.type == 'TASK' ? Colors.orange : (item.type == 'GOAL' ? Colors.green : Colors.blue),
            ),
            title: Text(item.title, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Από: ${item.author.name}"),
            trailing: Session.isSupervisor()
              ? IconButton(
                  icon: Icon(Icons.delete, color: Colors.red[300]),
                  onPressed: () => _confirmDelete(context, item.id),
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

  void _showAddNewsDialog(BuildContext context) {
    final _titleController = TextEditingController();
    final _descController = TextEditingController();
    final _targetController = TextEditingController();

    String selectedType = 'ANNOUNCEMENT';
    DateTime? selectedDeadline;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context,setDialogState) => AlertDialog(
          title: Text("Νέα Ανάρτηση"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: selectedType,
                  isExpanded: true,
                  items: ['ANNOUNCEMENT','GOAL','TASK'].map((String val){
                    return DropdownMenuItem(value: val, child: Text(val));
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() => selectedType = val!);
                  },
                ),
                TextField(controller: _titleController,decoration: InputDecoration(labelText: "Τίτλος")),
                TextField(controller: _descController,decoration: InputDecoration(labelText: "Περιγραφή"), maxLines: 3),

                if (selectedType == 'GOAL')
                  TextField(
                    controller: _targetController,
                    decoration: InputDecoration(labelText: "Τιμή Στόχου (Target Value)"),
                    keyboardType: TextInputType.number,
                  ),

                if (selectedType == 'TASK')
                  ListTile(
                    title: Text(selectedDeadline == null
                        ? "Επιλογή Deadline"
                        : "Deadline: ${selectedDeadline!.day}/${selectedDeadline!.month}"
                    ),
                    trailing: Icon(Icons.calendar_today),
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),);
                      if (picked != null) setDialogState(() => selectedDeadline = picked);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Ακύρωση")),
            ElevatedButton(
              onPressed: () async {
                NewsItem newItem = NewsItem(
                    id: 0,
                    title: _titleController.text,
                    description: _descController.text,
                    type: selectedType,
                    createdAt: DateTime.now(),
                    author: Session.currentUser!,
                    deadline: selectedDeadline,
                    targetValue: int.tryParse(_targetController.text),
                );

                try{
                  await _apiService.postNews(newItem);
                  Navigator.pop(context);
                  setState(() {
                    _newsFuture = _apiService.getNews();
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Σφάλμα: $e")));
                }
              },
              child: Text("Δημοσίευση"),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, int newsId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Διαγραφή Ανάρτησης"),
        content: Text("Είστε σίγουροι ότι θέλετε να διαγράψετε αυτή την ενημέρωση;"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Ακύρωση")),
          TextButton(
            onPressed: () async {
              try{
                await _apiService.deleteNews(newsId);
                Navigator.pop(context);
                setState(() {
                  _newsFuture = _apiService.getNews();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Η ανάρτηση διαγράφηκε")),
                );
              } catch (e) {
                Navigator.pop(context);
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