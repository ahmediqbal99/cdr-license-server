import 'package:flutter/material.dart';
import 'services/cdr_analysis_engine.dart';

class CallAnalysisScreen extends StatelessWidget {

  final List<List<dynamic>> cdrData;
  final Map<String,int> columns;

  const CallAnalysisScreen({
    super.key,
    required this.cdrData,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {

    if(cdrData.length < 2){
      return const Center(
        child: Text(
          "Load a CDR first",
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    final engine = CdrAnalysisEngine(cdrData, columns);
    final stats = engine.callStatistics();

    int incomingCalls = stats["incomingCalls"] ?? 0;
    int outgoingCalls = stats["outgoingCalls"] ?? 0;

    int incomingSms = stats["incomingSms"] ?? 0;
    int outgoingSms = stats["outgoingSms"] ?? 0;
    int totalSms = stats["totalSms"] ?? 0;

    int totalDuration = stats["totalDuration"] ?? 0;
    int longestCall = stats["longestCall"] ?? 0;

    double avgDuration = stats["avgDuration"] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Call Analysis",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height:30),

          /// CALLS
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    "Calls",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height:10),

                  Text("Incoming Calls : $incomingCalls"),
                  Text("Outgoing Calls : $outgoingCalls"),

                ],
              ),
            ),
          ),

          const SizedBox(height:15),

          /// SMS
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    "SMS",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height:10),

                  Text("Incoming SMS : $incomingSms"),
                  Text("Outgoing SMS : $outgoingSms"),
                  Text("Total SMS : $totalSms"),

                ],
              ),
            ),
          ),

          const SizedBox(height:15),

          /// DURATION
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    "Call Duration",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height:10),

                  Text("Total Duration : $totalDuration seconds"),
                  Text("Average Duration : ${avgDuration.toStringAsFixed(2)} sec"),
                  Text("Longest Call : $longestCall sec"),

                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
}