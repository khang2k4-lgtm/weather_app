import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

// ─────────────────────────────────────────────────────────
// CONFIG
// ─────────────────────────────────────────────────────────
const String owmApiKey =
    'fef5f16204bc3c6a7fd7cbc31fc6ea74'; // API key thật từ openweathermap.org
const LatLng kDefaultCenter = LatLng(21.0285, 105.8412); // Hà Nội
const double kDefaultZoom = 14.0;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WeatherMapApp());
}

// ─────────────────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────────────────
class HourlyForecast {
  final int temp;
  final String icon;
  final DateTime time;

  HourlyForecast({required this.temp, required this.icon, required this.time});
}

class ForecastDay {
  final String shortDay;
  final String icon;
  final int temp;

  const ForecastDay({
    required this.shortDay,
    required this.icon,
    required this.temp,
  });
}

class WeatherMapApp extends StatelessWidget {
  const WeatherMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thông Tin Thời Tiết',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'sans-serif'),
      home: const HomeScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────
class WeatherData {
  final String city;
  final int temp;
  final int feelsLike;
  final String desc;
  final String icon;
  final double wind;
  final int humidity;
  final int pressure;

  final int visibility;
  final int sunrise;
  final int sunset;
  final double rain;
  final double uvi;
  final int aqi;
  final List<ForecastDay> forecast;
  final List<HourlyForecast> hourly;

  const WeatherData({
    required this.city,
    required this.temp,
    required this.feelsLike,
    required this.desc,
    required this.icon,
    required this.wind,
    required this.humidity,
    required this.pressure,
    required this.visibility,
    required this.sunrise,
    required this.sunset,
    required this.rain,
    required this.uvi,
    required this.aqi,
    required this.forecast,
    required this.hourly,
  });
}

// ─────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────
bool isNight(int sunrise, int sunset) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return now < sunrise || now > sunset;
}

const _shortDays = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];
const _fullDays = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];

String todayLabel() {
  final now = DateTime.now();
  return '${_fullDays[now.weekday - 1]}, ${now.day} tháng ${now.month} ${now.year}';
}

String _owmIconToEmoji(String? icon) {
  if (icon == null) return '🌡';
  final id = icon.replaceAll('d', '').replaceAll('n', '');
  const map = {
    '01': '☀️',
    '02': '⛅',
    '03': '☁️',
    '04': '☁️',
    '09': '🌧',
    '10': '🌦',
    '11': '⛈',
    '13': '❄️',
    '50': '🌫',
  };
  return map[id] ?? '🌡';
}

