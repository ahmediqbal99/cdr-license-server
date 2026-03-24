import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';

DateTime parseCDRDate(String raw, String columnName) {

  raw = raw.trim();

  /// 1️⃣ Try automatic ISO parsing
  DateTime? auto = DateTime.tryParse(raw);
  if (auto != null) {
    return auto;
  }

  /// 2️⃣ Excel numeric date
  double? excel = double.tryParse(raw);
  if(excel != null){

    DateTime base = DateTime(1899,12,30);

    int days = excel.floor();
    int seconds =
    ((excel - days) * 86400).round();

    return base.add(
        Duration(days: days, seconds: seconds)
    );
  }

  /// 3️⃣ Telecom formats
  try {

    if(columnName == "STRT_TM"){
      return DateFormat("MM/dd/yyyy HH:mm:ss").parseStrict(raw);
    }

    if(columnName == "Start Time"){
      return DateFormat("dd/MM/yyyy HH:mm").parseStrict(raw);
    }

    if(columnName == "Datetime"){
      return DateFormat("MM/dd/yyyy hh:mm:ss a").parseStrict(raw);
    }

  } catch(e) {
    print("Date parse failed: $raw");
  }

  return DateTime.now();
}
/// MODEL FOR TOWER + TIME
class TowerPoint {
  final LatLng location;
  final DateTime time;
  final String site;

  TowerPoint(this.location, this.time, this.site);
}

class HomeWorkTower {
  final LatLng location;
  final String site;

  HomeWorkTower(this.location, this.site);
}

enum DateFilter {
  oneDay,
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  all
}

class TowerMapScreen extends StatefulWidget {
  final List<List<dynamic>> cdrData;
  final Map<String, int> columns;

  const TowerMapScreen({
    super.key,
    required this.cdrData,
    required this.columns,
  });

  @override
  State<TowerMapScreen> createState() => _TowerMapScreenState();
}

class _TowerMapScreenState extends State<TowerMapScreen> {

  final MapController mapController = MapController();
  bool firstLoad = true;
  DateTime? selectedDay;

  double timelineValue = 0;

  Timer? playTimer;
  bool isPlaying = false;
  bool showHeatmap = true;
  DateFilter selectedFilter = DateFilter.oneMonth;
  @override
  void didUpdateWidget(covariant TowerMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    /// stop animation when new CDR data is loaded
    if(oldWidget.cdrData != widget.cdrData){

      stopAnimation();

      firstLoad = true;

    }
  }
  Future<void> openDatePicker() async {
    stopAnimation();
    var availableDates = getAvailableDates();

    if(availableDates.isEmpty) return;

    var sortedDates = availableDates.toList()..sort();

    DateTime firstDate = sortedDates.first;

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDay ?? firstDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),

