import 'package:flutter/material.dart';
import 'cdr_data_store.dart';

class GangDetectionScreen extends StatelessWidget {
  const GangDetectionScreen({super.key});

  Map<int, Map<String, dynamic>> detectGangs() {

    Map<String, Set<String>> graph = {};
    Map<String, int> connectionCount = {};
    Map<String, Set<String>> numberTargets = {};

    /// MERGE ALL CDR DATASETS
    allCdrTargets.forEach((target, data) {

      List<List<dynamic>> dataset =
      List<List<dynamic>>.from(data["data"]);

      Map<String, int> cols =
      Map<String, int>.from(data["columns"]);

      int aIndex =
          cols["Aparty"] ??
              cols["AParty"] ??
              cols["A number"] ??
              cols["ANumber"] ??
              cols["MSISDN"] ??
              -1;

      int bIndex =
          cols["Bparty"] ??
              cols["BParty"] ??
              cols["B number"] ??
              cols["BNumber"] ??
              -1;

      if (aIndex == -1 || bIndex == -1) return;

      for (int i = 1; i < dataset.length; i++) {

        var row = dataset[i];

        if (row.length <= aIndex || row.length <= bIndex) continue;

        String a = row[aIndex].toString().trim();
        String b = row[bIndex].toString().trim();

        if (a.isEmpty || b.isEmpty) continue;

        /// NORMALIZE NUMBERS
        a = a.replaceAll("+", "").replaceAll(" ", "");
        b = b.replaceAll("+", "").replaceAll(" ", "");

        if (!RegExp(r'^(03\d{9}|923\d{9})$').hasMatch(a)) continue;
        if (!RegExp(r'^(03\d{9}|923\d{9})$').hasMatch(b)) continue;

        if (a.startsWith("03")) a = "92${a.substring(1)}";
        if (b.startsWith("03")) b = "92${b.substring(1)}";

        /// BUILD GRAPH
        graph.putIfAbsent(a, () => {});
        graph.putIfAbsent(b, () => {});

        graph[a]!.add(b);
        graph[b]!.add(a);

        connectionCount[a] = (connectionCount[a] ?? 0) + 1;
        connectionCount[b] = (connectionCount[b] ?? 0) + 1;

        /// TRACK WHICH CDR DATASET NUMBER APPEARS IN
        numberTargets.putIfAbsent(a, () => {});
        numberTargets.putIfAbsent(b, () => {});

        numberTargets[a]!.add(target);
        numberTargets[b]!.add(target);
      }
    });
    /// REMOVE CALL CENTER / SPAM NUMBERS
    graph.removeWhere((number, neighbours) => neighbours.length > 80);

    /// REMOVE VERY WEAK NUMBERS
    graph.removeWhere((number, neighbours) => neighbours.length < 1);

    Map<int, Map<String, dynamic>> gangs = {};
    Set<String> visited = {};

    int gangId = 1;

    for (var number in graph.keys) {

      if (visited.contains(number)) continue;

      List<String> stack = [number];
      Set<String> cluster = {};

      while (stack.isNotEmpty) {

        String current = stack.removeLast();

        if (visited.contains(current)) continue;

        visited.add(current);
        cluster.add(current);

        for (var neighbour in graph[current] ?? {}) {
          if (!visited.contains(neighbour)) {
            stack.add(neighbour);
          }
        }
      }

      /// CLUSTER SIZE FILTER
      if (cluster.length < 3 || cluster.length > 50) continue;

      /// ENSURE CLUSTER IS DENSE (important improvement)
      int strongMembers = 0;

      for (var n in cluster) {

        var neighbours = graph[n] ?? {};

        int internalConnections = neighbours
            .where((m) => cluster.contains(m))
            .length;

        if (internalConnections >= 1) {
          strongMembers++;
        }
      }

      if (strongMembers < 2) continue;

      /// FIND LEADER (highest internal connections)
      String leader = cluster.first;
      int leaderScore = 0;

      for (var n in cluster) {

        var neighbours = graph[n] ?? {};

        int score = neighbours
            .where((m) => cluster.contains(m))
            .length;

        if (score > leaderScore) {
          leaderScore = score;
          leader = n;
        }
      }

      /// FIND CONNECTORS (appear in multiple CDR datasets)
      Set<String> connectors = {};

      for (var n in cluster) {
        if ((numberTargets[n]?.length ?? 0) > 1) {
          connectors.add(n);
        }
      }

      gangs[gangId] = {
        "leader": leader,
        "members": cluster,
        "connectors": connectors
      };

      gangId++;
    }

    return gangs;
  }

  @override
  Widget build(BuildContext context) {

    var gangs = detectGangs();

    if (gangs.isEmpty) {
      return const Center(
        child: Text("No dense gang clusters detected"),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: gangs.entries.map((entry) {

          String leader = entry.value["leader"];
          Set<String> members = entry.value["members"];
          Set<String> connectors = entry.value["connectors"];

          return Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    "Gang ${entry.key} (${members.length} members)",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "Leader: $leader",
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: members.map((n) {

                      Color color = Colors.deepOrange;

                      if (n == leader) {
                        color = Colors.red;
                      } else if (connectors.contains(n)) {
                        color = Colors.purple;
                      }

                      return Chip(
                        label: Text(
                          n,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: color,
                      );

                    }).toList(),
                  )
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}