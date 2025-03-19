import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:uni_links/uni_links.dart'; // Add this for deep linking
import 'dart:async';
import 'auth_provider.dart'; // Keep this in lib/ if it’s there
import 'screens/checkout_screen.dart'; // Adjusted to lib/screens/
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/add_restaurant_screen.dart';
import 'screens/restaurant_screen.dart';
import 'screens/restaurant_profile_screen.dart';
import 'screens/restaurant_owner_screen.dart';
import 'screens/order_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/logistics_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/grocery_screen.dart';

const primaryColor = Color(0xFFFF7043); // Warm Coral (Appetizing & Playful)
const textColor = Color(0xFF3E2723); // Deep Brown (Rich & Readable)
const accentColor = Color(0xFF66BB6A); // Fresh Green (Healthy & Organic)
const secondaryColor = Color(0xFFFFCA28); // Soft Gold (Friendly & Energetic)

Future<void> main() async {
  try {
    await dotenv.load(fileName: ".env");
    print('Dotenv loaded successfully');
  } catch (e) {
    print('Error loading .env: $e');
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) {
        print('Creating AuthProvider');
        final authProvider = AuthProvider();
        authProvider.loadToken(); // Load token on startup
        return authProvider;
      },
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    initUniLinks();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> initUniLinks() async {
    try {
      // Handle initial deep link when app starts
      final initialLink = await getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }

      // Listen for deep links while app is running
      _sub = linkStream.listen((String? link) {
        if (link != null) {
          _handleDeepLink(link);
        }
      }, onError: (err) {
        print('Deep link error: $err');
      });
    } catch (e) {
      print('Error initializing deep links: $e');
    }
  }

  void _handleDeepLink(String link) {
    final uri = Uri.parse(link);
    if (uri.scheme == 'chiwexpress' && uri.host == 'orders') {
      final orderId = uri.queryParameters['order_id'];
      final status = uri.queryParameters['status'];
      print('Handling deep link: $link, orderId: $orderId, status: $status');

      // Navigate to Orders screen with orderId and status
      Navigator.pushReplacementNamed(
        context,
        '/orders',
        arguments: {'orderId': orderId, 'status': status},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building MyApp');
    return MaterialApp(
      title: 'Chiw Express',
      theme: ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: Colors.grey[100],
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
          accentColor: accentColor,
        ).copyWith(secondary: secondaryColor),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: textColor, fontFamily: 'Poppins'),
          titleLarge: TextStyle(color: textColor, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
          labelLarge: TextStyle(color: Colors.white, fontSize: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontFamily: 'Poppins'),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) {
          print('Navigating to SplashScreen');
          return const SplashScreen();
        },
        '/login': (context) {
          print('Navigating to LoginScreen');
          return const LoginScreen();
        },
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const HomeScreen(),
        '/add-restaurant': (context) => const AddRestaurantScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/orders': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final orderId = args?['orderId'] as String?;
          final status = args?['status'] as String?;
          print('Navigating to OrderScreen with orderId: $orderId, status: $status');
          return OrderScreen(orderId: orderId, initialStatus: status);
        },
        '/dashers': (context) => const Scaffold(body: Center(child: Text('Dashers'))),
        '/logistics': (context) => const LogisticsScreen(),
        '/groceries': (context) => const GroceryScreen(),
        '/restaurants': (context) => const RestaurantScreen(),
        '/restaurant-profile': (context) => const RestaurantProfileScreen(
              restaurant: {
                'image': 'https://via.placeholder.com/300',
                'tags': {'name': 'Test Restaurant', 'address': '123 Test St'},
                'lat': 6.5,
                'lon': 3.3,
              },
            ),
        '/restaurant-owner': (context) => const RestaurantOwnerScreen(),
        '/cart': (context) => const CartScreen(),
        '/checkout': (context) => const CheckoutScreen(), // No cart parameter
      },
      onUnknownRoute: (settings) {
        print('Unknown route: ${settings.name}');
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Route not found'))));
      },
    );
  }
}