Widget _weatherDetails(WeatherData w) {
  Widget item(IconData icon, String title, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white60, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "DETAILS",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 15),

            Row(
              children: [
                item(Icons.wb_sunny_outlined, "Sunrise", formatTime(w.sunrise)),
                const SizedBox(width: 10),
                item(Icons.nightlight_round, "Sunset", formatTime(w.sunset)),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                item(Icons.grain, "Rain", "${w.rain} mm"),
                const SizedBox(width: 10),
                item(Icons.air, "Wind", "${w.wind} m/s"),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                item(Icons.water_drop, "Humidity", "${w.humidity}%"),
                const SizedBox(width: 10),
                item(
                  Icons.visibility,
                  "Visibility",
                  "${w.visibility ~/ 1000} km",
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                item(
                  Icons.wb_sunny,
                  "UV Index",
                  w.uvi == 0 ? "Low" : w.uvi.toString(),
                ),
                const SizedBox(width: 10),
                item(Icons.speed, "Pressure", "${w.pressure} hPa"),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _airQuality(WeatherData w) {
  Color aqiColor(int aqi) {
    switch (aqi) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.lightGreen;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.orange;
      case 5:
        return Colors.red;
      default:
        return Colors.white;
    }
  }

  double progress = (w.aqi / 5).clamp(0.0, 1.0);

  return ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        margin: const EdgeInsets.only(top: 15),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("AIR QUALITY", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  getAqiText(w.aqi),
                  style: TextStyle(
                    color: aqiColor(w.aqi),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "AQI ${w.aqi}",
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 🌈 Thanh mức độ AQI
            Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Colors.green,
                          Colors.yellow,
                          Colors.orange,
                          Colors.red,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _sunChart(WeatherData w) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  double progress = (now - w.sunrise) / (w.sunset - w.sunrise);
  progress = progress.clamp(0.0, 1.0);

  return ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        margin: const EdgeInsets.only(top: 15),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "SUNRISE & SUNSET",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatTime(w.sunrise),
                  style: const TextStyle(color: Colors.white54),
                ),
                Text(
                  formatTime(w.sunset),
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),

            const SizedBox(height: 10),

            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;

                return Stack(
                  children: [
                    // nền thanh
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    // progress
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.deepOrange,
                              Colors.orange,
                              Colors.yellow,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // 🌞 mặt trời chạy theo giờ
                    Positioned(
                      left: (width * progress) - 10,
                      top: -6,
                      child: const Icon(
                        Icons.wb_sunny,
                        color: Colors.yellow,
                        size: 16,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

WeatherData _mockWeather(double lat) {
  final now = DateTime.now();
  final icons = ['☁️', '⛅', '🌧', '☀️'];
  final temps = [14, 14, 15, 16];

  final forecast = List.generate(4, (i) {
    final d = now.add(Duration(days: i + 1));
    return ForecastDay(
      shortDay: _shortDays[d.weekday - 1],
      icon: icons[i],
      temp: temps[i],
    );
  });

  return WeatherData(
    city: lat > 20
        ? 'Hà Nội'
        : lat > 15
        ? 'Đà Nẵng'
        : 'Hồ Chí Minh',
    temp: 16,
    feelsLike: 14,
    desc: 'Nhiều mây',
    icon: '☁️',
    wind: 1.3,
    humidity: 72,
    pressure: 1010,

    visibility: 10000,
    sunrise: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    sunset:
        DateTime.now().add(const Duration(hours: 12)).millisecondsSinceEpoch ~/
        1000,
    rain: 1,
    uvi: 0,

    aqi: 2,

    forecast: forecast,
    hourly: [],
  );
}

Future<WeatherData> fetchWeather(double lat, double lon) async {
  if (owmApiKey == 'demo') {
    await Future.delayed(const Duration(milliseconds: 700));
    return _mockWeather(lat);
  }
  try {
    final air = await http.get(
      Uri.parse(
        'http://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$owmApiKey',
      ),
    );
    final res = await http.get(
      Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=$lat&lon=$lon&appid=$owmApiKey&units=metric&lang=vi',
      ),
    );
    final fc = await http.get(
      Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast'
        '?lat=$lat&lon=$lon&appid=$owmApiKey&units=metric&lang=vi',
      ),
    );
    if (res.statusCode != 200) return _mockWeather(lat);

    final c = jsonDecode(res.body);
    final f = jsonDecode(fc.body);
    final hourly = (f['list'] as List).take(8).map((item) {
      final dt = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);

      return HourlyForecast(
        temp: (item['main']['temp'] as num).round(),
        icon: _owmIconToEmoji(item['weather'][0]['icon']),
        time: dt,
      );
    }).toList();
    int aqi = 1;
    if (air.statusCode == 200) {
      final aqiData = jsonDecode(air.body);
      aqi = aqiData['list'][0]['main']['aqi'];
    }

    final Map<String, ForecastDay> dailyMap = {};

    for (var item in f['list']) {
      final dt = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
      final dayKey = "${dt.year}-${dt.month}-${dt.day}";

      if (!dailyMap.containsKey(dayKey)) {
        dailyMap[dayKey] = ForecastDay(
          shortDay: _fullDays[dt.weekday - 1],
          icon: _owmIconToEmoji(item['weather'][0]['icon']),
          temp: (item['main']['temp'] as num).round(),
        );
      }
    }

    final forecast = dailyMap.values.take(7).toList();

    return WeatherData(
      city: c['name'] ?? 'Vị trí hiện tại',
      temp: (c['main']['temp'] as num).round(),
      feelsLike: (c['main']['feels_like'] as num).round(),
      desc: c['weather'][0]['description'] ?? '',
      icon: _owmIconToEmoji(c['weather'][0]['icon']),
      wind: (c['wind']['speed'] as num).toDouble(),
      humidity: c['main']['humidity'] as int,
      pressure: (c['main']['pressure'] as num).round(),

      // 👉 NEW
      visibility: (c['visibility'] ?? 10000),
      sunrise: c['sys']['sunrise'],
      sunset: c['sys']['sunset'],
      rain: (c['rain']?['1h'] ?? 0).toDouble(),
      uvi: 0,

      forecast: forecast,
      aqi: aqi,
      hourly: hourly,
    );
  } catch (_) {
    return _mockWeather(lat);
  }
}

String formatTime(int unix) {
  final dt = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
  return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
}

String getAqiText(int aqi) {
  switch (aqi) {
    case 1:
      return "Tốt";
    case 2:
      return "Khá";
    case 3:
      return "Trung bình";
    case 4:
      return "Kém";
    case 5:
      return "Rất kém";
    default:
      return "--";
  }
}

//@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Future<LatLng?> searchLocation(String query) async {
  try {
    final res = await http.get(
      Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
      ),
      headers: {'User-Agent': 'weather-app'},
    );

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body);
    if (data.isEmpty) return null;

    final lat = double.parse(data[0]['lat']);
    final lon = double.parse(data[0]['lon']);

    return LatLng(lat, lon);
  } catch (e) {
    return null;
  }
}

// ─────────────────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapCtrl = MapController();

  StreamSubscription<Position>? _posSub;

  LatLng? _userLoc;
  LatLng? _selectedLoc;

  bool _isTracking = false;
  bool _loadingWeather = false;
  bool _pickWeatherMode = false;
  WeatherData? _weather;

  double _zoom = kDefaultZoom;

  bool _showMap = false;

  // bool _isFirstFix = true;

  // lưu khu vực đã thêm
  final List<WeatherData> _savedLocations = [];

  // animation
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // LOCATION TRACKING
  // ─────────────────────────────────────────────
  Future<void> _toggleLocate() async {
    // nếu đang tracking => tắt
    if (_isTracking) {
      _stopTracking();

      _toast('❌ Đã tắt định vị');

      return;
    }

    try {
      // kiểm tra GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _toast('⚠ Hãy bật GPS/Vị trí');

        await Geolocator.openLocationSettings();

        return;
      }

      // kiểm tra quyền
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _toast('❌ Quyền vị trí bị từ chối');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _toast('❌ Hãy cấp quyền vị trí trong cài đặt');

        await Geolocator.openAppSettings();

        return;
      }

      // bật tracking
      setState(() {
        _isTracking = true;
        _loadingWeather = true;
      });

      _pulseCtrl.repeat();

      // lấy vị trí hiện tại ngay lập tức
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final loc = LatLng(pos.latitude, pos.longitude);

      // move map
      _mapCtrl.move(loc, 16);

      // lấy weather
      final w = await fetchWeather(pos.latitude, pos.longitude);

      if (!mounted) return;

      setState(() {
        _userLoc = loc;
        _selectedLoc = loc;
        _weather = w;
        _zoom = 16;
        _loadingWeather = false;
      });

      _toast('📍 ${w.city}');

      // stream vị trí realtime
      _posSub?.cancel();

      _posSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((Position position) {
            final newLoc = LatLng(position.latitude, position.longitude);

            if (!mounted) return;

            setState(() {
              _userLoc = newLoc;
            });

            // map follow user
            if (_isTracking) {
              _mapCtrl.move(newLoc, _zoom);
            }
          });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingWeather = false;
        _isTracking = false;
      });

      _pulseCtrl.stop();

      _toast('❌ Không lấy được vị trí');
    }
  }

  // ─────────────────────────────────────────────
  // STOP TRACKING
  // ─────────────────────────────────────────────
  void _stopTracking() {
    _posSub?.cancel();

    _pulseCtrl.stop();

    setState(() {
      _isTracking = false;
    });
  }

  // ─────────────────────────────────────────────
  // MAP CONTROLS
  // ─────────────────────────────────────────────
  void _zoomIn() {
    _zoom = (_zoom + 1).clamp(2.0, 18.0);

    _mapCtrl.move(_mapCtrl.camera.center, _zoom);
  }

  void _zoomOut() {
    _zoom = (_zoom - 1).clamp(2.0, 18.0);

    _mapCtrl.move(_mapCtrl.camera.center, _zoom);
  }

  // ─────────────────────────────────────────────
  // SEARCH LOCATION
  // ─────────────────────────────────────────────
  Future<LatLng?> searchLocation(String query) async {
    try {
      final res = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
        ),
        headers: {'User-Agent': 'weather-app'},
      );

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);

      if (data.isEmpty) return null;

      final lat = double.parse(data[0]['lat']);
      final lon = double.parse(data[0]['lon']);

      return LatLng(lat, lon);
    } catch (e) {
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // SEARCH DIALOG
  // ─────────────────────────────────────────────
  Future<void> _showSearchDialog() async {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Thêm khu vực'),

          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Nhập tên thành phố...',
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Hủy'),
            ),

            TextButton(
              onPressed: () async {
                final text = controller.text.trim();

                if (text.isEmpty) return;

                Navigator.pop(context);

                setState(() {
                  _loadingWeather = true;
                });

                final loc = await searchLocation(text);

                if (loc == null) {
                  _toast('❌ Không tìm thấy địa điểm');

                  setState(() {
                    _loadingWeather = false;
                  });

                  return;
                }

                _mapCtrl.move(loc, 14);

                _zoom = 14;

                final w = await fetchWeather(loc.latitude, loc.longitude);

                setState(() {
                  _weather = w;
                  _userLoc = loc;
                  _loadingWeather = false;

                  // thêm vào danh sách
                  if (!_savedLocations.any((e) => e.city == w.city)) {
                    _savedLocations.add(w);
                  }
                });

                _toast('📍 ${w.city}');
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // TOAST
  // ─────────────────────────────────────────────
  void _toast(String msg, {int seconds = 2}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white)),
          duration: Duration(seconds: seconds),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF0A2540),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.only(bottom: 120, left: 32, right: 32),
        ),
      );
  }

  // ─────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 👉 Weather full màn hình
            Positioned.fill(child: _buildWeatherPanel()),

            // 👉 Map overlay (chỉ khi bật)
            if (_showMap)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.9),
                  child: _buildMapPanel(),
                ),
              ),

            // 👉 Nút bật/tắt map
            Positioned(
              top: 20,
              right: 20,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.black.withOpacity(0.6),
                onPressed: () {
                  setState(() {
                    _showMap = !_showMap;
                  });
                },
                child: Icon(
                  _showMap ? Icons.close : Icons.map,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // WEATHER PANEL
  // ─────────────────────────────────────────────────────
  Widget _buildWeatherPanel() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors:
              (_weather != null && isNight(_weather!.sunrise, _weather!.sunset))
              ? [const Color(0xFF0B1D3A), const Color(0xFF000000)]
              : [const Color(0xFF6EC6FF), const Color(0xFF1E88E5)],
        ),
      ),
      child: _loadingWeather
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _weather == null
                  ? _buildWeatherEmpty()
                  : _buildWeatherContent(_weather!),
            ),
    );
  }

  Widget _buildWeatherEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_searching, color: Colors.white60, size: 52),
          const SizedBox(height: 14),
          Text(
            _isTracking
                ? 'Đang xác định vị trí...'
                : 'Đang chờ vị trí tự động hoặc thêm khu vực mới',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _showSearchDialog,
            icon: const Icon(Icons.add_location, color: Colors.white),
            label: const Text(
              'Thêm khu vực',
              style: TextStyle(color: Colors.white),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              backgroundColor: Colors.white24,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherContent(WeatherData w) {
    final bool night = isNight(w.sunrise, w.sunset);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Stack(
        children: [
          // 🌙 / ☀️ BACKGROUND
          ...[
            if (night) ...[
              ...List.generate(30, (i) {
                return Positioned(
                  top: (i * 37) % 500 + 20,
                  left: (i * 53) % 350,
                  child: AnimatedOpacity(
                    duration: Duration(milliseconds: 800 + (i * 40)),
                    opacity: 0.3 + (i % 5) * 0.1,
                    child: Container(
                      width: 2,
                      height: 2,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),

              Positioned(
                right: -30,
                top: 40,
                child: Opacity(
                  opacity: 0.2,
                  child: Icon(
                    Icons.nightlight_round,
                    size: 180,
                    color: Colors.white,
                  ),
                ),
              ),
            ] else ...[
              Positioned(
                right: -40,
                top: 20,
                child: Opacity(
                  opacity: 0.25,
                  child: Icon(
                    Icons.wb_sunny,
                    size: 180,
                    color: Colors.yellowAccent,
                  ),
                ),
              ),
            ],
          ],

          // 📊 CONTENT
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: SizedBox(
              width: double.infinity, // ✅ FIX LỖI CHÍNH
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CITY
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "📍 ${w.city}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const Icon(Icons.more_vert, color: Colors.white70),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Updated: ${todayLabel()}",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showSearchDialog,
                        icon: const Icon(
                          Icons.add_location,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Thêm khu vực',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white24,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "${w.temp}°",
                    style: const TextStyle(
                      fontSize: 80,
                      color: Colors.white,
                      fontWeight: FontWeight.w300,
                    ),
                  ),

                  Text(
                    w.desc.toUpperCase(),
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "↑ ${w.temp + 2}°   ↓ ${w.temp - 2}°",
                    style: const TextStyle(color: Colors.white60),
                  ),

                  const SizedBox(height: 20),

                  // ✅ FIX INFOBOX (KHÔNG LỖI NỮA)
                  Row(
                    children: [
                      _infoBox(Icons.water_drop, "${w.humidity}%"),
                      const SizedBox(width: 10),
                      _infoBox(Icons.thermostat, "${w.feelsLike}°"),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _hourlyForecast(w),

                  const SizedBox(height: 20),

                  _dailyForecast(w),

                  const SizedBox(height: 20),

                  _weatherDetails(w),
                  _airQuality(w),
                  _sunChart(w),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _hourlyForecast(WeatherData w) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "HOURLY FORECAST",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),

          SizedBox(
            height: 95,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: w.hourly.length,
              itemBuilder: (context, i) {
                final h = w.hourly[i];

                return Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${h.temp}°",
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(h.icon),
                      Text(
                        "${h.time.hour.toString().padLeft(2, '0')}:00",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dailyForecast(WeatherData w) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "DAILY FORECAST",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),

          ...w.forecast.map(
            (f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      f.shortDay,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  Text(f.icon),
                  Text(
                    "${f.temp}°",
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // MAP PANEL
  // ─────────────────────────────────────────────────────
  Widget _buildMapPanel() {
    return Stack(
      children: [
        // ───────────────── MAP ─────────────────
        FlutterMap(
          mapController: _mapCtrl,

          options: MapOptions(
            initialCenter: kDefaultCenter,
            initialZoom: kDefaultZoom,

            // 👉 CLICK MAP LẤY THỜI TIẾT
            onTap: (tapPosition, point) async {
              // chỉ hoạt động khi bật chế độ pick weather
              if (!_pickWeatherMode) return;

              setState(() {
                _selectedLoc = point;
                _loadingWeather = true;
              });

              // move camera
              _mapCtrl.move(point, 15);

              try {
                final w = await fetchWeather(point.latitude, point.longitude);

                if (!mounted) return;

                setState(() {
                  _weather = w;
                  _loadingWeather = false;
                });

                _toast('📍 ${w.city}: ${w.temp}° - ${w.desc}');
              } catch (e) {
                setState(() {
                  _loadingWeather = false;
                });

                _toast('❌ Không lấy được thời tiết');
              }
            },
          ),

          children: [
            // ───────────────── TILE ─────────────────
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.weather_map',
            ),

            // ───────────────── USER LOCATION ─────────────────
            if (_userLoc != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _userLoc!,
                    width: 28,
                    height: 28,
                    child: _LocationDot(),
                  ),
                ],
              ),

            // ───────────────── WEATHER MARKER ─────────────────
            if (_selectedLoc != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLoc!,
                    width: 90,
                    height: 100,

                    child: Column(
                      children: [
                        // 🌡 TEMP BOX
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),

                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.78),
                            borderRadius: BorderRadius.circular(12),
                          ),

                          child: Text(
                            _weather != null ? "${_weather!.temp}°" : "...",

                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // ☁️ RED GLOW MARKER
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,

                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),

                          padding: const EdgeInsets.all(8),

                          child: const Icon(
                            Icons.cloud,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),

        // ───────────────── LOADING ─────────────────
        if (_loadingWeather)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(14),

              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(16),
              ),

              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(width: 12),

                  Text(
                    "Đang tải thời tiết...",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

        // ───────────────── TOP MODE INFO ─────────────────
        if (_pickWeatherMode)
          Positioned(
            top: 90,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.9),
                borderRadius: BorderRadius.circular(14),
              ),

              child: const Row(
                children: [
                  Icon(Icons.touch_app, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Chạm vào bản đồ để xem thời tiết",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ───────────────── CONTROL BAR ─────────────────
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Center(child: _buildControlBar()),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // CONTROL BAR
  // ─────────────────────────────────────────────────────
  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F33).withOpacity(0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapCtrlBtn(
            icon: Icons.search,
            tooltip: 'Tìm địa điểm',
            onTap: _showSearchDialog,
          ),
          const SizedBox(width: 6),
          // Locate button with pulse when active
          const SizedBox(width: 6),

          // ☁️ CLICK MAP WEATHER MODE
          _MapCtrlBtn(
            icon: Icons.touch_app,
            tooltip: 'Chạm bản đồ xem thời tiết',

            active: _pickWeatherMode,

            onTap: () {
              setState(() {
                _pickWeatherMode = !_pickWeatherMode;
              });

              _toast(
                _pickWeatherMode
                    ? '☁️ Đã bật chế độ chọn thời tiết'
                    : '❌ Đã tắt chế độ chọn thời tiết',
              );
            },
          ),
          _MapCtrlBtn(
            icon: Icons.my_location,
            tooltip: _isTracking ? 'Tắt định vị' : 'Định vị',
            onTap: _toggleLocate,
            active: _isTracking,
            pulseController: _isTracking ? _pulseCtrl : null,
          ),
          const SizedBox(width: 6),
          _MapCtrlBtn(icon: Icons.remove, tooltip: 'Thu nhỏ', onTap: _zoomOut),
          const SizedBox(width: 6),
          _MapCtrlBtn(icon: Icons.add, tooltip: 'Phóng to', onTap: _zoomIn),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────

/// Blue pulsing dot for user location
class _LocationDot extends StatefulWidget {
  @override
  State<_LocationDot> createState() => _LocationDotState();
}

class _LocationDotState extends State<_LocationDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _anim = Tween(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E88E5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E88E5).withOpacity(_anim.value),
              blurRadius: 10,
              spreadRadius: 5,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single square button in the map control bar
class _MapCtrlBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final AnimationController? pulseController;

  const _MapCtrlBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    Widget btn = Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF2E7D32).withOpacity(0.9)
                : const Color(0xFF152840),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? const Color(0xFF66BB6A).withOpacity(0.55)
                  : Colors.white.withOpacity(0.14),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: active ? Colors.white : Colors.white.withOpacity(0.85),
            size: 22,
          ),
        ),
      ),
    );

    // Wrap with pulse animation when active
    if (pulseController != null) {
      btn = AnimatedBuilder(
        animation: pulseController!,
        builder: (_, child) => Opacity(
          opacity: 0.75 + 0.25 * pulseController!.value,
          child: child,
        ),
        child: btn,
      );
    }

    return btn;
  }
}
