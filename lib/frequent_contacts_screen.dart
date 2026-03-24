import 'package:flutter/material.dart';

class FrequentContactsScreen extends StatelessWidget {

  final List<List<dynamic>> cdrData;
  final Map<String,int> columns;

  const FrequentContactsScreen({
    super.key,
    required this.cdrData,
    required this.columns,
  });

  /// -------- Normalize numbers --------
  String normalize(String number){

    number = number.replaceAll(".0","").trim();
    number = number.replaceAll("+","").replaceAll(" ","");

    if(number.startsWith("0092")){
      number = number.substring(2);
    }

    if(number.startsWith("03")){
      number = "92${number.substring(1)}";
    }

    if(number.startsWith("3") && number.length == 10){
      number = "92$number";
    }

    if(!number.startsWith("92")) return "";
    if(number.length != 12) return "";

    return number;
  }

  Map<String,int> computeContacts(){

    Map<String,int> contacts = {};

    /// -------- Detect column formats --------

    int? aIndex =
        columns["Aparty"] ??
            columns["A Party"] ??
            columns["A Number"] ??
            columns["ANumber"] ??
            columns["MSISDN"];

    int? bIndex =
        columns["Bparty"] ??
            columns["BParty"] ??
            columns["B Number"] ??
            columns["BNumber"];

    int? typeIndex =
        columns["CallType"] ??
            columns["Direction"];

    if(aIndex == null || bIndex == null){
      return contacts;
    }

    /// -------- Determine target number --------

    String target = normalize(cdrData[1][aIndex].toString());

    for(int i=1;i<cdrData.length;i++){

      var row = cdrData[i];
      String type = "";

      if(typeIndex != null && typeIndex < row.length){
        type = row[typeIndex].toString().toLowerCase();
      }

      /// 🚨 VERY IMPORTANT
      if(type.contains("data")) continue;

      if(aIndex >= row.length || bIndex >= row.length){
        continue;
      }

      String a = normalize(row[aIndex].toString());
      String b = normalize(row[bIndex].toString());

      /// Determine which number is the contact

      String contact = "";

      if(a == target){
        contact = b;
      }
      else if(b == target){
        contact = a;
      }
      else{
        continue; // 🚨 CRITICAL FIX
      }
      if(contact == target) continue;

      if(contact.isEmpty) continue;

      contacts[contact] = (contacts[contact] ?? 0) + 1;
    }

    /// -------- Sort contacts --------

    var sorted = Map.fromEntries(
        contacts.entries.toList()
          ..sort((a,b)=>b.value.compareTo(a.value))
    );

    return sorted;
  }

  @override
  Widget build(BuildContext context) {

    if(cdrData.isEmpty){
      return const Center(
        child: Text("Load a CDR first"),
      );
    }

    final contacts = computeContacts();

    if(contacts.isEmpty){
      return const Center(
        child: Text("No contacts detected"),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Frequent Contacts",
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold
            ),
          ),

          const SizedBox(height:20),

          Expanded(
            child: ListView.builder(

              itemCount: contacts.entries.take(100).length,

              itemBuilder:(context,index){

                var entry =
                contacts.entries.take(100).elementAt(index);

                return Card(
                  child: ListTile(

                    leading: CircleAvatar(
                      child: Text("${index+1}"),
                    ),

                    title: Text(
                      entry.key,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold
                      ),
                    ),

                    trailing: Text(
                      "${entry.value} interactions",
                      style: const TextStyle(
                          fontWeight: FontWeight.w500
                      ),
                    ),

                  ),
                );
              },
            ),
          )

        ],
      ),
    );
  }
}