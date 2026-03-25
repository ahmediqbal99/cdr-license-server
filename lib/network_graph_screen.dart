import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'cdr_data_store.dart';
import 'dart:math';

class NetworkGraphScreen extends StatefulWidget {

  final List<List<dynamic>> cdrData;
  final Map<String,int> columns;

  const NetworkGraphScreen({
    super.key,
    required this.cdrData,
    required this.columns,
  });

  @override
  State<NetworkGraphScreen> createState() => _NetworkGraphScreenState();
}

class _NetworkGraphScreenState extends State<NetworkGraphScreen> {

  final Graph graph = Graph();

  final Map<String,Node> nodes = {};
  final Map<String,int> nodeConnections = {};
  final Map<String,int> contactFrequency = {};
  final Map<String,int> incomingCalls = {};
  final Map<String,int> outgoingCalls = {};

  final TransformationController zoomController = TransformationController();

  @override
  void initState() {
    super.initState();
    rebuildGraph();
  }

  @override
  void didUpdateWidget(NetworkGraphScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if(oldWidget.cdrData != widget.cdrData){
      rebuildGraph();
    }
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

  void rebuildGraph(){

    graph.nodes.clear();
    graph.edges.clear();

    nodes.clear();
    nodeConnections.clear();
    contactFrequency.clear();
    incomingCalls.clear();
    outgoingCalls.clear();

    buildGraph();

    setState(() {});
  }

  void buildGraph(){

    if(allCdrTargets.isEmpty) return;

    /// 🔥 TARGET
    String target = selectedTarget ?? "";

    target = normalize(target);

    if(target.isEmpty){
      print("❌ Invalid target");
      return;
    }

    Node targetNode = Node.Id(target);
    nodes[target] = targetNode;
    graph.addNode(targetNode);

    /// 🔥 LOOP THROUGH ALL CDRS
    for (var targetData in allCdrTargets.values) {

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

      int typeIndex =
          columns["CallType"] ??
              columns["Direction"] ??
              -1;

      if(aIndex == -1 || bIndex == -1) continue;

      for(int i=1;i<data.length;i++){

        var row = data[i];

        if(row == null || row.length <= max(aIndex, bIndex)) continue;

        String a = normalize(row[aIndex].toString());
        String b = normalize(row[bIndex].toString());

        if(a.isEmpty || b.isEmpty) continue;

        String contact = "";

        if(a == target){
          contact = b;
        }
        else if(b == target){
          contact = a;
        }
        else{
          continue;
        }

        if(contact.isEmpty || contact == target) continue;

        /// 🔥 TYPE
        String type = "";
        if(typeIndex != -1 && typeIndex < row.length){
          type = row[typeIndex].toString().toLowerCase();
        }

        /// ❌ Skip data sessions
        if(type.contains("data")) continue;

        /// 🔥 COUNT
        contactFrequency[contact] =
            (contactFrequency[contact] ?? 0) + 1;

        if(type.contains("out") || type == "mo"){
          outgoingCalls[contact] =
              (outgoingCalls[contact] ?? 0) + 1;
        }

        if(type.contains("in") || type == "mt"){
          incomingCalls[contact] =
              (incomingCalls[contact] ?? 0) + 1;
        }
      }
    }

    /// 🔥 SORT TOP CONTACTS
    List<MapEntry<String,int>> sorted =
    contactFrequency.entries.toList()
      ..sort((a,b)=>b.value.compareTo(a.value));

    var topContacts = sorted.take(10);

    if(topContacts.isEmpty){
      print("⚠️ No contacts found");
      return;
    }

    /// 🔥 BUILD GRAPH
    for(var entry in topContacts){

      String contact = entry.key;
      int frequency = entry.value;

      Node contactNode = nodes.putIfAbsent(contact, () {
        final n = Node.Id(contact);
        graph.addNode(n);
        return n;
      });

      graph.addEdge(
        targetNode,
        contactNode,
        paint: Paint()
          ..color = Colors.white
          ..strokeWidth = 1 + log(frequency + 1),
      );

      nodeConnections[target] =
          (nodeConnections[target] ?? 0) + 1;

      nodeConnections[contact] =
          (nodeConnections[contact] ?? 0) + 1;
    }

    print("TARGET: $target");
    print("CONTACTS: ${contactFrequency.length}");
  }

  Widget buildNode(String text){

    String normalizedTarget = normalize(selectedTarget ?? "");

    bool isTarget = text == normalizedTarget;

    int incoming = incomingCalls[text] ?? 0;
    int outgoing = outgoingCalls[text] ?? 0;
    int calls = incoming + outgoing;
    int total = contactFrequency[text] ?? 0;

    Color color;

    if(isTarget){
      color = Colors.red;
    }
    else if(calls > 100){
      color = Colors.deepOrange;
    }
    else if(calls > 50){
      color = Colors.orange;
    }
    else if(calls > 20){
      color = Colors.amber;
    }
    else{
      color = Colors.blueAccent;
    }

    return GestureDetector(

      onTap: (){
        showDialog(
          context: context,
          builder: (_){
            return AlertDialog(
              title: const Text("Contact Intelligence"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Number: $text"),
                  const SizedBox(height:10),
                  Text("Total Calls: $calls"),
                  Text("Incoming: $incoming"),
                  Text("Outgoing: $outgoing"),
                  Text("Connections: ${nodeConnections[text] ?? 0}"),
                ],
              ),
            );
          },
        );
      },

      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            if(!isTarget)
              Text(
                "Calls: $calls | Total: $total",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),

            if(isTarget)
              Text(
                "[${nodeConnections[text] ?? 0} contacts]",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),

          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context){


    if(allCdrTargets.isEmpty){
      return const Center(child: Text("Load CDR files first"));
    }

    if(graph.nodes.isEmpty || graph.edges.isEmpty){
      return const Center(child: Text("No valid network data"));
    }

    return Stack(

      children: [

        InteractiveViewer(

          transformationController: zoomController,

          constrained: false,
          boundaryMargin: const EdgeInsets.all(4000),

          minScale: 0.05,
          maxScale: 5,

          child: GraphView(
            graph: graph,
            algorithm: BuchheimWalkerAlgorithm(
              BuchheimWalkerConfiguration()
                ..siblingSeparation = 80
                ..levelSeparation = 120
                ..subtreeSeparation = 120
                ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM,
              TreeEdgeRenderer(
                BuchheimWalkerConfiguration(),
              ),
            ),
            builder: (Node node) {

              final id = node.key?.value?.toString() ?? "";
              if(id.isEmpty) return const SizedBox();

              return buildNode(id);
            },
          ),
        ),

        Positioned(
          right: 20,
          bottom: 20,
          child: Column(
            children: [

              FloatingActionButton(
                heroTag: "zoomIn",
                mini: true,
                onPressed: (){
                  zoomController.value =
                      zoomController.value.scaled(1.2, 1.2, 1);
                },
                child: const Icon(Icons.add),
              ),

              const SizedBox(height:10),

              FloatingActionButton(
                heroTag: "zoomOut",
                mini: true,
                onPressed: (){
                  zoomController.value =
                      zoomController.value.scaled(0.8, 0.8, 1);
                },
                child: const Icon(Icons.remove),
              ),

              const SizedBox(height:10),

              FloatingActionButton(
                heroTag: "resetZoom",
                mini: true,
                onPressed: (){
                  zoomController.value = Matrix4.identity();
                },
                child: const Icon(Icons.center_focus_strong),
              ),

            ],
          ),
        )

      ],
    );
  }
}