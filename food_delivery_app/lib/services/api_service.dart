import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html if (dart.library.html) 'dart:html';

class ApiService {
  static const String baseUrl = 'https://plus.apexjets.org/api';
  static const String overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const String googlePlacesUrl = 'https://maps.googleapis.com/maps/api/place';
  static String get googleApiKey => dotenv.env['GOOGLE_API_KEY'] ?? 'YOUR_GOOGLE_API_KEY';
  String? _token;
  static const bool _isWeb = identical(0, 0.0);

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Getter for token
  String? get token => _token;

  // Headers with token
  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // Load token from persistent storage (Updated for web support)
  Future<void> loadToken() async {
    if (_isWeb) {
      _token = html.window.localStorage['auth_token'];
    } else {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
    }
  }

  // Set token and persist it (Updated for web support)
  Future<void> setToken(String token) async {
    _token = token;
    if (_isWeb) {
      html.window.localStorage['auth_token'] = token;
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    }
  }

  // Clear token (Updated for web support)
  Future<void> clearToken() async {
    _token = null;
    if (_isWeb) {
      html.window.localStorage.remove('auth_token');
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    }
  }

  // Generic HTTP Methods
  Future<dynamic> get(String path) async {
    if (_token == null && !path.startsWith('/login') && !path.startsWith('/register')) {
      throw Exception('No token set. Please log in.');
    }
    final url = '$baseUrl$path';
    final response = await http.get(Uri.parse(url), headers: headers);
    return _handleResponse(response, action: 'GET $path');
  }

  Future<dynamic> post(String path, dynamic data) async {
    if (_token == null && !path.startsWith('/login') && !path.startsWith('/register')) {
      throw Exception('No token set. Please log in.');
    }
    final url = '$baseUrl$path';
    final body = json.encode(data);
    final response = await http.post(Uri.parse(url), headers: headers, body: body);
    return _handleResponse(response, action: 'POST $path');
  }

  Future<dynamic> put(String path, dynamic data) async {
    if (_token == null) throw Exception('No token set. Please log in.');
    final url = '$baseUrl$path';
    final body = json.encode(data);
    final response = await http.put(Uri.parse(url), headers: headers, body: body);
    return _handleResponse(response, action: 'PUT $path');
  }

  Future<dynamic> delete(String path) async {
    if (_token == null) throw Exception('No token set. Please log in.');
    final url = '$baseUrl$path';
    final response = await http.delete(Uri.parse(url), headers: headers);
    return _handleResponse(response, action: 'DELETE $path');
  }

