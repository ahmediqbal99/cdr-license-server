import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/license_service.dart';
import 'services/device_service.dart';

class LicenseScreen extends StatefulWidget {
  @override
  _LicenseScreenState createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {

  String key = "";
  bool loading = false;

  void verifyKey() async {

    final deviceId = await DeviceService.getDeviceId(); // 🔥 HERE

    String status = await LicenseService.activate(key, deviceId);

    if (status == "activated" || status == "valid") {

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("license_key", key);

      Navigator.pushReplacementNamed(context, "/home");

    } else if (status == "used_on_other_device") {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Key already used on another device")),
      );

    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid License Key")),
      );

    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: Center(
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              const Icon(Icons.lock, size: 40, color: Colors.blueAccent),
              const SizedBox(height: 10),

              const Text(
                "Enter License Key",
                style: TextStyle(fontSize: 18),
              ),

              const SizedBox(height: 15),

              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "XXXX-XXXX",
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => key = v,
              ),

              const SizedBox(height: 15),

              loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: verifyKey,
                child: const Text("Activate"),
              )
            ],
          ),
        ),
      ),
    );
  }
}