      selectableDayPredicate: (day) {

        DateTime normalized = DateTime(day.year, day.month, day.day);

        return availableDates.any((d) =>
        d.year == normalized.year &&
            d.month == normalized.month &&
            d.day == normalized.day);
      },
    );

    if(picked != null){

      setState(() {
        selectedDay = picked;
        timelineValue = 0;
        firstLoad = true;
      });

    }

  }
  Set<DateTime> getAvailableDates() {

    Set<DateTime> dates = {};

    int datetimeIndex = -1;
    String datetimeColumn = "";

    if(widget.columns.containsKey("STRT_TM")){
      datetimeIndex = widget.columns["STRT_TM"]!;
      datetimeColumn = "STRT_TM";
    }
    else if(widget.columns.containsKey("Start Time")){
      datetimeIndex = widget.columns["Start Time"]!;
      datetimeColumn = "Start Time";
    }
    else if(widget.columns.containsKey("Datetime")){
      datetimeIndex = widget.columns["Datetime"]!;
      datetimeColumn = "Datetime";
    }

    if(datetimeIndex == -1) return dates;

    for(int i=1;i<widget.cdrData.length;i++){

      var row = widget.cdrData[i];

      if(datetimeIndex >= row.length) continue;

      DateTime time =
      parseCDRDate(row[datetimeIndex].toString(), datetimeColumn);

      DateTime d = DateTime(time.year,time.month,time.day);

      dates.add(d);

    }

    return dates;
  }
  /// EXTRACT TOWER DATA
  List<TowerPoint> getLocations() {
    List<TowerPoint> points = [];
    int latIndex =
        widget.columns["LAT"] ??
            widget.columns["Latitude"] ??
            -1;

    int lonIndex =
        widget.columns["LNG"] ??
            widget.columns["Longitude"] ??
            -1;

    int siteIndex =
        widget.columns["SiteLocation"] ??
            widget.columns["Location"] ??
            -1;

    int datetimeIndex = -1;
    String datetimeColumn = "";

    if(widget.columns.containsKey("STRT_TM")){
      datetimeIndex = widget.columns["STRT_TM"]!;
      datetimeColumn = "STRT_TM";
    }
    else if(widget.columns.containsKey("Start Time")){
      datetimeIndex = widget.columns["Start Time"]!;
      datetimeColumn = "Start Time";
    }
    else if(widget.columns.containsKey("Datetime")){
      datetimeIndex = widget.columns["Datetime"]!;
      datetimeColumn = "Datetime";
    }

    for (int i = 1; i < widget.cdrData.length; i++) {

      var row = widget.cdrData[i];
      double lat = 0;
      double lon = 0;
      String site = "Unknown Tower";

      if(siteIndex != -1 && siteIndex < row.length){
        site = row[siteIndex].toString();

        if(site.contains("|")){
          site = site.split("|").last;
        }
      }

      if (latIndex != -1 && lonIndex != -1) {

        if (latIndex < row.length && lonIndex < row.length) {

          lat = double.tryParse(row[latIndex].toString()) ?? 0;
          lon = double.tryParse(row[lonIndex].toString()) ?? 0;

        }
      }

      if ((lat == 0 || lon == 0) && siteIndex != -1 && siteIndex < row.length) {

        String loc = row[siteIndex].toString();

        RegExp coord = RegExp(r'(\d{2}\.\d+)\|(\d{2}\.\d+)');

        var match = coord.firstMatch(loc);

        if (match != null) {

          lat = double.tryParse(match.group(1)!) ?? 0;
          lon = double.tryParse(match.group(2)!) ?? 0;

        }
      }

      /// remove invalid towers
      /// Pakistan tower bounds validation
      if(lat < 23 || lat > 38) continue;
      if(lon < 60 || lon > 78) continue;

      DateTime time = DateTime.now();

      if(datetimeIndex != -1 && datetimeIndex < row.length){

        String rawTime = row[datetimeIndex].toString();

        time = parseCDRDate(rawTime, datetimeColumn);
      }

      points.add(
        TowerPoint(
          LatLng(lat, lon),
          time,
          site,
        ),
      );
    }
    if(points.isEmpty){
      return points;
    }

    DateTime referenceTime = points
        .map((p) => p.time)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    /// DATE FILTER

    points = points.where((p){

      switch(selectedFilter){

        case DateFilter.oneDay:

          if(selectedDay == null) return false;

          DateTime d = DateTime(
              p.time.year,
              p.time.month,
              p.time.day
          );

          DateTime selected = DateTime(
              selectedDay!.year,
              selectedDay!.month,
              selectedDay!.day
          );

          return d == selected;

        case DateFilter.oneMonth:
          return p.time.isAfter(
              referenceTime.subtract(const Duration(days:30))
          );

        case DateFilter.threeMonths:
          return p.time.isAfter(
              referenceTime.subtract(const Duration(days:90))
          );

        case DateFilter.sixMonths:
          return p.time.isAfter(
              referenceTime.subtract(const Duration(days:180))
          );

        case DateFilter.oneYear:
          return p.time.isAfter(
              referenceTime.subtract(const Duration(days:365))
          );

        case DateFilter.all:
          return true;
      }

    }).toList();

    points.sort((a,b)=>a.time.compareTo(b.time));

    return points;
  }
  void stopAnimation(){

    playTimer?.cancel();
    playTimer = null;

    isPlaying = false;

    setState(() {
      timelineValue = 0;
    });

  }
  List<WeightedLatLng> buildHeatData(List<TowerPoint> towers){

    Map<String,int> frequency = {};

    for(var t in towers){

      String key =
          "${t.location.latitude},${t.location.longitude}";

      frequency[key] = (frequency[key] ?? 0) + 1;

    }

    List<WeightedLatLng> heat = [];

    frequency.forEach((key,value){

      var parts = key.split(",");

      double lat = double.parse(parts[0]);
      double lng = double.parse(parts[1]);

      heat.add(
          WeightedLatLng(
            LatLng(lat,lng),
            value.toDouble(),
          )
      );

    });

    return heat;
  }

  Map<String, HomeWorkTower?> detectHomeWork(List<TowerPoint> towers){

    Map<String,int> homeFreq = {};
    Map<String,int> workFreq = {};
    Map<String,LatLng> towerLocations = {};

    for(var t in towers){

      int hour = t.time.hour;
      String tower = t.site;

      towerLocations[tower] = t.location;

      /// HOME: 10 PM – 6 AM
      if(hour >= 22 || hour <= 6){
        homeFreq[tower] = (homeFreq[tower] ?? 0) + 1;
      }

      /// WORK: 9 AM – 5 PM
      if(hour >= 9 && hour <= 17){
        workFreq[tower] = (workFreq[tower] ?? 0) + 1;
      }

    }

    HomeWorkTower? home;
    HomeWorkTower? work;

    if(homeFreq.isNotEmpty){

      var best = homeFreq.entries.reduce(
              (a,b)=>a.value>b.value?a:b
      );

      home = HomeWorkTower(
        towerLocations[best.key]!,
        best.key,
      );

    }

    if(workFreq.isNotEmpty){

      var best = workFreq.entries.reduce(
              (a,b)=>a.value>b.value?a:b
      );

      work = HomeWorkTower(
        towerLocations[best.key]!,
        best.key,
      );

    }

    return {
      "home": home,
      "work": work
    };

  }

  /// PLAYBACK CONTROLS

  void startPlayback(){

    if(isPlaying) return;

    firstLoad = false;

    isPlaying = true;

    playTimer = Timer.periodic(
        const Duration(milliseconds:400),
            (timer){

          if(!mounted) return;

          setState(() {

            timelineValue += 0.01;

            if(timelineValue >= 1){
              timelineValue = 1;
              timer.cancel();
              isPlaying = false;
            }

          });

        }
    );

  }

  void pausePlayback(){

    playTimer?.cancel();
    isPlaying = false;

  }

  void stopPlayback(){

    playTimer?.cancel();

    setState(() {
      timelineValue = 0;
    });

    isPlaying = false;

  }

  /// CALCULATE MAP BOUNDS

  LatLngBounds calculateBounds(List<TowerPoint> pts){

    double minLat = pts.first.location.latitude;
    double maxLat = pts.first.location.latitude;
    double minLng = pts.first.location.longitude;
    double maxLng = pts.first.location.longitude;

    for(var p in pts){

      minLat = min(minLat, p.location.latitude);
      maxLat = max(maxLat, p.location.latitude);
      minLng = min(minLng, p.location.longitude);
      maxLng = max(maxLng, p.location.longitude);

    }

    /// prevent zero-size bounds
    if(minLat == maxLat){
      minLat -= 0.0005;
      maxLat += 0.0005;
    }

    if(minLng == maxLng){
      minLng -= 0.0005;
      maxLng += 0.0005;
    }

    return LatLngBounds(
      LatLng(minLat,minLng),
      LatLng(maxLat,maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {

    var towerPoints = getLocations();
    if(towerPoints.isEmpty){
      return const Center(
        child: Text(
          "No tower data for selected date",
          style: TextStyle(fontSize: 18),
        ),
      );
    }
    var homeWork = detectHomeWork(towerPoints);

    var homeTower = homeWork["home"];
    var workTower = homeWork["work"];

    if(towerPoints.isEmpty){
      return const Center(child:Text("No tower location data"));
    }

    int visibleCount;

    if(firstLoad){
      visibleCount = towerPoints.length;
    }else{

      if(towerPoints.isEmpty){
        visibleCount = 0;
      }else{

        double safeTimeline = timelineValue;

        if(safeTimeline.isNaN || safeTimeline.isInfinite){
          safeTimeline = 0;
        }

        visibleCount =
            (towerPoints.length * safeTimeline).floor();

        if(visibleCount <= 0){
          visibleCount = 1;
        }

        if(visibleCount > towerPoints.length){
          visibleCount = towerPoints.length;
        }

      }
    }

    var points = towerPoints.take(visibleCount).toList();

    /// remove home/work towers from clustering


    LatLngBounds bounds;

    if(towerPoints.length <= 1){

      var p = towerPoints.first.location;

      bounds = LatLngBounds(
        LatLng(p.latitude - 0.0005, p.longitude - 0.0005),
        LatLng(p.latitude + 0.0005, p.longitude + 0.0005),
      );

    }else{
      bounds = calculateBounds(towerPoints);
    }

    WidgetsBinding.instance.addPostFrameCallback((_){

      if(towerPoints.isNotEmpty){
        mapController.fitCamera(
          CameraFit.bounds(bounds: bounds),
        );
      }

    });

    return Column(
      children: [

        /// PLAYBACK CONTROLS
        Row(
          children: [

            /// PLAYBACK
            ElevatedButton(
              onPressed: startPlayback,
              child: const Text("▶ Play"),
            ),

            const SizedBox(width:10),

            ElevatedButton(
              onPressed: pausePlayback,
              child: const Text("⏸ Pause"),
            ),

            const SizedBox(width:10),

            ElevatedButton(
              onPressed: stopPlayback,
              child: const Text("■ Stop"),
            ),

            const SizedBox(width:20),

            /// DATE FILTER DROPDOWN
            DropdownButton<DateFilter>(
              value: selectedFilter,
              onChanged: (v) async {

                if(v == DateFilter.oneDay){

                  /// force user to pick date FIRST
                  await openDatePicker();

                  if(selectedDay == null){
                    return; // user cancelled
                  }

                }

                setState(() {
                  selectedFilter = v!;
                  timelineValue = 0;
                  firstLoad = true;
                });

              },
              items: const [

                DropdownMenuItem(
                  value: DateFilter.oneDay,
                  child: Text("Specific Day"),
                ),

                DropdownMenuItem(
                  value: DateFilter.oneMonth,
                  child: Text("1 Month"),
                ),

                DropdownMenuItem(
                  value: DateFilter.threeMonths,
                  child: Text("3 Months"),
                ),

                DropdownMenuItem(
                  value: DateFilter.sixMonths,
                  child: Text("6 Months"),
                ),

                DropdownMenuItem(
                  value: DateFilter.oneYear,
                  child: Text("1 Year"),
                ),

                DropdownMenuItem(
                  value: DateFilter.all,
                  child: Text("All"),
                ),

              ],
            ),

            const SizedBox(width:10),

            /// CALENDAR BUTTON (ONLY FOR SPECIFIC DAY)
            if(selectedFilter == DateFilter.oneDay)
              IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: openDatePicker,
              ),

          ],
        ),

        /// TIMELINE
        Slider(
          value: timelineValue.isNaN ? 0 : timelineValue,
          min: 0,
          max: 1,
          divisions: 100,
          onChanged: (v){
            setState(() {
              timelineValue = v;
            });
          },
        ),

        Expanded(
          child: Stack(
            children: [

              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: bounds.center,
                  initialZoom: 10,
                ),
                children: [

                  TileLayer(
                    urlTemplate:
                    "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    userAgentPackageName: 'com.example.cdr_analyzer',
                  ),
                  if(showHeatmap && towerPoints.length > 5)
                    HeatMapLayer(
                      heatMapDataSource: InMemoryHeatMapDataSource(
                        data: buildHeatData(towerPoints),
                      ),
                      heatMapOptions: HeatMapOptions(
                        radius: 35,
                        minOpacity: 0.3,
                        gradient: {
                          0.2: Colors.blue,
                          0.4: Colors.green,
                          0.6: Colors.yellow,
                          0.8: Colors.orange,
                          1.0: Colors.red,
                        },
                      ),
                    ),
                  /// MOVEMENT PATH
                  if(points.length > 1)
                    PolylineLayer(
                      polylines: List.generate(points.length - 1, (i){

                      return Polyline(
                        points: [
                          points[i].location,
                          points[i+1].location
                        ],
                        color: Colors.blue,
                        strokeWidth: 3,
                      );

                    }),
                  ),

                  /// MARKERS
                  if(points.isNotEmpty)
                    MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      maxClusterRadius: 50,
                      size: const Size(40,40),

                        markers: points.map((p){

                          return Marker(
                            key: ValueKey("${p.site}_${p.location.latitude}_${p.location.longitude}_${p.time.millisecondsSinceEpoch}"),
                            point: p.location,
                            width: 40,
                            height: 40,
                            child: GestureDetector(

                              onTap: (){

                                showDialog(
                                  context: context,
                                  builder:(_){

                                    return AlertDialog(
                                      title: const Text("Tower Information"),
                                      content: Text(
                                          "Tower: ${p.site}\n\n"
                                              "Time: ${DateFormat('yyyy-MM-dd HH:mm').format(p.time)}"
                                      ),
                                    );

                                  },
                                );

                              },

                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 28,
                              ),

                            ),
                          );

                        }).toList(),

                        builder: (context, markers) {

                          Color clusterColor = Colors.deepPurple;

                          for (var m in markers) {

                            if(homeTower != null &&
                                m.point.latitude == homeTower.location.latitude &&
                                m.point.longitude == homeTower.location.longitude){
                              clusterColor = Colors.green; // HOME
                              break;
                            }

                            if(workTower != null &&
                                m.point.latitude == workTower.location.latitude &&
                                m.point.longitude == workTower.location.longitude){
                              clusterColor = Colors.blue; // OFFICE
                              break;
                            }

                          }

                          return Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: clusterColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              markers.length.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }

                    ),
                  ),
                  /// HOME / WORK MARKERS

                ],
              ),

              /// ZOOM BUTTONS
              Positioned(
                right: 15,
                top: 15,
                child: Column(
                  children: [

                    FloatingActionButton(
                      heroTag: "zoomIn",
                      mini: true,
                      child: const Icon(Icons.add),
                      onPressed: (){
                        mapController.move(
                          mapController.camera.center,
                          mapController.camera.zoom + 1,
                        );
                      },
                    ),

                    const SizedBox(height:10),

                    FloatingActionButton(
                      heroTag: "zoomOut",
                      mini: true,
                      child: const Icon(Icons.remove),
                      onPressed: (){
                        mapController.move(
                          mapController.camera.center,
                          mapController.camera.zoom - 1,
                        );
                      },
                    ),

                  ],
                ),
              )

            ],
          ),
        )

      ],
    );
  }
}