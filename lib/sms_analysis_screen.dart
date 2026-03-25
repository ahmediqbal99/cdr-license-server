import 'package:flutter/material.dart';

class SmsAnalysisScreen extends StatelessWidget {

  final List<List<dynamic>> cdrData;
  final Map<String,int> columns;

  const SmsAnalysisScreen({
    super.key,
    required this.cdrData,
    required this.columns,
  });

  Map<String,int> calculateSMS(){

    int incoming = 0;
    int outgoing = 0;

    if(!columns.containsKey("CallType")) return {};

    int typeIndex = columns["CallType"]!;

    for(int i=1;i<cdrData.length;i++){

      var row = cdrData[i];

      if(row.length <= typeIndex) continue;

      String type = row[typeIndex].toString().toLowerCase();

      if(type.contains("sms")){

        if(type.contains("in"))
          incoming++;

        if(type.contains("out"))
          outgoing++;
      }
    }

    return {
      "incoming":incoming,
      "outgoing":outgoing
    };
  }

  @override
  Widget build(BuildContext context){

    var stats = calculateSMS();

    if(stats.isEmpty){
      return const Center(child: Text("No SMS data found"));
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "SMS Analysis",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height:30),

          Text("Incoming SMS : ${stats["incoming"]}"),
          Text("Outgoing SMS : ${stats["outgoing"]}"),
        ],
      ),
    );
  }
}