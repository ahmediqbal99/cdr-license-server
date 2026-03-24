import 'package:flutter/material.dart';
import 'services/name_lookup_service.dart';
import 'cdr_data_store.dart';

class NumberDirectoryScreen extends StatefulWidget {
  const NumberDirectoryScreen({super.key});

  @override
  State<NumberDirectoryScreen> createState() => _NumberDirectoryScreenState();
}

class _NumberDirectoryScreenState extends State<NumberDirectoryScreen> {

  List<String> uniqueNumbers = [];
  Map<String,String> names = {};
  String search = "";
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadNumbers();
  }

  /// 🔥 Normalize number
  String normalize(String num){

    num = num.replaceAll(".0","").trim();
    num = num.replaceAll(RegExp(r'[^0-9]'), '');

    if(num.startsWith("03")){
      num = "92${num.substring(1)}";
    }

    if(num.startsWith("3") && num.length == 10){
      num = "92$num";
    }

    if(!num.startsWith("92")) return "";
    if(num.length != 12) return "";

    return num;
  }

  /// 🔥 Load numbers for selected target
  Future<void> loadNumbers() async {

    setState(() {
      loading = true;
      uniqueNumbers = [];
      names = {};
    });

    Set<String> numbers = {};

    var targetData = allCdrTargets[selectedTarget];

    if(targetData == null){
      setState(() {
        loading = false;
      });
      return;
    }

    List data = targetData["data"];
    Map<String,int> columns = targetData["columns"];

    int aIndex =
        columns["Aparty"] ??
            columns["A Party"] ??
            columns["A number"] ??
            columns["ANumber"] ??
            columns["MSISDN"] ??
            columns["msisdn"] ??
            -1;

    int bIndex =
        columns["Bparty"] ??
            columns["B Party"] ??
            columns["B number"] ??
            columns["BNumber"] ??
            -1;

    /// 🔥 If no valid columns → exit safely
    if(aIndex == -1 && bIndex == -1){
      setState(() {
        loading = false;
      });
      return;
    }

    /// 🔥 Extract numbers
    for(int i=1;i<data.length;i++){

      var row = data[i];

      if(row == null || row.isEmpty) continue;

      /// A number
      if(aIndex != -1 && aIndex < row.length){
        String n = normalize(row[aIndex].toString());
        if(n.isNotEmpty) numbers.add(n);
      }

      /// B number
      if(bIndex != -1 && bIndex < row.length){
        String n = normalize(row[bIndex].toString());
        if(n.isNotEmpty) numbers.add(n);
      }
    }

    uniqueNumbers = numbers.toList();

    print("TARGET: $selectedTarget");
    print("TOTAL UNIQUE NUMBERS: ${uniqueNumbers.length}");

    /// 🔥 Fetch names
    try{

      final result = await NameLookupService.lookupBatch(uniqueNumbers);

      if(!mounted) return;

      setState(() {
        names = result;
        loading = false;
      });

    }catch(e){

      print("❌ API Error: $e");

      if(!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    List<String> filtered = uniqueNumbers.where((n){
      return n.contains(search) ||
          (names[n] ?? "").toLowerCase().contains(search.toLowerCase());
    }).toList();

    return Column(
      children: [

        /// 🔍 Search bar
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: const InputDecoration(
              hintText: "Search number or name...",
              border: OutlineInputBorder(),
            ),
            onChanged: (val){
              setState(() {
                search = val;
              });
            },
          ),
        ),

        /// 📋 List
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
              ? const Center(child: Text("No numbers found"))
              : ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index){

              String num = filtered[index];

              String normalizedNum = normalize(num);

              String name = names[normalizedNum] ??
                  names[num] ??
                  "Unknown";
              print("Checking: $num → ${names[num]}");
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(
                    num,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(name),
                ),
              );
            },
          ),
        )

      ],
    );
  }
}