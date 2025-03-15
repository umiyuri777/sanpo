import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:sanpo/import.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.title});

  final String title;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  LocationData? _currentLocation;
  final location = Location();

  void _requestLocationPermission() async {
    await RequestLocationPermission.request(location);
  }

  void _getLocation() {
    GetLocation.getPosition(location)
        .then((value) => setState(() => _currentLocation = value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                '$_currentLocation',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            ButtonBar(
              alignment: MainAxisAlignment.center,
              buttonPadding: const EdgeInsets.all(10),
              children: [
                SizedBox(
                  height: 50,
                  width: 105,
                  child: ElevatedButton(
                    onPressed: _requestLocationPermission,
                    child: const Text('request'),
                  ),
                ),
                SizedBox(
                  height: 50,
                  width: 105,
                  child: ElevatedButton(
                    onPressed: _getLocation,
                    child: const Text('get'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}