  // Handle HTTP response
  Future<dynamic> _handleResponse(http.Response response, {String action = 'API request'}) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isNotEmpty ? json.decode(response.body) : null;
    }
    throw Exception('$action failed: ${response.statusCode} - ${response.body}');
  }

  // Authentication Methods
  Future<Map<String, dynamic>> register(String name, String email, String password, String role) async {
    return await post('/register', {'name': name, 'email': email, 'password': password, 'role': role});
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    return await post('/login', {'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> loginWithGoogle(String email, String accessToken) async {
    return await post('/google-login', {'email': email, 'google_token': accessToken});
  }

  Future<void> logout() async {
    if (_token == null) {
      await clearToken();
      return;
    }
    await post('/logout', {});
    await clearToken();
  }

  Future<Map<String, dynamic>> getProfile() async {
    return await get('/profile');
  }

  Future<Map<String, dynamic>> updateProfile(
    String name,
    String email, {
    String? deliveryLocation,
    String? role,
    String? phone,
    String? vehicle,
  }) async {
    final body = {
      'name': name,
      'email': email,
      if (deliveryLocation != null) 'delivery_location': deliveryLocation,
      if (role != null) 'role': role,
      if (phone != null) 'phone': phone,
      if (vehicle != null) 'vehicle': vehicle,
    };
    return await put('/profile', body);
  }

  Future<Map<String, dynamic>> upgradeRole(String newRole) async {
    return await post('/upgrade-role', {'role': newRole});
  }

  // Restaurant Methods
  Future<List<Map<String, dynamic>>> getRestaurantsFromOverpass({
    double south = 4.0,
    double west = 2.0,
    double north = 14.0,
    double east = 15.0,
  }) async {
    final query = '[out:json];node["amenity"="restaurant"]($south,$west,$north,$east);out;';
    final url = '$overpassUrl?data=${Uri.encodeQueryComponent(query)}';
    final response = await http.get(Uri.parse(url));
    final overpassData = await _handleResponse(response, action: 'Overpass Fetch');
    final elements = overpassData['elements'] as List<dynamic>;
    List<Map<String, dynamic>> restaurants = [];

    for (var restaurant in elements) {
      final name = restaurant['tags']['name'] ?? 'Unnamed Restaurant';
      final lat = restaurant['lat'].toString();
      final lon = restaurant['lon'].toString();

      String? imageUrl;
      final googleUrl = '$googlePlacesUrl/nearbysearch/json?location=$lat,$lon&radius=500&type=restaurant&keyword=$name&key=$googleApiKey';
      final googleResponse = await http.get(Uri.parse(googleUrl));
      if (googleResponse.statusCode == 200) {
        final googleData = json.decode(googleResponse.body);
        if (googleData['results'].isNotEmpty && googleData['results'][0]['photos'] != null) {
          final photoReference = googleData['results'][0]['photos'][0]['photo_reference'];
          imageUrl = '$googlePlacesUrl/photo?maxwidth=400&photoreference=$photoReference&key=$googleApiKey';
        }
      }

      restaurants.add({
        'id': restaurant['id'].toString(),
        'name': name,
        'lat': lat,
        'lon': lon,
        'image': imageUrl ?? 'https://via.placeholder.com/300',
        'tags': restaurant['tags'],
      });
    }
    return restaurants;
  }

  Future<Map<String, double>> getBoundingBox(String location) async {
    final locations = await locationFromAddress(location);
    if (locations.isEmpty) throw Exception('Location not found');
    final lat = locations.first.latitude;
    final lon = locations.first.longitude;
    const delta = 0.45; // ~50km
    return {'south': lat - delta, 'west': lon - delta, 'north': lat + delta, 'east': lon + delta};
  }

  Future<Map<String, dynamic>> addRestaurant(
    String name,
    String address,
    String state,
    String country,
    String category, {
    double? latitude,
    double? longitude,
    String? image,
    required List<Map<String, dynamic>> menuItems,
  }) async {
    final body = {
      'name': name,
      'address': address,
      'state': state,
      'country': country,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'image': image,
      'menu_items': menuItems,
    };
    return await post('/restaurants', body);
  }

  Future<List<dynamic>> getRestaurantsFromApi() async {
    final data = await get('/restaurants');
    return data is List ? data : data['restaurants'] ?? data['data'] ?? [];
  }

  // Order Management
  Future<List<dynamic>> getOrders() async {
    final data = await get('/orders');
    return data is List ? data : data['orders'] ?? [];
  }

  Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> orderData) async {
    return await post('/orders', orderData);
  }

  Future<void> updateOrderPaymentStatus(String orderId, String status) async {
    await put('/orders/$orderId/payment-status', {'status': status});
  }

  Future<void> cancelOrder(String orderId) async {
    await post('/orders/$orderId/cancel', {});
  }

  Future<Map<String, dynamic>> getOrderTracking(String trackingNumber) async {
    return await get('/orders/track/$trackingNumber');
  }

  Future<List<dynamic>> getRestaurantOrders() async {
    final data = await get('/restaurant-orders');
    return data is List ? data : data['orders'] ?? [];
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await put('/orders/$orderId/status', {'status': status});
  }

  // Grocery Methods
  Future<List<dynamic>> getGroceries() async {
    final data = await get('/grocery');
    return data is List ? data : data['data'] ?? [];
  }

  Future<List<dynamic>> fetchGroceryProducts() async {
    return await getGroceries();
  }

  Future<Map<String, dynamic>> createGrocery(List<Map<String, dynamic>> items) async {
    final totalAmount = items.fold(0.0, (sum, item) => sum + (item['quantity'] * item['price']));
    final body = {
      'items': items,
      'total_amount': totalAmount,
      'status': 'pending',
    };
    return await post('/grocery', body);
  }

  Future<void> deleteGrocery(String groceryId) async {
    await delete('/grocery/$groceryId');
  }

  Future<Map<String, dynamic>> initiateCheckout(String groceryId, {String paymentMethod = 'stripe'}) async {
    return await post('/grocery/$groceryId/checkout', {'payment_method': paymentMethod});
  }

  Future<List<dynamic>> fetchUserGroceries() async {
    final data = await get('/user/groceries');
    return data is List ? data : data['groceries'] ?? data['data'] ?? [];
  }

  // Dasher Methods
  Future<List<dynamic>> getDasherOrders() async {
    final data = await get('/dasher/orders');
    return data is List ? data : data['orders'] ?? [];
  }

  Future<Map<String, dynamic>> acceptOrder(String orderId) async {
    return await post('/dasher/orders/$orderId/accept', {});
  }

  // New Method: Fetch Customer Reviews
  Future<List<dynamic>> fetchCustomerReviews() async {
    final data = await get('/customer-reviews');
    return data is List ? data : data['reviews'] ?? data['data'] ?? [];
  }
}