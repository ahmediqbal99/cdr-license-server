import 'package:flutter/material.dart';
import 'cdr_data_store.dart';
import 'services/cdr_analysis_engine.dart';

class MultiCdrCorrelationScreen extends StatelessWidget {

  final List<List<dynamic>> cdrData;
  final Map<String,int> columns;

  const MultiCdrCorrelationScreen({
    super.key,
    required this.cdrData,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {

    if(globalCdrData.isEmpty){
      return const Center(
        child: Text("Load CDR first"),
      );
    }

    final engine = CdrAnalysisEngine(globalCdrData, globalColumns);
    final contacts = engine.detectSharedContacts();

    if(contacts.isEmpty){
      return const Center(
        child: Text("No shared contacts detected"),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context,index){

          var entry = contacts.entries.elementAt(index);

          return Card(
            child: ListTile(
              title: Text(entry.key),
              trailing: Text("${entry.value} interactions"),
            ),
          );
        },
      ),
    );
  }
}