import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'services/cdr_analysis_engine.dart';
import 'cdr_data_store.dart';

class MeetingDetectionScreen extends StatelessWidget {

  final List<List<dynamic>> cdrData;
  final Map<String,int> columns;

  const MeetingDetectionScreen({
    super.key,
    required this.cdrData,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {

    if(allCdrTargets.isEmpty){
      return const Center(
        child: Text("Load CDR files first"),
      );
    }

    return FutureBuilder<List<Map<String,dynamic>>>(
      future: compute(runMeetingAnalysis,{
        "targets": allCdrTargets
      }),
      builder:(context,snapshot){

        if(snapshot.connectionState == ConnectionState.waiting){
          return const Center(child:CircularProgressIndicator());
        }

        if(!snapshot.hasData || snapshot.data!.isEmpty){
          return const Center(
            child: Text("No meetings detected"),
          );
        }

        final meetings = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: ListView.builder(

            itemCount: meetings.length,

            itemBuilder:(context,index){

              var m = meetings[index];

              List members = m["members"] ?? [];
              String tower = m["tower"] ?? "Unknown location";
              String date = m["date"] ?? "";
              String time = m["time"] ?? "";

              return Card(
                color: Colors.blueGrey.shade900,
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text(
                        "Meeting Detected (${members.length} phones)",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize:16,
                            color: Colors.white
                        ),
                      ),

                      const SizedBox(height:6),

                      Text(
                        "Location: $tower",
                        style: const TextStyle(
                            color: Colors.white70
                        ),
                      ),

                      const SizedBox(height:4),

                      Text(
                        "Date: $date   Time: $time",
                        style: const TextStyle(
                            color: Colors.lightBlueAccent,
                            fontWeight: FontWeight.w500
                        ),
                      ),

                      const SizedBox(height:12),

                      Wrap(
                        spacing:8,
                        runSpacing:6,
                        children: members.map((n){

                          return Chip(
                            backgroundColor: Colors.blue.shade700,
                            label: Text(
                              n.toString(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold
                              ),
                            ),
                          );

                        }).toList(),
                      )

                    ],
                  ),
                ),
              );

            },
          ),
        );
      },
    );
  }
}