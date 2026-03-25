import 'package:flutter/material.dart';
import 'services/cdr_analysis_engine.dart';

class ImeiIntelligenceScreen extends StatelessWidget {

  final List<List<dynamic>> cdrData;
  final Map<String,int> columns;

  const ImeiIntelligenceScreen({
    super.key,
    required this.cdrData,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {

    if(cdrData.isEmpty){
      return const Center(
        child: Text("Load a CDR first"),
      );
    }

    final engine = CdrAnalysisEngine(cdrData, columns);

    final deviceSwaps = engine.detectDeviceSwaps();
    final sharedDevices = engine.detectSharedDevices();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [

          const Text(
            "Device Swaps (SIM → IMEIs)",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height:10),

          ...deviceSwaps.entries.map((entry){

            return Card(
              child: ListTile(
                title: Text("SIM: ${entry.key}"),
                subtitle: Text(
                    "IMEIs used (${entry.value.length}): ${entry.value.join(", ")}"
                ),
              ),
            );

          }),

          const SizedBox(height:30),

          const Text(
            "Shared Devices (IMEI → SIMs)",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height:10),

          ...sharedDevices.entries
              .where((e)=>e.value.length > 1)
              .map((entry){

            return Card(
              child: ListTile(
                title: Text("IMEI: ${entry.key}"),
                subtitle: Text(
                    "SIMs used (${entry.value.length}): ${entry.value.join(", ")}"
                ),
              ),
            );

          }),

        ],
      ),
    );
  }
}