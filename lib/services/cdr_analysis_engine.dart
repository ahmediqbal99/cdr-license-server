import 'package:cdr_analyzer/cdr_data_store.dart';

String normalize(String num) {

  num = num.replaceAll(".0","").trim();
  num = num.replaceAll("+","").replaceAll(" ","");

  if(num.length < 10) return "";

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


class CdrAnalysisEngine {

  List<List<dynamic>> data;
  Map<String,int> columns;

  CdrAnalysisEngine(this.data, this.columns){
    if(data.length < 2){
      throw Exception("CDR file is empty");
    }
  }

  int? _col(String name) => columns[name];


  int getDuration(int row){

    if(row >= data.length) return 0;

    var r = data[row];

    int? durationIndex = _col("Duration");
    int? minsIndex = _col("MINS");
    int? secsIndex = _col("SECS");

    /// use duration column if exists
    if(durationIndex != null && durationIndex < r.length){
      return int.tryParse(r[durationIndex].toString()) ?? 0;
    }

    int mins = 0;
    int secs = 0;

    if(minsIndex != null && minsIndex < r.length){
      mins = int.tryParse(r[minsIndex].toString()) ?? 0;
    }

    if(secsIndex != null && secsIndex < r.length){
      secs = int.tryParse(r[secsIndex].toString()) ?? 0;
    }

    return mins * 60 + secs;
  }

  Map<String,int> getFrequentContacts(){

    Map<String,int> contacts = {};

    int? aIndex = _col("Aparty");
    int? bIndex = _col("Bparty");

    if(aIndex == null || bIndex == null) return contacts;

    for(int i=1;i<data.length;i++){

      var row = data[i];

      if(aIndex >= row.length) continue;
      if(bIndex >= row.length) continue;

      String a = row[aIndex].toString();
      String b = row[bIndex].toString();

      String number = b.isNotEmpty ? b : a;

      number = number.replaceAll(".0","").trim();

      /// remove garbage
      if(!RegExp(r'^\d{7,15}$').hasMatch(number)){
        continue;
      }

      /// normalize numbers
      if(number.startsWith("03")){
        number = "92${number.substring(1)}";
      }

      if(number.startsWith("3") && number.length == 10){
        number = "92$number";
      }

      /// keep only Pakistan mobile numbers
      if(!number.startsWith("92")) continue;

      if(number.length != 12) continue;

      contacts[number] = (contacts[number] ?? 0) + 1;
    }

    var sorted = Map.fromEntries(
        contacts.entries.toList()
          ..sort((a,b)=>b.value.compareTo(a.value))
    );

    return sorted;
  }


  int? findColumn(List<String> names) {

    String clean(String s) {
      return s.toLowerCase().replaceAll("_", "").replaceAll(" ", "");
    }

    for (var entry in columns.entries) {

      String col = clean(entry.key);

      for (var name in names) {

        if (col == clean(name)) {
          return entry.value;
        }
      }
    }

    return null;
  }
  Map<String,dynamic> callStatistics(){

    int incomingCalls = 0;
    int outgoingCalls = 0;

    int incomingSms = 0;
    int outgoingSms = 0;

    int totalDuration = 0;
    int longestCall = 0;

    int? callTypeIndex = findColumn([
      "calltype",
      "call_type"
    ]);

    int? typeIndex = findColumn([
      "type"
    ]);

    int? directionIndex = findColumn([
      "direction"
    ]);

    int? durationIndex = findColumn([
      "duration",
      "secs"
    ]);

    int? minsIndex = findColumn([
      "mins"
    ]);
    print("Columns map: $columns");
    print("CallTypeIndex: $callTypeIndex");
    print("Header row: ${data[0]}");
    for(int i = 1; i < data.length; i++){

      var row = data[i];

      String type = "";
      String direction = "";

      if(callTypeIndex != null && callTypeIndex < row.length){
        type = row[callTypeIndex]
            .toString()
            .toLowerCase()
            .replaceAll("-", " ")
            .replaceAll("_", " ")
            .replaceAll(RegExp(r'\s+'), " ")
            .trim();
      }

      if(typeIndex != null && typeIndex < row.length){
        type += " " + row[typeIndex].toString().toLowerCase();
      }

      if(directionIndex != null && directionIndex < row.length){
        direction = row[directionIndex].toString().toLowerCase();
        type += " " + direction;
      }

      bool incoming = type.contains("incoming") || direction.contains("incoming");
      bool outgoing = type.contains("outgoing") || direction.contains("outgoing");

      bool sms = type.contains("sms");

      bool call =
          type.contains("call") ||
              type.contains("voice");

      if(sms){

        if(incoming) incomingSms++;
        if(outgoing) outgoingSms++;

        continue;
      }

      if(call || incoming || outgoing){

        if(incoming) incomingCalls++;
        if(outgoing) outgoingCalls++;

        int duration = 0;

        if(durationIndex != null && durationIndex < row.length){
          duration += int.tryParse(row[durationIndex].toString()) ?? 0;
        }

        if(minsIndex != null && minsIndex < row.length){
          int mins = int.tryParse(row[minsIndex].toString()) ?? 0;
          duration += mins * 60;
        }

        totalDuration += duration;

        if(duration > longestCall){
          longestCall = duration;
        }
      }
    }

    int totalCalls = incomingCalls + outgoingCalls;

    double avgDuration =
    totalCalls == 0 ? 0 : totalDuration / totalCalls;

    return {

      "incomingCalls": incomingCalls,
      "outgoingCalls": outgoingCalls,

      "incomingSms": incomingSms,
      "outgoingSms": outgoingSms,
      "totalSms": incomingSms + outgoingSms,

      "totalDuration": totalDuration,
      "longestCall": longestCall,
      "avgDuration": avgDuration,
    };
  }

  Map<String, Set<String>> getImeiIntelligence(){

    int? imeiIndex = _col("IMEI");
    int? aIndex = _col("Aparty");

    Map<String, Set<String>> imeiMap = {};

    if(imeiIndex == null || aIndex == null) return imeiMap;

    for(int i=1;i<data.length;i++){

      if(imeiIndex >= data[i].length || aIndex >= data[i].length) continue;

      String imei = data[i][imeiIndex].toString();
      String sim = data[i][aIndex].toString();

      if(imei.isEmpty) continue;

      imeiMap.putIfAbsent(imei, ()=>{});
      imeiMap[imei]!.add(sim);
    }

    return imeiMap;
  }


  List<Map<String,dynamic>> detectMeetings(){

    int? aIndex = _col("Aparty");
    int? bIndex = _col("Bparty");
    int? cellIndex = _col("CellID");
    int? timeIndex = _col("Datetime");

    if(aIndex == null || bIndex == null || cellIndex == null || timeIndex == null){
      return [];
    }

    Map<String,Map<String,String>> towerPresence = {};
    List<Map<String,dynamic>> meetings = [];

    for(int i=1;i<data.length;i++){

      var row = data[i];

      if(cellIndex >= row.length || timeIndex >= row.length) continue;

      String tower = row[cellIndex].toString();
      String time  = row[timeIndex].toString();

      towerPresence.putIfAbsent(tower, ()=>{});

      if(aIndex < row.length){
        String a = normalize(row[aIndex].toString());
        if(a.isNotEmpty) towerPresence[tower]![a] = time;
      }

      if(bIndex < row.length){
        String b = normalize(row[bIndex].toString());
        if(b.isNotEmpty) towerPresence[tower]![b] = time;
      }
    }

    /// -------- Pair meetings --------
    for(var tower in towerPresence.keys){

      var numbers = towerPresence[tower]!;
      var list = numbers.keys.toList();

      for(int i=0;i<list.length;i++){
        for(int j=i+1;j<list.length;j++){

          meetings.add({
            "type":"pair",
            "number1":list[i],
            "number2":list[j],
            "tower":tower,
            "time1":numbers[list[i]],
            "time2":numbers[list[j]]
          });

        }
      }
    }

    /// -------- Gang gatherings --------
    for(var tower in towerPresence.keys){

      var numbers = towerPresence[tower]!;

      if(numbers.length >= 3){

        meetings.add({
          "type":"gang",
          "tower":tower,
          "members":numbers.keys.toList(),
          "count":numbers.length
        });

      }
    }

    return meetings;
  }

  Map<String,int> detectSharedContacts(){

    Map<String,int> shared = {};

    int? bIndex = _col("Bparty");
    if(bIndex == null) return shared;

    for(int i=1;i<data.length;i++){

      if(bIndex >= data[i].length) continue;

      String num = data[i][bIndex].toString();

      num = num.replaceAll(".0","").trim();

      if(num.length < 10) continue;

      shared[num] = (shared[num] ?? 0) + 1;
    }

    return shared;
  }
  Map<String, Set<String>> detectSharedDevices(){

    int? imeiIndex = _col("IMEI");
    int? simIndex = _col("Aparty");

    Map<String, Set<String>> shared = {};

    if(imeiIndex == null || simIndex == null) return shared;

    for(int i=1;i<data.length;i++){

      var row = data[i];

      if(imeiIndex >= row.length) continue;
      if(simIndex >= row.length) continue;

      String imei = row[imeiIndex].toString().replaceAll(".0","").trim();
      String sim  = row[simIndex].toString().replaceAll(".0","").trim();

      if(imei.isEmpty || imei == "null" || imei == "0") continue;
      if(sim.isEmpty || sim == "null") continue;

      shared.putIfAbsent(imei, ()=>{});
      shared[imei]!.add(sim);
    }

    return shared;
  }

  Map<String, Set<String>> detectDeviceSwaps(){

    int? imeiIndex = _col("IMEI");
    int? simIndex  = _col("Aparty");

    Map<String, Set<String>> devices = {};

    if(imeiIndex == null || simIndex == null) return devices;

    for(int i=1;i<data.length;i++){

      var row = data[i];

      if(imeiIndex >= row.length) continue;
      if(simIndex >= row.length) continue;

      String imei = row[imeiIndex].toString().replaceAll(".0","").trim();
      String sim  = row[simIndex].toString().replaceAll(".0","").trim();

      if(imei.isEmpty || imei == "null" || imei == "0") continue;
      if(sim.isEmpty || sim == "null") continue;

      devices.putIfAbsent(sim, ()=>{});
      devices[sim]!.add(imei);
    }

    return devices;
  }
}

List<Map<String,dynamic>> runMeetingAnalysis(Map input){

  Map<String,Map<String,dynamic>> allTargets = input["targets"];
  print("TOTAL TARGET FILES: ${allTargets.length}");

  Map<String,List<Map<String,dynamic>>> towerEvents = {};

  allTargets.forEach((target,data){

    List<List<dynamic>> dataset =
    List<List<dynamic>>.from(data["data"]);

    Map<String,int> cols =
    Map<String,int>.from(data["columns"]);

    /// -------- Column Detection --------

    int aIndex =
        cols["Aparty"] ??
            cols["A Party"] ??
            cols["A Number"] ??
            cols["A number"] ??
            cols["A"] ??
            -1;

    int bIndex =
        cols["BParty"] ??
            cols["Bparty"] ??
            cols["B Party"] ??
            cols["B Number"] ??
            cols["B number"] ??
            cols["B"] ??
            -1;

    int cellIndex =
        cols["CellID"] ??
            cols["cellid"] ??
            cols["Cell Id"] ??
            cols["TowerID"] ??
            -1;

    int locationIndex =
        cols["SiteLocation"] ??
            cols["Location"] ??
            cols["Address"] ??
            cols["TowerLocation"] ??
            cols["Site Location"] ??
            -1;

    int timeIndex =
        cols["Datetime"] ??
            cols["DateTime"] ??
            cols["Start Time"] ??
            cols["Call Time"] ??
            cols["Time"] ??
            -1;

    if(aIndex == -1 || timeIndex == -1) return;

    for(int i=1;i<dataset.length;i++){

      var row = dataset[i];

      if(row.length <= timeIndex) continue;

      /// -------- Tower --------

      /// -------- LOCATION DETECTION --------

      /// -------- LOCATION + COORDINATE DETECTION --------

      int latIndex = cols["LAT"] ?? -1;
      int lngIndex = cols["LNG"] ?? -1;

      int latitudeIndex = cols["Latitude"] ?? -1;
      int longitudeIndex = cols["Longitude"] ?? -1;

      int locIndex =
          cols["SiteLocation"] ??
              cols["Location"] ??
              cols["Address"] ??
              -1;

      String lat = "";
      String lng = "";
      String location = "";

      /// Pattern 1 — LAT / LNG
      if(latIndex != -1 && lngIndex != -1){
        if(latIndex < row.length) lat = row[latIndex].toString().trim();
        if(lngIndex < row.length) lng = row[lngIndex].toString().trim();
      }

      /// Pattern 2 — Latitude / Longitude
      if((lat.isEmpty || lng.isEmpty) &&
          latitudeIndex != -1 &&
          longitudeIndex != -1){

        if(latitudeIndex < row.length)
          lat = row[latitudeIndex].toString().trim();

        if(longitudeIndex < row.length)
          lng = row[longitudeIndex].toString().trim();
      }

      /// Pattern 3 — Coordinates inside SiteLocation
      if((lat.isEmpty || lng.isEmpty) && locIndex != -1){

        location = row[locIndex].toString();

        RegExp coord = RegExp(r'(\d{2}\.\d+)\s*\|\s*(\d{2}\.\d+)');

        var match = coord.firstMatch(location);

        if(match != null){

          double a = double.tryParse(match.group(1)!) ?? 0;
          double b = double.tryParse(match.group(2)!) ?? 0;

          /// detect which is lat/lng automatically
          if(a > 30){
            lng = a.toString();
            lat = b.toString();
          }else{
            lat = a.toString();
            lng = b.toString();
          }
        }
      }

      /// skip rows without coordinates
      if(lat.isEmpty || lng.isEmpty) continue;

      /// clean readable location
      if(locIndex != -1){
        location = row[locIndex].toString();
        if(location.contains("|")){
          location = location.split("|")[0].trim();
        }
      }

      double latD = double.tryParse(lat) ?? 0;
      double lngD = double.tryParse(lng) ?? 0;

      String towerKey =
          "${latD.toStringAsFixed(4)},${lngD.toStringAsFixed(4)}";

      /// -------- Time Parsing (Robust) --------

      DateTime? time;

      String rawTime = row[timeIndex].toString().trim();

      try {

        /// -------- EXCEL SERIAL DATE --------
        if(RegExp(r'^\d+\.\d+$').hasMatch(rawTime)){

          double excelDate = double.parse(rawTime);

          DateTime baseDate = DateTime(1899, 12, 30);

          int days = excelDate.floor();
          double fraction = excelDate - days;

          int seconds = (fraction * 86400).round();

          time = baseDate
              .add(Duration(days: days))
              .add(Duration(seconds: seconds));
        }

        /// -------- ISO FORMAT --------
        else if(rawTime.contains("T")){

          time = DateTime.parse(rawTime);
        }

        /// -------- NORMAL STRING DATE --------
        else {

          List parts = rawTime.split(" ");

          List d = parts[0].split("/");

          int a = int.parse(d[0]);
          int b = int.parse(d[1]);
          int year = int.parse(d[2]);

          int day;
          int month;

          if(a > 12){
            day = a;
            month = b;
          }
          else if(b > 12){
            month = a;
            day = b;
          }
          else{
            month = a;
            day = b;
          }

          int hour = 0;
          int minute = 0;
          int second = 0;

          if(parts.length > 1){

            List t = parts[1].split(":");

            hour = int.parse(t[0]);
            minute = int.parse(t[1]);

            if(t.length > 2){
              second = int.parse(t[2]);
            }
          }

          time = DateTime(year, month, day, hour, minute, second);
        }

      }
      catch(e){

        print("Date parse failed: $rawTime");
        time = null;
      }

      if(time == null) continue;

      /// -------- Normalize Numbers --------

      Set<String> numbers = {};

      if(aIndex != -1 && aIndex < row.length){
        String a = normalize(row[aIndex].toString());
        if(a.isNotEmpty) numbers.add(a);
      }

      if(bIndex != -1 && bIndex < row.length){
        String b = normalize(row[bIndex].toString());
        if(b.isNotEmpty) numbers.add(b);
      }

      for(String n in numbers){

        towerEvents.putIfAbsent(towerKey, ()=>[]);

        towerEvents[towerKey]!.add({
          "number": n,
          "time": time,
          "target": target,
          "location": location
        });

      }

    }

  });

  /// -------- Detect Meetings --------
  print("TOTAL TOWERS FOUND: ${towerEvents.length}");
  List<Map<String,dynamic>> meetings = [];

  Set<String> seenClusters = {};

  towerEvents.forEach((tower,events){
    events.sort((a,b)=>a["time"].compareTo(b["time"]));

    for(int i=0;i<events.length;i++){

      DateTime startTime = events[i]["time"];

      Set<String> clusterNumbers = {};
      Set<String> clusterTargets = {};

      for(int j=i;j<events.length;j++){

        Duration diff =
        events[j]["time"].difference(startTime);

        if(diff.inMinutes > 15) break;

        String num = events[j]["number"];
        String tgt = events[j]["target"];

        clusterNumbers.add("${tgt}_$num");
        clusterTargets.add(tgt);

      }

      if(clusterNumbers.length >= 2 && clusterTargets.length >= 2){

        List<String> numbers =
        clusterNumbers
            .map((e)=>e.split("_")[1])
            .toSet()
            .toList()
          ..sort();

        /// Round time to 10 minute window
        DateTime rounded = DateTime(
            startTime.year,
            startTime.month,
            startTime.day,
            startTime.hour,
            startTime.minute ~/ 10 * 10
        );

        String date =
            "${rounded.day.toString().padLeft(2,'0')}/"
            "${rounded.month.toString().padLeft(2,'0')}/"
            "${rounded.year}";

        String time =
        rounded.toString().split(" ")[1].substring(0,5);

        /// Correct unique key
        String key = "$tower-$date-$time";

        int existingIndex =
        meetings.indexWhere((m) => m["key"] == key);

        if(existingIndex != -1){

          /// keep the largest cluster
          if(numbers.length > meetings[existingIndex]["count"]){

            meetings[existingIndex]["members"] = numbers;
            meetings[existingIndex]["count"] = numbers.length;

          }

        } else {

          String location = events[i]["location"] ?? tower;

          meetings.add({
            "key": key,
            "type":"meeting",
            "tower": tower,
            "location": location.isEmpty ? tower : location,
            "members": numbers,
            "count": numbers.length,
            "date": date,
            "time": time
          });

        }
      }

    }

  });

  return meetings;

}