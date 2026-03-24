import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cdr_import_screen.dart';
import 'call_analysis_screen.dart';
import 'cdr_data_store.dart';
import 'sms_analysis_screen.dart';
import 'frequent_contacts_screen.dart';
import 'network_graph_screen.dart';
import 'suspect_detection_screen.dart';
import 'tower_map_screen.dart';
import 'gang_detection_screen.dart';
import 'imei_intelligence_screen.dart';
import 'meeting_detection_screen.dart';
import 'license_screen.dart';

void main() {
  runApp(const CdrAnalyzerApp());
}

class CdrAnalyzerApp extends StatelessWidget {
  const CdrAnalyzerApp({super.key});

  /// ✅ MOVE FUNCTION HERE
  Future<bool> checkLicense() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("license_key") != null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zooravar',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,

      /// ✅ ROUTES ADDED
      routes: {
        "/home": (context) => const HomePage(),
        "/license": (context) => LicenseScreen(),
      },

      home: FutureBuilder(
        future: checkLicense(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.data == true) {
            return const HomePage();
          } else {
            return LicenseScreen();
          }
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  int selectedTab = 0;

  Widget getScreen() {

    switch (selectedTab) {

      case 0:
        return Column(
          children: [

            /// 🔥 DASHBOARD CARDS
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  buildCard("Targets", allCdrTargets.length.toString()),
                  buildCard("Records", globalCdrData.length.toString()),
                  buildCard("Contacts", globalFrequentContacts.length.toString()),
                ],
              ),
            ),

            Expanded(
              child: CdrImportScreen(
                onImportComplete: () {
                  setState(() {});
                },
              ),
            ),
          ],
        );

      case 1:
        return CallAnalysisScreen(
          cdrData: globalCdrData,
          columns: globalColumns,
        );

      case 2:
        return FrequentContactsScreen(
            cdrData: globalCdrData,
            columns: globalColumns
        );

      case 3:
        return ImeiIntelligenceScreen(
            cdrData: globalCdrData,
            columns: globalColumns
        );

      case 4:
        return TowerMapScreen(
            cdrData: globalCdrData,
            columns: globalColumns
        );

      case 5:
        return NetworkGraphScreen(
            cdrData: globalCdrData,
            columns: globalColumns
        );

      case 6:
        return SuspectDetectionScreen(
            cdrData: globalCdrData,
            columns: globalColumns
        );

      case 7:
        return const GangDetectionScreen();

      case 8:
        return MeetingDetectionScreen(
            cdrData: globalCdrData,
            columns: globalColumns
        );

      default:
        return const CdrImportScreen();
    }
  }

  Widget buildMenuItem(String title, int index, IconData icon) {
    bool selected = selectedTab == index;

    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: Colors.blue.withOpacity(0.2),
      onTap: () {
        setState(() {
          selectedTab = index;
        });
      },
    );
  }

  Widget buildCard(String title, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 5),
            Text(title),
          ],
        ),
      ),
    );
  }
  Widget targetSelector(){

    if(allCdrTargets.isEmpty){
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [

          const Text(
            "Target:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(width:10),

          DropdownButton<String>(
            value: selectedTarget.isEmpty ? null : selectedTarget,
            items: allCdrTargets.keys.map((number){
              return DropdownMenuItem(
                value: number,
                child: Text(number),
              );
            }).toList(),
            onChanged: (value){
              setState(() {
                loadTarget(value!);
              });
            },
          ),

          const SizedBox(width:20),

          ElevatedButton(
            onPressed: (){

              if(selectedTarget.isEmpty) return;

              setState((){

                loadTarget(selectedTarget);

              });

            },
            child: const Text("Analyze"),
          )

        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            Icon(Icons.security, color: Colors.blueAccent),
            SizedBox(width: 10),
            Text("Zooravar Analyzer System"),
          ],
        ),
      ),

        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0F2027),
                Color(0xFF203A43),
                Color(0xFF2C5364),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
        children: [

          Container(
            width: 240,
            color: Colors.black,
            child: ListView(
              children: [

                /// 🔥 APP TITLE

                Divider(color: Colors.white24),

                /// 🔥 MENU
                buildMenuItem("Import CDR", 0, Icons.upload_file),
                buildMenuItem("Call & SMS Analysis", 1, Icons.analytics),
                buildMenuItem("Frequent Contacts", 2, Icons.people),
                buildMenuItem("IMEI / IMSI Tracking", 3, Icons.phone_android),
                buildMenuItem("Tower Mapping", 4, Icons.map),
                buildMenuItem("Network Graph", 5, Icons.hub),
                buildMenuItem("Suspect Detection", 6, Icons.warning),
                buildMenuItem("Gang Detection", 7, Icons.groups),
                buildMenuItem("Meeting Detection", 8, Icons.event),

              ],
            ),
          ),

          Expanded(
            child: Column(
              children: [

                if (selectedTab != 7 && selectedTab != 8) targetSelector(),

                Expanded(
                  child: getScreen(),
                )

              ],
            ),
          )

        ],
      ),
        ),
    );
  }
}