import 'services/cdr_analysis_engine.dart';

List<List<dynamic>> globalCdrData = [];
Map<String,int> globalColumns = {};
Map<String,int> globalFrequentContacts = {};

CdrAnalysisEngine? globalEngine;

/// target → {data, columns}
Map<String, Map<String,dynamic>> allCdrTargets = {};

String selectedTarget = "";

void loadTarget(String target){

  selectedTarget = target;

  /// load correct dataset
  globalCdrData = List<List<dynamic>>.from(
      allCdrTargets[target]!["data"]
  );

  /// load correct column mapping
  globalColumns = Map<String,int>.from(
      allCdrTargets[target]!["columns"]
  );

  globalEngine = CdrAnalysisEngine(globalCdrData, globalColumns);

  globalFrequentContacts = globalEngine!.getFrequentContacts();

  print("Loaded target: $target");
  print("Rows loaded: ${globalCdrData.length}");
}