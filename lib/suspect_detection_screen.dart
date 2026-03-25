import 'package:flutter/material.dart';

class SuspectDetectionScreen extends StatelessWidget {

  final List<List<dynamic>> cdrData;
  final Map<String,int> columns;

  const SuspectDetectionScreen({
    super.key,
    required this.cdrData,
    required this.columns,
  });

  /// -------- Normalize phone numbers --------
  String normalize(String num){

    num = num.replaceAll(".0","").trim();
    num = num.replaceAll("+","").replaceAll(" ","");

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

  Map<String,int> detectSuspects(){

    Map<String,int> score = {};

    /// -------- Detect columns across all CDR formats --------

    int aIndex =
        columns["Aparty"] ??
            columns["A Party"] ??
            columns["A Number"] ??
            columns["ANumber"] ??
            columns["MSISDN"] ??
            -1;

    int bIndex =
        columns["Bparty"] ??
            columns["BParty"] ??
            columns["B Number"] ??
            columns["BNumber"] ??
            -1;

    int durationIndex =
        columns["Duration"] ??
            columns["MINS"] ??
            columns["SECS"] ??
            -1;

    int typeIndex =
        columns["CallType"] ??
            columns["CALL_TYPE"] ??
            columns["Type"] ??
            -1;

    if(aIndex == -1 || bIndex == -1){
      return {};
    }
    String target = normalize(cdrData[1][aIndex].toString());
    for(int i=1;i<cdrData.length;i++){

      var row = cdrData[i];

      if(row.length <= bIndex) continue;

      String a = normalize(row[aIndex].toString());
      String b = normalize(row[bIndex].toString());

      String number = "";

      if(a == target){
        number = b;
      }
      else if(b == target){
        number = a;
      }
      else{
        continue; // 🚨 ignore unrelated rows
      }

      if(number == target) continue;
      if(number.isEmpty) continue;

      /// -------- Base score for contact --------
      score[number] = (score[number] ?? 0) + 2;

      /// -------- Short duration calls (suspicious) --------
      if(durationIndex != -1 && row.length > durationIndex){

        int duration =
            int.tryParse(row[durationIndex].toString()) ?? 0;

        if(duration < 10){
          score[number] = score[number]! + 3;
        }

        if(duration > 300){
          score[number] = score[number]! + 1;
        }
      }

      /// -------- SMS bursts --------
      if(typeIndex != -1 && row.length > typeIndex){

        String type =
        row[typeIndex].toString().toLowerCase();

        if(type.contains("sms")){
          score[number] = score[number]! + 2;
        }

      }

    }

    /// -------- Sort suspects by score --------

    var sorted = Map.fromEntries(
        score.entries.toList()
          ..sort((a,b)=>b.value.compareTo(a.value))
    );

    return sorted;
  }

  @override
  Widget build(BuildContext context){

    var suspects = detectSuspects();

    if(suspects.isEmpty){
      return const Center(
        child: Text("No suspects detected"),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Suspect Detection",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height:20),

          Expanded(
            child: ListView.builder(

              itemCount: suspects.entries.take(25).length,

              itemBuilder:(context,index){

                var entry =
                suspects.entries.take(25).elementAt(index);

                return Card(
                  child: ListTile(

                    leading: CircleAvatar(
                      child: Text("${index+1}"),
                    ),

                    title: Text(
                      entry.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal:10,vertical:5),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Score ${entry.value}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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