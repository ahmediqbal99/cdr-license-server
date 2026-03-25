List<List<List<dynamic>>> allCdrFiles = [];
List<List<dynamic>> globalCdrData = [];
Map<String,int> globalColumns = {};

Map<String,List<List<dynamic>>> allCdrs = {};

String selectedTarget = "";
List<List<dynamic>> mergeAllCdrs(){

  List<List<dynamic>> merged = [];

  if(allCdrFiles.isEmpty) return merged;

  merged.add(allCdrFiles[0][0]); // header

  for(var file in allCdrFiles){

    for(int i=1;i<file.length;i++){
      merged.add(file[i]);
    }

  }

  return merged;
}