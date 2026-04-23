import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: CruchefFirebaseOptions.currentPlatform,
  );
  runApp(const CruchefApp());
}

class CruchefApp extends StatefulWidget {
  const CruchefApp({super.key});

  @override
  State<CruchefApp> createState() => _CruchefAppState();
}

class _CruchefAppState extends State<CruchefApp> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CruchefApi _api = CruchefApi();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final Map<String, int> _cart = <String, int>{};
  final TextEditingController _manualQrController = TextEditingController();
  final TextEditingController _voiceController = TextEditingController();

  bool _isBusy = false;
  bool _backendOnline = true;
  List<Dish> _dishes = <Dish>[];
  List<OrderRecord> _orders = <OrderRecord>[];
  String? _selectedRestaurantName;
  String _selectedCategory = 'Todas';

  @override
  void dispose() {
    _manualQrController.dispose();
    _voiceController.dispose();
    super.dispose();
  }

  User? get _firebaseUser => _auth.currentUser;

  List<RestaurantSummary> get _restaurants {
    final Map<String, List<Dish>> grouped = <String, List<Dish>>{};
    for (final Dish dish in _dishes) {
      grouped.putIfAbsent(dish.restaurantName, () => <Dish>[]).add(dish);
    }

    return grouped.entries.map((MapEntry<String, List<Dish>> entry) {
      final Dish firstDish = entry.value.first;
      return RestaurantSummary(
        id: firstDish.restaurantId,
        ownerUid: firstDish.ownerUid,
        name: entry.key,
        qrCode: buildRestaurantQr(entry.key),
        dishes: entry.value,
      );
    }).toList(growable: false);
  }

  RestaurantSummary? get _selectedRestaurant {
    if (_restaurants.isEmpty) {
      return null;
    }
    final String restaurantName =
        _selectedRestaurantName ?? _restaurants.first.name;
    for (final RestaurantSummary restaurant in _restaurants) {
      if (restaurant.name == restaurantName) {
        return restaurant;
      }
    }
    return _restaurants.first;
  }

  List<String> get _categories {
    final RestaurantSummary? restaurant = _selectedRestaurant;
    if (restaurant == null) {
      return const <String>['Todas'];
    }
    final List<String> categories = restaurant.dishes
        .map((Dish dish) => dish.categoryId)
        .toSet()
        .toList(growable: false);
    return <String>['Todas', ...categories];
  }

  List<Dish> get _visibleDishes {
    final RestaurantSummary? restaurant = _selectedRestaurant;
    if (restaurant == null) {
      return const <Dish>[];
    }
    return restaurant.dishes.where((Dish dish) {
      if (_selectedCategory == 'Todas') {
        return true;
      }
      return dish.categoryId == _selectedCategory;
    }).toList(growable: false);
  }

  List<OrderRecord> get _trackingOrders {
    return _orders.where((OrderRecord order) {
      return order.status != OrderStatus.delivered &&
          order.status != OrderStatus.cancelled;
    }).toList(growable: false);
  }

  List<OrderRecord> get _historyOrders {
    return _orders.where((OrderRecord order) {
      return order.status == OrderStatus.delivered ||
          order.status == OrderStatus.cancelled;
    }).toList(growable: false);
  }

  List<CartEntry> get _cartEntries {
    return _cart.entries.map((MapEntry<String, int> entry) {
      final Dish? dish = _findDish(entry.key);
      if (dish == null) {
        return null;
      }
      return CartEntry(dish: dish, quantity: entry.value);
    }).whereType<CartEntry>().toList(growable: false);
  }

  int get _cartCount {
    int total = 0;
    for (final int value in _cart.values) {
      total += value;
    }
    return total;
  }

  double get _cartTotal {
    double total = 0;
    for (final CartEntry entry in _cartEntries) {
      total += entry.total;
    }
    return total;
  }

  Dish? _findDish(String id) {
    for (final Dish dish in _dishes) {
      if (dish.id == id) {
        return dish;
      }
    }
    return null;
  }

  int _quantityForDish(String dishId) => _cart[dishId] ?? 0;

  void _showSnackBar(
    String message, {
    Color backgroundColor = const Color(0xFF4C1D1D),
  }) {
    final ScaffoldMessengerState? messenger = _scaffoldMessengerKey.currentState;
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: backgroundColor,
          content: Text(message),
        ),
      );
  }

  Future<void> _login(String email, String password) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _bootstrap();
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
      });
      _showSnackBar(error.message ?? 'No se pudo iniciar sesion.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
      });
      _showSnackBar('Error de acceso: $error');
    }
  }

  Future<void> _bootstrap() async {
    final User? user = _firebaseUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
      return;
    }

    try {
      final bool backendOnline = await _api.health();
      final List<Dish> dishes = await _api.getDishes();
      final List<OrderRecord> orders = await _api.getOrders(
        customerUid: user.uid,
      );

      if (!mounted) {
        return;
      }

      final String? firstRestaurant =
          dishes.isEmpty ? null : dishes.first.restaurantName;

      setState(() {
        _backendOnline = backendOnline;
        _dishes = dishes;
        _orders = orders;
        _selectedRestaurantName = firstRestaurant;
        _selectedCategory = 'Todas';
        _cart.clear();
        _isBusy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _backendOnline = false;
        _isBusy = false;
      });
      _showSnackBar('No se pudo sincronizar con CruChef: $error');
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isBusy = true;
    });
    await _auth.signOut();
    if (!mounted) {
      return;
    }
    setState(() {
      _isBusy = false;
      _dishes = <Dish>[];
      _orders = <OrderRecord>[];
      _selectedRestaurantName = null;
      _selectedCategory = 'Todas';
      _cart.clear();
    });
  }

  void _selectRestaurant(String restaurantName) {
    setState(() {
      _selectedRestaurantName = restaurantName;
      _selectedCategory = 'Todas';
      _cart.clear();
    });
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  void _addToCart(Dish dish) {
    if (_selectedRestaurantName != null &&
        dish.restaurantName != _selectedRestaurantName) {
      return;
    }
    setState(() {
      _cart.update(dish.id, (int value) => value + 1, ifAbsent: () => 1);
    });
  }

  void _removeFromCart(Dish dish) {
    final int? quantity = _cart[dish.id];
    if (quantity == null) {
      return;
    }
    setState(() {
      if (quantity <= 1) {
        _cart.remove(dish.id);
      } else {
        _cart[dish.id] = quantity - 1;
      }
    });
  }

  bool _applyQrCode(String rawCode) {
    final String normalized = normalizeRestaurantValue(rawCode);
    for (final RestaurantSummary restaurant in _restaurants) {
      if (normalizeRestaurantValue(restaurant.qrCode) == normalized ||
          normalizeRestaurantValue(restaurant.name) == normalized) {
        _selectRestaurant(restaurant.name);
        return true;
      }
    }
    return false;
  }

  void _submitManualQr() {
    final bool found = _applyQrCode(_manualQrController.text);
    _manualQrController.clear();
    _showSnackBar(
      found ? 'Restaurante actualizado.' : 'QR no reconocido.',
      backgroundColor:
          found ? const Color(0xFF163928) : const Color(0xFF4C1D1D),
    );
  }

  void _openScanner() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ScannerPage(
          onDetected: (String code) {
            final bool found = _applyQrCode(code);
            Navigator.of(context).pop();
            if (!mounted) {
              return;
            }
            _showSnackBar(
              found
                  ? 'Restaurante cambiado a ${_selectedRestaurant?.name ?? ''}.'
                  : 'QR no reconocido.',
              backgroundColor:
                  found ? const Color(0xFF163928) : const Color(0xFF4C1D1D),
            );
          },
        ),
      ),
    );
  }

  Future<void> _placeOrder() async {
    final User? user = _firebaseUser;
    final RestaurantSummary? restaurant = _selectedRestaurant;
    if (user == null || restaurant == null || _cartEntries.isEmpty) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      for (final CartEntry entry in _cartEntries) {
        await _api.createOrder(
          OrderCreatePayload(
            ownerUid: entry.dish.ownerUid,
            restaurantId: entry.dish.restaurantId,
            restaurantName: entry.dish.restaurantName,
            customerUid: user.uid,
            customerEmail: user.email ?? '',
            customerName: user.displayName ?? 'Cliente CruChef',
            dishId: entry.dish.id,
            dishName: entry.dish.name,
            dishImageUrl: entry.dish.imageUrl,
            categoryId: entry.dish.categoryId,
            quantity: entry.quantity,
            unitPrice: entry.dish.price,
            notes: '',
          ),
        );
      }

      final List<OrderRecord> orders = await _api.getOrders(
        customerUid: user.uid,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _orders = orders;
        _cart.clear();
        _isBusy = false;
      });

      _showSnackBar(
        'Pedido enviado correctamente.',
        backgroundColor: const Color(0xFF163928),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
      });
      _showSnackBar('No se pudo crear el pedido: $error');
    }
  }

  Future<void> _rateOrder(OrderRecord order) async {
    final RatingResult? result = await showDialog<RatingResult>(
      context: context,
      builder: (BuildContext context) => RatingDialog(order: order),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await _api.rateOrder(
        id: order.id,
        rating: result.rating,
        reviewText: result.reviewText,
      );

      final User? user = _firebaseUser;
      if (user != null) {
        _orders = await _api.getOrders(customerUid: user.uid);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isBusy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
      });
      _showSnackBar('No se pudo calificar la orden: $error');
    }
  }

  Future<void> _analyzeVoiceText() async {
    if (_voiceController.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _isBusy = true;
    });

    try {
      final String result = await _api.textToDish(_voiceController.text.trim());
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
      });
      _showSnackBar(
        result,
        backgroundColor: const Color(0xFF163928),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
      });
      _showSnackBar('No se pudo consultar IA: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F0F10),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFE34B4B),
        secondary: Color(0xFFFFB27A),
        surface: Color(0xFF1B1B1D),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1B1B1D),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerColor: Colors.white10,
      textTheme: Typography.whiteMountainView,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF202022),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(color: Colors.white38),
        labelStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE34B4B)),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFF232326),
        selectedColor: Color(0xFFE34B4B),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      home: Stack(
        children: <Widget>[
          _firebaseUser == null
              ? LoginPage(
                  onLogin: _login,
                  isBusy: _isBusy,
                )
              : UserShell(
                  user: _firebaseUser!,
                  backendOnline: _backendOnline,
                  restaurants: _restaurants,
                  selectedRestaurant: _selectedRestaurant,
                  categories: _categories,
                  selectedCategory: _selectedCategory,
                  dishes: _visibleDishes,
                  cartEntries: _cartEntries,
                  cartCount: _cartCount,
                  cartTotal: _cartTotal,
                  trackingOrders: _trackingOrders,
                  historyOrders: _historyOrders,
                  manualQrController: _manualQrController,
                  voiceController: _voiceController,
                  quantityForDish: _quantityForDish,
                  onSelectRestaurant: _selectRestaurant,
                  onSelectCategory: _selectCategory,
                  onAddToCart: _addToCart,
                  onRemoveFromCart: _removeFromCart,
                  onOpenScanner: _openScanner,
                  onSubmitManualQr: _submitManualQr,
                  onAnalyzeVoiceText: _analyzeVoiceText,
                  onPlaceOrder: _placeOrder,
                  onRateOrder: _rateOrder,
                  onRefresh: _bootstrap,
                  onLogout: _logout,
                ),
          if (_isBusy) const BusyOverlay(),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLogin,
    required this.isBusy,
  });

  final Future<void> Function(String email, String password) onLogin;
  final bool isBusy;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF181819),
              Color(0xFF111112),
              Color(0xFF181112),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool isWide = constraints.maxWidth > 880;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: IntrinsicHeight(
                    child: isWide
                        ? Row(
                            children: <Widget>[
                              const Expanded(child: LoginIntroPanel()),
                              const SizedBox(width: 32),
                              Expanded(
                                child: LoginFormCard(
                                  emailController: _emailController,
                                  passwordController: _passwordController,
                                  isBusy: widget.isBusy,
                                  onLogin: () => widget.onLogin(
                                    _emailController.text,
                                    _passwordController.text,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              const LoginIntroPanel(),
                              const SizedBox(height: 28),
                              LoginFormCard(
                                emailController: _emailController,
                                passwordController: _passwordController,
                                isBusy: widget.isBusy,
                                onLogin: () => widget.onLogin(
                                  _emailController.text,
                                  _passwordController.text,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class UserShell extends StatefulWidget {
  const UserShell({
    super.key,
    required this.user,
    required this.backendOnline,
    required this.restaurants,
    required this.selectedRestaurant,
    required this.categories,
    required this.selectedCategory,
    required this.dishes,
    required this.cartEntries,
    required this.cartCount,
    required this.cartTotal,
    required this.trackingOrders,
    required this.historyOrders,
    required this.manualQrController,
    required this.voiceController,
    required this.quantityForDish,
    required this.onSelectRestaurant,
    required this.onSelectCategory,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.onOpenScanner,
    required this.onSubmitManualQr,
    required this.onAnalyzeVoiceText,
    required this.onPlaceOrder,
    required this.onRateOrder,
    required this.onRefresh,
    required this.onLogout,
  });

  final User user;
  final bool backendOnline;
  final List<RestaurantSummary> restaurants;
  final RestaurantSummary? selectedRestaurant;
  final List<String> categories;
  final String selectedCategory;
  final List<Dish> dishes;
  final List<CartEntry> cartEntries;
  final int cartCount;
  final double cartTotal;
  final List<OrderRecord> trackingOrders;
  final List<OrderRecord> historyOrders;
  final TextEditingController manualQrController;
  final TextEditingController voiceController;
  final int Function(String dishId) quantityForDish;
  final ValueChanged<String> onSelectRestaurant;
  final ValueChanged<String> onSelectCategory;
  final ValueChanged<Dish> onAddToCart;
  final ValueChanged<Dish> onRemoveFromCart;
  final VoidCallback onOpenScanner;
  final VoidCallback onSubmitManualQr;
  final Future<void> Function() onAnalyzeVoiceText;
  final Future<void> Function() onPlaceOrder;
  final Future<void> Function(OrderRecord order) onRateOrder;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      MenuPage(
        user: widget.user,
        backendOnline: widget.backendOnline,
        restaurants: widget.restaurants,
        selectedRestaurant: widget.selectedRestaurant,
        categories: widget.categories,
        selectedCategory: widget.selectedCategory,
        dishes: widget.dishes,
        cartEntries: widget.cartEntries,
        cartCount: widget.cartCount,
        cartTotal: widget.cartTotal,
        manualQrController: widget.manualQrController,
        voiceController: widget.voiceController,
        quantityForDish: widget.quantityForDish,
        onSelectRestaurant: widget.onSelectRestaurant,
        onSelectCategory: widget.onSelectCategory,
        onAddToCart: widget.onAddToCart,
        onRemoveFromCart: widget.onRemoveFromCart,
        onOpenScanner: widget.onOpenScanner,
        onSubmitManualQr: widget.onSubmitManualQr,
        onAnalyzeVoiceText: widget.onAnalyzeVoiceText,
        onPlaceOrder: widget.onPlaceOrder,
        onRefresh: widget.onRefresh,
      ),
      TrackingPage(orders: widget.trackingOrders),
      HistoryPage(
        orders: widget.historyOrders,
        onRateOrder: widget.onRateOrder,
      ),
      ProfilePage(
        user: widget.user,
        backendOnline: widget.backendOnline,
        ordersCount: widget.trackingOrders.length,
        historyCount: widget.historyOrders.length,
        onRefresh: widget.onRefresh,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tabIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 76,
        backgroundColor: const Color(0xFF161618),
        indicatorColor: const Color(0x33E34B4B),
        selectedIndex: _tabIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _tabIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Seguimiento',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class MenuPage extends StatelessWidget {
  const MenuPage({
    super.key,
    required this.user,
    required this.backendOnline,
    required this.restaurants,
    required this.selectedRestaurant,
    required this.categories,
    required this.selectedCategory,
    required this.dishes,
    required this.cartEntries,
    required this.cartCount,
    required this.cartTotal,
    required this.manualQrController,
    required this.voiceController,
    required this.quantityForDish,
    required this.onSelectRestaurant,
    required this.onSelectCategory,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.onOpenScanner,
    required this.onSubmitManualQr,
    required this.onAnalyzeVoiceText,
    required this.onPlaceOrder,
    required this.onRefresh,
  });

  final User user;
  final bool backendOnline;
  final List<RestaurantSummary> restaurants;
  final RestaurantSummary? selectedRestaurant;
  final List<String> categories;
  final String selectedCategory;
  final List<Dish> dishes;
  final List<CartEntry> cartEntries;
  final int cartCount;
  final double cartTotal;
  final TextEditingController manualQrController;
  final TextEditingController voiceController;
  final int Function(String dishId) quantityForDish;
  final ValueChanged<String> onSelectRestaurant;
  final ValueChanged<String> onSelectCategory;
  final ValueChanged<Dish> onAddToCart;
  final ValueChanged<Dish> onRemoveFromCart;
  final VoidCallback onOpenScanner;
  final VoidCallback onSubmitManualQr;
  final Future<void> Function() onAnalyzeVoiceText;
  final Future<void> Function() onPlaceOrder;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 1000;
        final int columns = constraints.maxWidth >= 1180 ? 2 : 1;

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Hola, ${user.displayName?.split(' ').first ?? 'Cliente'}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pide en CruChef',
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    _RoundIconButton(
                      icon: Icons.qr_code_scanner,
                      onTap: onOpenScanner,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                StatusBanner(isOnline: backendOnline),
                const SizedBox(height: 16),
                RestaurantHero(
                  selectedRestaurant: selectedRestaurant,
                  cartCount: cartCount,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: manualQrController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Codigo QR del restaurante',
                    prefixIcon: const Icon(Icons.qr_code_2),
                    suffixIcon: IconButton(
                      onPressed: onSubmitManualQr,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: voiceController,
                  decoration: InputDecoration(
                    hintText: 'Describe un plato con IA',
                    prefixIcon: const Icon(Icons.mic_none),
                    suffixIcon: IconButton(
                      onPressed: () {
                        onAnalyzeVoiceText();
                      },
                      icon: const Icon(Icons.auto_awesome),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: restaurants.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final RestaurantSummary restaurant = restaurants[index];
                      final bool selected =
                          restaurant.name == selectedRestaurant?.name;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(restaurant.name),
                        onSelected: (_) => onSelectRestaurant(restaurant.name),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (BuildContext context, int index) {
                      final String category = categories[index];
                      return CategoryChip(
                        category: category,
                        selected: category == selectedCategory,
                        onTap: () => onSelectCategory(category),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        flex: 7,
                        child: DishGrid(
                          dishes: dishes,
                          columns: columns,
                          quantityForDish: quantityForDish,
                          onAddToCart: onAddToCart,
                          onRemoveFromCart: onRemoveFromCart,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 4,
                        child: CartPanel(
                          entries: cartEntries,
                          total: cartTotal,
                          onPlaceOrder: onPlaceOrder,
                        ),
                      ),
                    ],
                  )
                else ...<Widget>[
                  DishGrid(
                    dishes: dishes,
                    columns: 1,
                    quantityForDish: quantityForDish,
                    onAddToCart: onAddToCart,
                    onRemoveFromCart: onRemoveFromCart,
                  ),
                  const SizedBox(height: 18),
                  CartPanel(
                    entries: cartEntries,
                    total: cartTotal,
                    onPlaceOrder: onPlaceOrder,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class TrackingPage extends StatelessWidget {
  const TrackingPage({super.key, required this.orders});

  final List<OrderRecord> orders;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      children: <Widget>[
        const Text(
          'Seguimiento',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 18),
        if (orders.isEmpty)
          const EmptyStateCard(
            icon: Icons.receipt_long_outlined,
            title: 'No hay compras en curso',
            subtitle: 'Cuando confirmes un pedido lo veras aqui.',
          )
        else
          ...orders.map(
            (OrderRecord order) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TrackingOrderCard(order: order),
            ),
          ),
      ],
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({
    super.key,
    required this.orders,
    required this.onRateOrder,
  });

  final List<OrderRecord> orders;
  final Future<void> Function(OrderRecord order) onRateOrder;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      children: <Widget>[
        const Text(
          'Historial',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 18),
        if (orders.isEmpty)
          const EmptyStateCard(
            icon: Icons.history_outlined,
            title: 'Sin historial',
            subtitle: 'Tus ordenes entregadas y canceladas apareceran aqui.',
          )
        else
          ...orders.map(
            (OrderRecord order) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: HistoryOrderCard(
                order: order,
                onRate: order.canRate ? () => onRateOrder(order) : null,
              ),
            ),
          ),
      ],
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.user,
    required this.backendOnline,
    required this.ordersCount,
    required this.historyCount,
    required this.onRefresh,
    required this.onLogout,
  });

  final User user;
  final bool backendOnline;
  final int ordersCount;
  final int historyCount;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      children: <Widget>[
        Row(
          children: <Widget>[
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0x33E34B4B),
              child: Text(
                buildInitials(user.displayName ?? user.email ?? 'CC'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    user.displayName ?? 'Cliente CruChef',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(user.email ?? '', style: const TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(child: ProfileMetric(label: 'Activas', value: '$ordersCount')),
            const SizedBox(width: 12),
            Expanded(child: ProfileMetric(label: 'Historial', value: '$historyCount')),
            const SizedBox(width: 12),
            Expanded(
              child: ProfileMetric(
                label: 'API',
                value: backendOnline ? 'OK' : 'OFF',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ProfileInfoCard(
          title: 'Cuenta',
          rows: <ProfileRowData>[
            ProfileRowData(label: 'UID', value: user.uid),
            ProfileRowData(label: 'Correo', value: user.email ?? ''),
            ProfileRowData(label: 'Metodo', value: 'Firebase Auth'),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () {
                    onRefresh();
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: const Color(0xFF232326),
                  ),
                  icon: const Icon(Icons.sync),
                  label: const Text('Sincronizar'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    onLogout();
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: const Color(0xFFE34B4B),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesion'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key, required this.onDetected});

  final ValueChanged<String> onDetected;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;
  bool _hasPermission = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCode(String? value) {
    if (_handled || value == null || value.trim().isEmpty) {
      return;
    }
    _handled = true;
    widget.onDetected(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Escanear QR'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: _controller,
            errorBuilder: (BuildContext context, MobileScannerException error) {
              _hasPermission = false;
              return const ScannerPermissionCard();
            },
            onDetect: (BarcodeCapture capture) {
              final String? value =
                  capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
              _handleCode(value);
            },
          ),
          if (_hasPermission)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'La camara pedira permiso si aun no esta habilitada.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.transparent, Colors.black87],
                ),
              ),
              child: const Text(
                'Apunta al QR del restaurante',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginIntroPanel extends StatelessWidget {
  const LoginIntroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: const <Widget>[
          Text(
            'BIENVENIDO',
            style: TextStyle(
              color: Color(0xFFE34B4B),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Inicia sesion',
            style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, height: 0.95),
          ),
          SizedBox(height: 18),
          FeatureTile(
            icon: Icons.qr_code_scanner,
            text: 'Escanea restaurantes, revisa platos y pide desde el celular.',
          ),
          SizedBox(height: 14),
          FeatureTile(
            icon: Icons.receipt_long,
            text: 'Sigue tus ordenes y califica las entregadas.',
          ),
        ],
      ),
    );
  }
}

class LoginFormCard extends StatelessWidget {
  const LoginFormCard({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.isBusy,
    required this.onLogin,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isBusy;
  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: const <Widget>[
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Color(0x33E34B4B),
                      child: Icon(Icons.restaurant, color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'CruChef',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Acceso de clientes',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Acceso',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo electronico',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contrasena',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: isBusy ? null : () => onLogin(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE34B4B),
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: Text(isBusy ? 'Conectando...' : 'Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOnline ? const Color(0xFF16251D) : const Color(0xFF321718),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: isOnline ? const Color(0xFF6BCB8B) : const Color(0xFFE34B4B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isOnline ? 'Backend conectado' : 'Backend sin respuesta',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class RestaurantHero extends StatelessWidget {
  const RestaurantHero({
    super.key,
    required this.selectedRestaurant,
    required this.cartCount,
  });

  final RestaurantSummary? selectedRestaurant;
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF1F1D1E), Color(0xFF24191A)],
        ),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      selectedRestaurant?.name ?? 'Sin restaurantes',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedRestaurant == null
                          ? 'No hay platos cargados.'
                          : '${selectedRestaurant!.dishes.length} platos disponibles',
                      style: const TextStyle(color: Colors.white60, height: 1.4),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: null,
                icon: const Icon(Icons.shopping_bag_outlined),
                label: Text('$cartCount'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              InfoPill(
                icon: Icons.restaurant_outlined,
                label: selectedRestaurant?.name ?? 'Sin datos',
              ),
              InfoPill(
                icon: Icons.qr_code_2,
                label: selectedRestaurant?.qrCode ?? 'QR',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final String category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE34B4B) : const Color(0xFF232326),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white10,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(iconForCategory(category), color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(
              categoryLabel(category),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class DishGrid extends StatelessWidget {
  const DishGrid({
    super.key,
    required this.dishes,
    required this.columns,
    required this.quantityForDish,
    required this.onAddToCart,
    required this.onRemoveFromCart,
  });

  final List<Dish> dishes;
  final int columns;
  final int Function(String dishId) quantityForDish;
  final ValueChanged<Dish> onAddToCart;
  final ValueChanged<Dish> onRemoveFromCart;

  @override
  Widget build(BuildContext context) {
    if (dishes.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.search_off,
        title: 'No hay platos en esta categoria',
        subtitle: 'Prueba con otro restaurante o categoria.',
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dishes.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: 272,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemBuilder: (BuildContext context, int index) {
        final Dish dish = dishes[index];
        return DishCard(
          dish: dish,
          quantity: quantityForDish(dish.id),
          onAdd: () => onAddToCart(dish),
          onRemove: () => onRemoveFromCart(dish),
        );
      },
    );
  }
}

class DishCard extends StatelessWidget {
  const DishCard({
    super.key,
    required this.dish,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final Dish dish;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF28282B),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    iconForCategory(dish.categoryId),
                    size: 28,
                    color: const Color(0xFFFFB27A),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        dish.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dish.restaurantName,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                TagChip(label: categoryLabel(dish.categoryId)),
                TagChip(label: 'Rating ${dish.rating.toStringAsFixed(1)}'),
              ],
            ),
            const Spacer(),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        formatPrice(dish.price),
                        style: const TextStyle(
                          color: Color(0xFFFFC56F),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dish.imageKey,
                        style: const TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                ),
                if (quantity == 0)
                  FilledButton(
                    onPressed: onAdd,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE34B4B),
                    ),
                    child: const Text('Pedir'),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF262629),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          onPressed: onRemove,
                          icon: const Icon(Icons.remove),
                        ),
                        Text(
                          '$quantity',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        IconButton(
                          onPressed: onAdd,
                          icon: const Icon(Icons.add),
                        ),
                      ],
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

class CartPanel extends StatelessWidget {
  const CartPanel({
    super.key,
    required this.entries,
    required this.total,
    required this.onPlaceOrder,
  });

  final List<CartEntry> entries;
  final double total;
  final Future<void> Function() onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.shopping_cart_outlined,
        title: 'Carrito vacio',
        subtitle: 'Agrega platos para crear tu pedido.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Tu pedido',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            ...entries.map(
              (CartEntry entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${entry.quantity} x ${entry.dish.name}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    Text(
                      formatPrice(entry.total),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 28),
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  formatPrice(total),
                  style: const TextStyle(
                    color: Color(0xFFFFC56F),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => onPlaceOrder(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE34B4B),
                minimumSize: const Size.fromHeight(54),
              ),
              child: const Text('Confirmar pedido'),
            ),
          ],
        ),
      ),
    );
  }
}

class TrackingOrderCard extends StatelessWidget {
  const TrackingOrderCard({super.key, required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        order.restaurantName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.id} - ${formatOrderTime(order.createdAt)}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                StatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 16),
            OrderSteps(status: order.status),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${order.quantity} x ${order.dishName}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                Text(
                  formatPrice(order.total),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    order.statusLabel,
                    style: const TextStyle(color: Colors.white60),
                  ),
                ),
                Text(
                  order.restaurantId,
                  style: const TextStyle(color: Colors.white38),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryOrderCard extends StatelessWidget {
  const HistoryOrderCard({
    super.key,
    required this.order,
    required this.onRate,
  });

  final OrderRecord order;
  final VoidCallback? onRate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    order.restaurantName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                StatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${order.id} - ${formatOrderTime(order.createdAt)}',
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(child: Text('${order.quantity} x ${order.dishName}')),
                Text(formatPrice(order.total)),
              ],
            ),
            const Divider(height: 26),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    order.reviewText.isEmpty
                        ? order.statusLabel
                        : order.reviewText,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
                if (order.rating != null)
                  Text(
                    '${order.rating!.toStringAsFixed(0)}/5',
                    style: const TextStyle(
                      color: Color(0xFFFFC56F),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
            if (onRate != null) ...<Widget>[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onRate,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE34B4B),
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Calificar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProfileInfoCard extends StatelessWidget {
  const ProfileInfoCard({
    super.key,
    required this.title,
    required this.rows,
  });

  final String title;
  final List<ProfileRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            ...rows.map(
              (ProfileRowData row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 88,
                      child: Text(
                        row.label,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileMetric extends StatelessWidget {
  const ProfileMetric({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final Color background = switch (status) {
      OrderStatus.pending => const Color(0x33E39E4B),
      OrderStatus.accepted => const Color(0x334B9AE3),
      OrderStatus.preparing => const Color(0x33E3C64B),
      OrderStatus.ready => const Color(0x334BCB76),
      OrderStatus.delivered => const Color(0x334BCB76),
      OrderStatus.cancelled => const Color(0x33E34B4B),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class OrderSteps extends StatelessWidget {
  const OrderSteps({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final List<OrderStatus> steps = <OrderStatus>[
      OrderStatus.pending,
      OrderStatus.accepted,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.delivered,
    ];
    final int activeIndex = steps.indexOf(status);

    return Row(
      children: List<Widget>.generate(steps.length, (int index) {
        final bool active = activeIndex >= index;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == steps.length - 1 ? 0 : 8),
            child: Column(
              children: <Widget>[
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFE34B4B) : Colors.white10,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  steps[index].label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: active ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: <Widget>[
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0x22E34B4B),
              child: Icon(icon, color: const Color(0xFFE34B4B)),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class ScannerPermissionCard extends StatelessWidget {
  const ScannerPermissionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const <Widget>[
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0x22E34B4B),
                  child: Icon(Icons.camera_alt_outlined, color: Color(0xFFE34B4B)),
                ),
                SizedBox(height: 14),
                Text(
                  'Permiso de camara requerido',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 8),
                Text(
                  'Acepta el permiso del sistema para leer el QR del restaurante.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: const Color(0xFFE34B4B)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF1D1D20),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _RoundIconButton extends RoundIconButton {
  const _RoundIconButton({
    required super.icon,
    required super.onTap,
  });
}

class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2021),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: const Color(0xFFFFB27A)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF262629),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.white70),
      ),
    );
  }
}

class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key, required this.order});

  final OrderRecord order;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double _rating = 5;
  final TextEditingController _reviewController = TextEditingController();

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1D),
      title: const Text('Calificar pedido'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Slider(
            min: 1,
            max: 5,
            divisions: 4,
            value: _rating,
            label: _rating.toStringAsFixed(0),
            onChanged: (double value) {
              setState(() {
                _rating = value;
              });
            },
          ),
          TextField(
            controller: _reviewController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comentario',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              RatingResult(
                rating: _rating.toInt(),
                reviewText: _reviewController.text.trim(),
              ),
            );
          },
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}

class BusyOverlay extends StatelessWidget {
  const BusyOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: const Color(0x66000000),
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFFE34B4B)),
          ),
        ),
      ),
    );
  }
}

class RatingResult {
  const RatingResult({
    required this.rating,
    required this.reviewText,
  });

  final int rating;
  final String reviewText;
}

class ProfileRowData {
  const ProfileRowData({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class Dish {
  const Dish({
    required this.id,
    required this.ownerUid,
    required this.restaurantId,
    required this.restaurantName,
    required this.name,
    required this.price,
    required this.rating,
    required this.categoryId,
    required this.imageKey,
    required this.imageUrl,
  });

  final String id;
  final String ownerUid;
  final String restaurantId;
  final String restaurantName;
  final String name;
  final double price;
  final double rating;
  final String categoryId;
  final String imageKey;
  final String imageUrl;

  factory Dish.fromJson(Map<String, dynamic> json) {
    final String restaurantName = _readString(
      json,
      <String>['restaurant', 'restaurantName'],
      fallback: 'CruChef',
    );

    return Dish(
      id: _readString(json, <String>['id', '_id'], fallback: ''),
      ownerUid: _readString(
        json,
        <String>['ownerUid', 'owner_uid'],
        fallback: '',
      ),
      restaurantId: _readString(
        json,
        <String>['restaurantId', 'restaurant_id'],
        fallback: slugify(restaurantName),
      ),
      restaurantName: restaurantName,
      name: _readString(json, <String>['name'], fallback: 'Plato'),
      price: _readDouble(json, <String>['price']),
      rating: _readDouble(json, <String>['rating'], fallback: 0),
      categoryId: _readString(
        json,
        <String>['categoryId', 'category_id'],
        fallback: 'general',
      ),
      imageKey: _readString(json, <String>['imageKey'], fallback: ''),
      imageUrl: _readString(json, <String>['imageUrl'], fallback: ''),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'restaurant': restaurantName,
      'price': price,
      'rating': rating,
      'categoryId': categoryId,
      'imageKey': imageKey,
      'imageUrl': imageUrl,
    };
  }
}

class RestaurantSummary {
  const RestaurantSummary({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.qrCode,
    required this.dishes,
  });

  final String id;
  final String ownerUid;
  final String name;
  final String qrCode;
  final List<Dish> dishes;
}

class CartEntry {
  const CartEntry({
    required this.dish,
    required this.quantity,
  });

  final Dish dish;
  final int quantity;

  double get total => dish.price * quantity;
}

enum OrderStatus {
  pending,
  accepted,
  preparing,
  ready,
  delivered,
  cancelled;

  String get label => switch (this) {
        OrderStatus.pending => 'Pendiente',
        OrderStatus.accepted => 'Aceptado',
        OrderStatus.preparing => 'Preparando',
        OrderStatus.ready => 'Listo',
        OrderStatus.delivered => 'Entregado',
        OrderStatus.cancelled => 'Cancelado',
      };
}

class OrderRecord {
  const OrderRecord({
    required this.id,
    required this.ownerUid,
    required this.restaurantId,
    required this.restaurantName,
    required this.customerUid,
    required this.customerEmail,
    required this.customerName,
    required this.dishId,
    required this.dishName,
    required this.dishImageUrl,
    required this.categoryId,
    required this.quantity,
    required this.unitPrice,
    required this.status,
    required this.createdAt,
    required this.notes,
    required this.rating,
    required this.reviewText,
  });

  final String id;
  final String ownerUid;
  final String restaurantId;
  final String restaurantName;
  final String customerUid;
  final String customerEmail;
  final String customerName;
  final String dishId;
  final String dishName;
  final String dishImageUrl;
  final String categoryId;
  final int quantity;
  final double unitPrice;
  final OrderStatus status;
  final DateTime createdAt;
  final String notes;
  final double? rating;
  final String reviewText;

  double get total => unitPrice * quantity;

  String get statusLabel => status.label;

  bool get canRate => status == OrderStatus.delivered && rating == null;

  factory OrderRecord.fromJson(Map<String, dynamic> json) {
    return OrderRecord(
      id: _readString(json, <String>['id', '_id'], fallback: ''),
      ownerUid: _readString(json, <String>['ownerUid'], fallback: ''),
      restaurantId: _readString(json, <String>['restaurantId'], fallback: ''),
      restaurantName: _readString(
        json,
        <String>['restaurantName'],
        fallback: 'CruChef',
      ),
      customerUid: _readString(json, <String>['customerUid'], fallback: ''),
      customerEmail: _readString(json, <String>['customerEmail'], fallback: ''),
      customerName: _readString(json, <String>['customerName'], fallback: ''),
      dishId: _readString(json, <String>['dishId'], fallback: ''),
      dishName: _readString(json, <String>['dishName'], fallback: 'Plato'),
      dishImageUrl: _readString(json, <String>['dishImageUrl'], fallback: ''),
      categoryId: _readString(json, <String>['categoryId'], fallback: 'general'),
      quantity: _readInt(json, <String>['quantity'], fallback: 1),
      unitPrice: _readDouble(json, <String>['unitPrice'], fallback: 0),
      status: parseOrderStatus(_readString(json, <String>['status'], fallback: 'pending')),
      createdAt: _readDateTime(json, <String>['createdAt', 'updatedAt']),
      notes: _readString(json, <String>['notes'], fallback: ''),
      rating: _readNullableDouble(json, <String>['rating']),
      reviewText: _readString(json, <String>['reviewText'], fallback: ''),
    );
  }
}

class OrderCreatePayload {
  const OrderCreatePayload({
    required this.ownerUid,
    required this.restaurantId,
    required this.restaurantName,
    required this.customerUid,
    required this.customerEmail,
    required this.customerName,
    required this.dishId,
    required this.dishName,
    required this.dishImageUrl,
    required this.categoryId,
    required this.quantity,
    required this.unitPrice,
    required this.notes,
  });

  final String ownerUid;
  final String restaurantId;
  final String restaurantName;
  final String customerUid;
  final String customerEmail;
  final String customerName;
  final String dishId;
  final String dishName;
  final String dishImageUrl;
  final String categoryId;
  final int quantity;
  final double unitPrice;
  final String notes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ownerUid': ownerUid,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'customerUid': customerUid,
      'customerEmail': customerEmail,
      'customerName': customerName,
      'dishId': dishId,
      'dishName': dishName,
      'dishImageUrl': dishImageUrl,
      'categoryId': categoryId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'notes': notes,
    };
  }
}

class CruchefApi {
  CruchefApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _apiOverride = String.fromEnvironment(
    'CRUCHEF_API_BASE_URL',
    defaultValue: '',
  );
  static const String _voiceOverride = String.fromEnvironment(
    'CRUCHEF_VOICE_BASE_URL',
    defaultValue: '',
  );

  String get apiBaseUrl {
    if (_apiOverride.isNotEmpty) {
      return _apiOverride;
    }
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000/api';
      default:
        return 'http://localhost:3000/api';
    }
  }

  String get voiceBaseUrl {
    if (_voiceOverride.isNotEmpty) {
      return _voiceOverride;
    }
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      default:
        return 'http://localhost:8000';
    }
  }

  Future<bool> health() async {
    final http.Response response =
        await _client.get(Uri.parse('$apiBaseUrl/health'));
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Future<List<Dish>> getDishes() async {
    final http.Response response =
        await _client.get(Uri.parse('$apiBaseUrl/dishes'));
    _ensureSuccess(response, 'No se pudieron cargar los platos.');
    final List<dynamic> data = _decodeList(response.body);
    return data
        .map((dynamic item) => Dish.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<Dish> createDish(Dish dish) async {
    final http.Response response = await _client.post(
      Uri.parse('$apiBaseUrl/dishes'),
      headers: _jsonHeaders,
      body: jsonEncode(dish.toJson()),
    );
    _ensureSuccess(response, 'No se pudo crear el plato.');
    return Dish.fromJson(_decodeMap(response.body));
  }

  Future<Dish> updateDish(Dish dish) async {
    final http.Response response = await _client.put(
      Uri.parse('$apiBaseUrl/dishes/${dish.id}'),
      headers: _jsonHeaders,
      body: jsonEncode(dish.toJson()),
    );
    _ensureSuccess(response, 'No se pudo actualizar el plato.');
    return Dish.fromJson(_decodeMap(response.body));
  }

  Future<void> deleteDish(String id) async {
    final http.Response response =
        await _client.delete(Uri.parse('$apiBaseUrl/dishes/$id'));
    _ensureSuccess(response, 'No se pudo eliminar el plato.');
  }

  Future<List<OrderRecord>> getOrders({
    String? ownerUid,
    String? customerUid,
    String? status,
  }) async {
    final Map<String, String> query = <String, String>{};
    if (ownerUid != null && ownerUid.isNotEmpty) {
      query['ownerUid'] = ownerUid;
    }
    if (customerUid != null && customerUid.isNotEmpty) {
      query['customerUid'] = customerUid;
    }
    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }

    final Uri uri = Uri.parse('$apiBaseUrl/orders').replace(queryParameters: query);
    final http.Response response = await _client.get(uri);
    _ensureSuccess(response, 'No se pudieron cargar las ordenes.');
    final List<dynamic> data = _decodeList(response.body);
    return data
        .map((dynamic item) => OrderRecord.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<OrderRecord> createOrder(OrderCreatePayload payload) async {
    final http.Response response = await _client.post(
      Uri.parse('$apiBaseUrl/orders'),
      headers: _jsonHeaders,
      body: jsonEncode(payload.toJson()),
    );
    _ensureSuccess(response, 'No se pudo crear la orden.');
    return OrderRecord.fromJson(_decodeMap(response.body));
  }

  Future<OrderRecord> updateOrderStatus({
    required String id,
    required String status,
  }) async {
    final http.Response response = await _client.patch(
      Uri.parse('$apiBaseUrl/orders/$id/status'),
      headers: _jsonHeaders,
      body: jsonEncode(<String, dynamic>{'status': status}),
    );
    _ensureSuccess(response, 'No se pudo actualizar el estado.');
    return OrderRecord.fromJson(_decodeMap(response.body));
  }

  Future<OrderRecord> rateOrder({
    required String id,
    required int rating,
    required String reviewText,
  }) async {
    final http.Response response = await _client.patch(
      Uri.parse('$apiBaseUrl/orders/$id/rating'),
      headers: _jsonHeaders,
      body: jsonEncode(
        <String, dynamic>{
          'rating': rating,
          'reviewText': reviewText,
        },
      ),
    );
    _ensureSuccess(response, 'No se pudo enviar la calificacion.');
    return OrderRecord.fromJson(_decodeMap(response.body));
  }

  Future<String> textToDish(String text) async {
    final http.Response response = await _client.post(
      Uri.parse('$voiceBaseUrl/text-to-dish'),
      headers: _jsonHeaders,
      body: jsonEncode(<String, dynamic>{'text': text}),
    );
    _ensureSuccess(response, 'No se pudo consultar el servicio de IA.');
    final Map<String, dynamic> data = _decodeMap(response.body);
    return _readString(
      data,
      <String>['dishName', 'text', 'result', 'message'],
      fallback: 'Consulta procesada.',
    );
  }

  void _ensureSuccess(http.Response response, String fallbackMessage) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw Exception('$fallbackMessage (${response.statusCode})');
  }
}

class CruchefFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyDyURnZJ6DEFHW04R8lJvDIY9drPK8is6c',
      authDomain: 'cruchefangular.firebaseapp.com',
      projectId: 'cruchefangular',
      storageBucket: 'cruchefangular.firebasestorage.app',
      messagingSenderId: '451514637467',
      appId: '1:451514637467:web:a2393ca908935a637afa3e',
    );
  }
}

const Map<String, String> _jsonHeaders = <String, String>{
  'Content-Type': 'application/json',
};

Map<String, dynamic> _decodeMap(String body) {
  if (body.trim().isEmpty) {
    return <String, dynamic>{};
  }
  return _asMap(jsonDecode(body));
}

List<dynamic> _decodeList(String body) {
  if (body.trim().isEmpty) {
    return <dynamic>[];
  }
  final dynamic decoded = jsonDecode(body);
  if (decoded is List) {
    return List<dynamic>.from(decoded);
  }
  if (decoded is Map<String, dynamic>) {
    for (final String key in <String>['data', 'items', 'results']) {
      if (decoded[key] is List) {
        return List<dynamic>.from(decoded[key] as List);
      }
    }
  }
  return <dynamic>[];
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic item) => MapEntry(key.toString(), item),
    );
  }
  return <String, dynamic>{};
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final String key in keys) {
    final dynamic value = json[key];
    if (value == null) {
      continue;
    }
    final String parsed = value.toString().trim();
    if (parsed.isNotEmpty && parsed != 'null') {
      return parsed;
    }
  }
  return fallback;
}

double _readDouble(
  Map<String, dynamic> json,
  List<String> keys, {
  double fallback = 0,
}) {
  for (final String key in keys) {
    final dynamic value = json[key];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final double? parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return fallback;
}

double? _readNullableDouble(Map<String, dynamic> json, List<String> keys) {
  for (final String key in keys) {
    final dynamic value = json[key];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final double? parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return null;
}

int _readInt(
  Map<String, dynamic> json,
  List<String> keys, {
  int fallback = 0,
}) {
  for (final String key in keys) {
    final dynamic value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final int? parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return fallback;
}

DateTime _readDateTime(Map<String, dynamic> json, List<String> keys) {
  for (final String key in keys) {
    final dynamic value = json[key];
    if (value is String) {
      final DateTime? parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed.toLocal();
      }
    }
  }
  return DateTime.now();
}

OrderStatus parseOrderStatus(String value) {
  switch (value.toLowerCase()) {
    case 'accepted':
      return OrderStatus.accepted;
    case 'preparing':
      return OrderStatus.preparing;
    case 'ready':
      return OrderStatus.ready;
    case 'delivered':
      return OrderStatus.delivered;
    case 'cancelled':
      return OrderStatus.cancelled;
    default:
      return OrderStatus.pending;
  }
}

IconData iconForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'burgers':
      return Icons.lunch_dining;
    case 'pizza':
    case 'pizzas':
      return Icons.local_pizza;
    case 'tacos':
      return Icons.local_dining;
    case 'sushi':
      return Icons.rice_bowl;
    case 'pastas':
      return Icons.dinner_dining;
    case 'postres':
      return Icons.cake;
    case 'bebidas':
      return Icons.local_drink;
    default:
      return Icons.fastfood;
  }
}

String categoryLabel(String category) {
  if (category.toLowerCase() == 'todas') {
    return 'Todas';
  }
  if (category.isEmpty) {
    return 'General';
  }
  return category[0].toUpperCase() + category.substring(1);
}

String formatPrice(double value) {
  final String fixed = value.toStringAsFixed(0);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < fixed.length; i++) {
    final int indexFromEnd = fixed.length - i;
    buffer.write(fixed[i]);
    if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
      buffer.write('.');
    }
  }
  return '\$$buffer';
}

String formatOrderTime(DateTime dateTime) {
  final Duration diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 60) {
    return 'Hace ${diff.inMinutes} min';
  }
  if (diff.inHours < 24) {
    return 'Hace ${diff.inHours} h';
  }
  return 'Hace ${diff.inDays} dias';
}

String slugify(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

String buildRestaurantQr(String restaurantName) {
  return 'CRU-${slugify(restaurantName).replaceAll('-', '_').toUpperCase()}';
}

String normalizeRestaurantValue(String value) {
  return value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

String buildInitials(String value) {
  final List<String> parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) {
    return 'CC';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}
