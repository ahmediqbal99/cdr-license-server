import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'cdr_data_store.dart';

class CdrImportScreen extends StatefulWidget {

  final VoidCallback? onImportComplete;

  const CdrImportScreen({super.key, this.onImportComplete});

  @override
  State<CdrImportScreen> createState() => _CdrImportScreenState();
}

class _CdrImportScreenState extends State<CdrImportScreen> {

  String fileName = "No file selected";
  Map<String,int> frequentContacts = {};

  void pickFile() async {

    allCdrTargets.clear();
    selectedTarget = "";
    globalCdrData = [];
    globalColumns = {};

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['xlsx','xls'],
    );

    if (result == null) return;

    int fileCount = 0;

    for (var pickedFile in result.files) {

      if (pickedFile.path == null) continue;

      File file = File(pickedFile.path!);

      try {
        readExcel(file);
        fileCount++;

        print("Current targets:");
        print(allCdrTargets.keys);

      } catch (e) {
        print("Skipping file: ${pickedFile.name}");
      }
    }

    setState(() {
      fileName = "$fileCount CDR file(s) loaded";
      frequentContacts = globalFrequentContacts;
    });
    widget.onImportComplete?.call();
  }

  void readExcel(File file) {

    List<List<dynamic>> localData = [];

    var bytes = file.readAsBytesSync();
    var excel = Excel.decodeBytes(bytes);

    /// READ ALL SHEETS
    var table = excel.tables.keys.first;

    var rows = excel.tables[table]!.rows;

    for (var row in rows) {

        List<dynamic> cleanedRow = row.map((cell) {

          if (cell == null) return "";

          var value = cell.value;

          if (value == null) return "";

          return value.toString().trim();

        }).toList();

        localData.add(cleanedRow);
      }
      print("Preview of first rows:");
      for(int i = 0; i < 10 && i < localData.length; i++){
        print(localData[i]);
      }


    if(localData.isEmpty) return;

    /// ------------------------------------------------
    /// STEP 1: DETECT TARGET FROM FILE NAME
    /// ------------------------------------------------

    String fileName =
        file.path.split(Platform.pathSeparator).last;

    String target =
    fileName.replaceAll(".xlsx","")
        .replaceAll(".xls","")
        .trim();

    if(target.startsWith("03")){
      target = "92${target.substring(1)}";
    }

    /// ------------------------------------------------
    /// STEP 2: IF FILE NAME IS NOT NUMBER
    /// TRY TO DETECT FROM HEADER MSISDN
    /// ------------------------------------------------

    /// ------------------------------------------------
    /// STEP 2: DETECT TARGET FROM DATA (ROBUST)
    /// ------------------------------------------------

    if(!RegExp(r'^92\d{10}$').hasMatch(target)){

      for(int i=0;i<localData.length;i++){

        var row = localData[i];

        for(int j=0;j<row.length;j++){

          String cell = row[j].toString().toLowerCase();

          /// check header labels
          if(cell.contains("msisdn") ||
              cell.contains("a number") ||
              cell.contains("aparty") ||
              cell.contains("a_party")){

            if(j + 1 < row.length){

              String num = row[j+1].toString()
                  .replaceAll(".0","")
                  .trim();

              if(num.startsWith("03")){
                num = "92${num.substring(1)}";
              }

              if(RegExp(r'^92\d{10}$').hasMatch(num)){
                target = num;
                break;
              }

            }
          }
        }

        if(RegExp(r'^92\d{10}$').hasMatch(target)){
          break;
        }
      }
    }

    print("Target detected: $target");

    /// Remove profile rows (Msisdn / Name / CNIC etc)

    localData = localData.where((row) {

      String r = row.join(" ").toLowerCase();

      if(r.contains("name")) return false;
      if(r.contains("cnic")) return false;

      /// skip simple msisdn profile row
      if(r.startsWith("msisdn") && !r.contains("call")) return false;

      return true;

    }).toList();

    /// STEP 3: DETECT HEADER ROW

    /// STEP 3: FIND REAL TELECOM HEADER

    int headerRow = -1;

    for (int i = 0; i < localData.length; i++) {

      var row = localData[i]
          .map((e) => (e ?? "").toString().toLowerCase())
          .join(" ");

      int score = 0;

      if(row.contains("call")) score++;
      if(row.contains("type")) score++;
      if(row.contains("a number") || row.contains("aparty") || row.contains("msisdn")) score++;
      if(row.contains("b number") || row.contains("bparty") || row.contains("bnumber")) score++;
      if(row.contains("time") || row.contains("date")) score++;
      if(row.contains("duration") || row.contains("mins") || row.contains("secs")) score++;

      if(score >= 3){
        headerRow = i;
        break;
      }
    }

    if (headerRow == -1) {
      print("CDR header not found");
      return;
    }

    /// Remove profile rows
    localData = localData.sublist(headerRow);

    /// HEADER
    List<String> header =
    localData[0].map((e)=>e.toString()).toList();

    Map<String,int> columns = detectColumns(header);

    print("Detected columns: $columns");
    print("CallType column index: ${columns["CallType"]}");

    /// ------------------------------------------------
    /// STEP 4: STORE DATA UNDER TARGET
    /// ------------------------------------------------

    if (!allCdrTargets.containsKey(target)) {

      allCdrTargets[target] = {
        "data": [],
        "columns": columns
      };

      /// add header
      allCdrTargets[target]!["data"].add(localData[0]);
    }

    /// add rows
    allCdrTargets[target]!["data"].addAll(localData.skip(1));

    /// ------------------------------------------------
    /// STEP 5: LOAD FIRST TARGET
    /// ------------------------------------------------

    selectedTarget = allCdrTargets.keys.first;
    print("TOTAL TARGETS LOADED: ${allCdrTargets.length}");
    loadTarget(selectedTarget);

  }

  Map<String,int> detectColumns(List<String> header){

    Map<String,int> columns = {};

    for(int i=0;i<header.length;i++){

      String h = header[i]
          .toLowerCase()
          .replaceAll("_", "")
          .replaceAll(" ", "")
          .replaceAll("-", "");

      if(h.contains("aparty") ||
          h.contains("msisdn") ||
          h.contains("calling") ||
          h.contains("caller") ||
          h.contains("anumber") ||
          h == "a"){
        columns["Aparty"] ??= i;
      }

      if(h.contains("bparty") ||
          h.contains("bnumber") ||
          h.contains("called") ||
          h.contains("callee") ||
          h.contains("destination") ||
          h == "b"){
        columns["Bparty"] ??= i;
      }

      if(h.contains("starttime") ||
          h.contains("strttm") ||
          h.contains("datetime") ||
          h.contains("timestamp") ||
          h.contains("calltime") ||
          h == "date" ||
          h == "time"){
        columns["Datetime"] ??= i;
      }

      if(h.contains("duration")){
        columns["Duration"] ??= i;
      }

      if(h.contains("mins")) columns["MINS"] ??= i;
      if(h.contains("secs")) columns["SECS"] ??= i;

      if(h.contains("imei")){
        columns["IMEI"] ??= i;
      }

      if(h.contains("imsi")){
        columns["IMSI"] ??= i;
      }

      if(h.contains("cell") ||
          h.contains("site") ||
          h.contains("location") ||
          h.contains("tower")){
        columns["CellID"] ??= i;
      }

      if(h.contains("calltype") || h.endsWith("type")){
        columns["CallType"] ??= i;
      }
      /// DIRECTION
      if(h.contains("direction")){
        columns["Direction"] ??= i;
      }
      if(h.contains("lat")) columns["LAT"] = i;
      if(h.contains("lng") || h.contains("lon")) columns["LNG"] = i;

      if(h.contains("latitude")) columns["Latitude"] = i;
      if(h.contains("longitude")) columns["Longitude"] = i;

      if(h.contains("sitelocation") || h.contains("location"))
        columns["SiteLocation"] = i;
    }

    return columns;
  }

  @override
  Widget build(BuildContext context) {

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          const Text(
            "Import CDR Files",
            style: TextStyle(fontSize: 24),
          ),

          const SizedBox(height:20),

          ElevatedButton(
            onPressed: pickFile,
            child: const Text("Select Files"),
          ),

          const SizedBox(height:20),

          Text(fileName),

          const SizedBox(height:20),

          Text("Contacts found: ${frequentContacts.length}"),
        ],
      ),
    );
  }
}