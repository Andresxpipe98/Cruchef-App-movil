import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'ui/cruchef_design.dart';

part 'screens/cruchef_screens.dart';
part 'widgets/cruchef_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const CruchefApp());
}

class CruchefApp extends StatefulWidget {
  const CruchefApp({super.key});

  @override
  State<CruchefApp> createState() => _CruchefAppState();
}

class _CruchefAppState extends State<CruchefApp> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CruchefRepository _repository = CruchefRepository();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final Map<String, int> _cart = <String, int>{};
  final TextEditingController _manualQrController = TextEditingController();
  final TextEditingController _voiceController = TextEditingController();
  final TextEditingController _orderNotesController = TextEditingController();
  final TextEditingController _paymentNameController = TextEditingController();
  final TextEditingController _paymentDocumentController =
      TextEditingController();
  final TextEditingController _paymentPhoneController = TextEditingController();
  final TextEditingController _paymentReferenceController =
      TextEditingController();

  bool _isBusy = false;
  bool _firebaseOnline = true;
  bool _draftRestored = false;
  String? _loginError;
  List<RestaurantSummary> _restaurants = <RestaurantSummary>[];
  List<Dish> _dishes = <Dish>[];
  List<OrderRecord> _orders = <OrderRecord>[];
  String? _selectedRestaurantKey;
  String _restaurantSearchQuery = '';
  String _selectedCategory = 'Todas';
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  String _profilePhone = '';
  String _profilePhotoUrl = '';

  @override
  void dispose() {
    _manualQrController.dispose();
    _voiceController.dispose();
    _orderNotesController.dispose();
    _paymentNameController.dispose();
    _paymentDocumentController.dispose();
    _paymentPhoneController.dispose();
    _paymentReferenceController.dispose();
    super.dispose();
  }

  User? get _firebaseUser => _auth.currentUser;

  List<RestaurantSummary> _restaurantsFromDishes(List<Dish> dishes) {
    final Map<String, List<Dish>> grouped = <String, List<Dish>>{};
    for (final Dish dish in dishes) {
      final String key = '${dish.ownerUid}:${dish.restaurantId}';
      grouped.putIfAbsent(key, () => <Dish>[]).add(dish);
    }

    return grouped.entries
        .map((MapEntry<String, List<Dish>> entry) {
          final Dish firstDish = entry.value.first;
          return RestaurantSummary(
            id: firstDish.restaurantId,
            ownerUid: firstDish.ownerUid,
            name: firstDish.restaurantName,
            qrCode: buildRestaurantQr(firstDish.restaurantName),
            dishes: entry.value,
          );
        })
        .toList(growable: false);
  }

  List<RestaurantSummary> _attachDishesToRestaurants(
    List<RestaurantSummary> restaurants,
    List<Dish> dishes,
  ) {
    if (restaurants.isEmpty) {
      return _restaurantsFromDishes(dishes);
    }

    return restaurants
        .map((RestaurantSummary restaurant) {
          final List<Dish> restaurantDishes = dishes
              .where((Dish dish) {
                return dish.ownerUid == restaurant.ownerUid &&
                    dish.restaurantId == restaurant.id;
              })
              .toList(growable: false);
          return restaurant.copyWith(dishes: restaurantDishes);
        })
        .toList(growable: false);
  }

  RestaurantSummary? get _selectedRestaurant {
    if (_restaurants.isEmpty) {
      return null;
    }
    final String restaurantKey =
        _selectedRestaurantKey ?? _restaurants.first.key;
    for (final RestaurantSummary restaurant in _restaurants) {
      if (restaurant.key == restaurantKey) {
        return restaurant;
      }
    }
    return _restaurants.first;
  }

  List<RestaurantSummary> get _filteredRestaurants {
    final String query = normalizeRestaurantValue(_restaurantSearchQuery);
    if (query.isEmpty) {
      return _restaurants;
    }
    return _restaurants
        .where((RestaurantSummary restaurant) {
          return normalizeRestaurantValue(restaurant.name).contains(query) ||
              normalizeRestaurantValue(restaurant.qrCode).contains(query) ||
              normalizeRestaurantValue(restaurant.key).contains(query);
        })
        .toList(growable: false);
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
    return restaurant.dishes
        .where((Dish dish) {
          if (_selectedCategory == 'Todas') {
            return true;
          }
          return dish.categoryId == _selectedCategory;
        })
        .toList(growable: false);
  }

  List<OrderRecord> get _trackingOrders {
    return _orders
        .where((OrderRecord order) {
          return order.status != OrderStatus.delivered &&
              order.status != OrderStatus.cancelled;
        })
        .toList(growable: false);
  }

  List<OrderRecord> get _historyOrders {
    return _orders
        .where((OrderRecord order) {
          return order.status == OrderStatus.delivered ||
              order.status == OrderStatus.cancelled;
        })
        .toList(growable: false);
  }

  List<CartEntry> get _cartEntries {
    return _cart.entries
        .map((MapEntry<String, int> entry) {
          final Dish? dish = _findDish(entry.key);
          if (dish == null) {
            return null;
          }
          return CartEntry(dish: dish, quantity: entry.value);
        })
        .whereType<CartEntry>()
        .toList(growable: false);
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

  String get _draftStorageKey {
    final String uid = _firebaseUser?.uid ?? 'anonymous';
    return 'cruchef_cart_draft_$uid';
  }

  Future<void> _saveCartDraft() async {
    final User? user = _firebaseUser;
    if (user == null) {
      return;
    }

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final Map<String, dynamic> draft = <String, dynamic>{
      'restaurantKey': _selectedRestaurantKey,
      'paymentMethod': _selectedPaymentMethod.name,
      'paymentName': _paymentNameController.text.trim(),
      'paymentDocument': _paymentDocumentController.text.trim(),
      'paymentPhone': _paymentPhoneController.text.trim(),
      'paymentReference': _paymentReferenceController.text.trim(),
      'notes': _orderNotesController.text.trim(),
      'cart': _cart,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await preferences.setString(_draftStorageKey, jsonEncode(draft));
  }

  Future<void> _clearCartDraft() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(_draftStorageKey);
  }

  Future<void> _restoreCartDraft(
    List<RestaurantSummary> restaurants,
    List<Dish> dishes,
  ) async {
    final User? user = _firebaseUser;
    if (user == null || _draftRestored) {
      return;
    }

    _draftRestored = true;
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? rawDraft = preferences.getString(_draftStorageKey);
    if (rawDraft == null || rawDraft.isEmpty) {
      return;
    }

    try {
      final Object? decoded = jsonDecode(rawDraft);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final String restaurantKey = _readString(decoded, <String>[
        'restaurantKey',
      ]);
      final bool restaurantExists = restaurants.any(
        (RestaurantSummary restaurant) => restaurant.key == restaurantKey,
      );
      if (!restaurantExists) {
        return;
      }

      final Object? rawCart = decoded['cart'];
      if (rawCart is! Map<String, dynamic>) {
        return;
      }

      final Set<String> validDishIds = dishes
          .map((Dish dish) => dish.id)
          .toSet();
      final Map<String, int> restoredCart = <String, int>{};
      for (final MapEntry<String, dynamic> entry in rawCart.entries) {
        final int quantity = _readDynamicInt(entry.value);
        if (quantity > 0 && validDishIds.contains(entry.key)) {
          restoredCart[entry.key] = quantity;
        }
      }

      if (restoredCart.isEmpty) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedRestaurantKey = restaurantKey;
        _selectedPaymentMethod = parsePaymentMethod(
          _readString(decoded, <String>['paymentMethod'], fallback: 'cash'),
        );
        _orderNotesController.text = _readString(decoded, <String>['notes']);
        _paymentNameController.text = _readString(decoded, <String>[
          'paymentName',
        ]);
        _paymentDocumentController.text = _readString(decoded, <String>[
          'paymentDocument',
        ]);
        _paymentPhoneController.text = _readString(decoded, <String>[
          'paymentPhone',
        ]);
        _paymentReferenceController.text = _readString(decoded, <String>[
          'paymentReference',
        ]);
        _cart
          ..clear()
          ..addAll(restoredCart);
      });
    } catch (error) {
      debugPrint('No se pudo restaurar el carrito pausado: $error');
    }
  }

  Dish? _findDish(String id) {
    for (final Dish dish in _dishes) {
      if (dish.id == id) {
        return dish;
      }
    }
    return null;
  }

  void _showSnackBar(
    String message, {
    Color backgroundColor = const Color(0xFF4C1D1D),
  }) {
    final ScaffoldMessengerState? messenger =
        _scaffoldMessengerKey.currentState;
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(backgroundColor: backgroundColor, content: Text(message)),
      );
  }

  Future<void> _login(String email, String password) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      setState(() {
        _loginError = 'Ingresa tu correo y contraseña para continuar.';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _loginError = null;
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
        _loginError = loginErrorMessage(error);
      });
      _showSnackBar(_loginError ?? 'No se pudo iniciar sesión.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
        _loginError = 'No se pudo iniciar sesión. Intenta nuevamente.';
      });
      _showSnackBar(_loginError!);
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

    List<RestaurantSummary> restaurants = <RestaurantSummary>[];
    List<Dish> dishes = <Dish>[];
    List<OrderRecord> orders = <OrderRecord>[];
    UserProfileData profile = const UserProfileData();
    String? syncWarning;
    bool firebaseConnected = false;

    try {
      restaurants = await _repository.getRestaurants();
      firebaseConnected = true;
    } on FirebaseException catch (error) {
      syncWarning = _firebaseErrorMessage('restaurantes', error);
      debugPrint(syncWarning);
    } catch (error) {
      syncWarning =
          'No se pudieron cargar los restaurantes desde Firebase: $error';
      debugPrint(syncWarning);
    }

    try {
      dishes = await _repository.getDishes();
      firebaseConnected = true;
    } on FirebaseException catch (error) {
      syncWarning ??= _firebaseErrorMessage('platos', error);
      debugPrint(_firebaseErrorMessage('platos', error));
    } catch (error) {
      syncWarning ??= 'No se pudieron cargar los platos desde Firebase: $error';
      debugPrint('No se pudieron cargar los platos desde Firebase: $error');
    }

    if (syncWarning == null) {
      try {
        orders = await _repository.getOrders(customerUid: user.uid);
      } on FirebaseException catch (error) {
        syncWarning = _firebaseErrorMessage('órdenes', error);
        debugPrint(syncWarning);
      } catch (error) {
        syncWarning = 'No se pudieron cargar tus órdenes. Intenta nuevamente.';
        debugPrint(syncWarning);
      }
    }

    try {
      profile = await _repository.getUserProfile(user.uid);
    } catch (error) {
      debugPrint('No se pudo cargar el perfil del usuario: $error');
    }

    if (!mounted) {
      return;
    }

    final List<RestaurantSummary> resolvedRestaurants =
        _attachDishesToRestaurants(restaurants, dishes);
    final bool keepSelectedRestaurant =
        _selectedRestaurantKey != null &&
        resolvedRestaurants.any(
          (RestaurantSummary restaurant) =>
              restaurant.key == _selectedRestaurantKey,
        );
    final String? selectedRestaurantKey = keepSelectedRestaurant
        ? _selectedRestaurantKey
        : resolvedRestaurants.isEmpty
        ? null
        : resolvedRestaurants.first.key;

    setState(() {
      _firebaseOnline = firebaseConnected;
      _restaurants = resolvedRestaurants;
      _dishes = dishes;
      _orders = orders;
      _profilePhone = profile.phone;
      _profilePhotoUrl = profile.photoUrl;
      _selectedRestaurantKey = selectedRestaurantKey;
      _selectedCategory = 'Todas';
      _isBusy = false;
    });

    await _restoreCartDraft(resolvedRestaurants, dishes);

    if (syncWarning != null) {
      _showSnackBar(syncWarning);
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
      _restaurants = <RestaurantSummary>[];
      _dishes = <Dish>[];
      _orders = <OrderRecord>[];
      _selectedRestaurantKey = null;
      _selectedCategory = 'Todas';
      _selectedPaymentMethod = PaymentMethod.cash;
      _profilePhone = '';
      _profilePhotoUrl = '';
      _orderNotesController.clear();
      _clearPaymentControllers();
      _cart.clear();
      _draftRestored = false;
    });
  }

  void _selectRestaurant(String restaurantKey) {
    if (_selectedRestaurantKey == restaurantKey) {
      return;
    }
    setState(() {
      _selectedRestaurantKey = restaurantKey;
      _restaurantSearchQuery = '';
      _manualQrController.clear();
      _selectedCategory = 'Todas';
      _cart.clear();
      _selectedPaymentMethod = PaymentMethod.cash;
      _orderNotesController.clear();
      _clearPaymentControllers();
    });
    _saveCartDraft();
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  void _selectPaymentMethod(PaymentMethod method) {
    setState(() {
      _selectedPaymentMethod = method;
    });
    _saveCartDraft();
  }

  void _updateOrderNotes(String value) {
    _saveCartDraft();
  }

  void _updatePaymentDetails(String value) {
    _saveCartDraft();
  }

  void _clearPaymentControllers() {
    _paymentNameController.clear();
    _paymentDocumentController.clear();
    _paymentPhoneController.clear();
    _paymentReferenceController.clear();
  }

  void _cancelCart() {
    if (_cart.isEmpty) {
      return;
    }
    setState(() {
      _cart.clear();
      _selectedPaymentMethod = PaymentMethod.cash;
      _orderNotesController.clear();
      _clearPaymentControllers();
    });
    _clearCartDraft();
    _showSnackBar(
      'Carrito cancelado.',
      backgroundColor: const Color(0xFF163928),
    );
  }

  void _addToCart(Dish dish) {
    if (_selectedRestaurantKey != null &&
        '${dish.ownerUid}:${dish.restaurantId}' != _selectedRestaurantKey) {
      return;
    }
    setState(() {
      _cart.update(dish.id, (int value) => value + 1, ifAbsent: () => 1);
    });
    _saveCartDraft();
  }

  void _removeFromCart(Dish dish) {
    final int? quantity = _cart[dish.id];
    if (quantity == null) {
      return;
    }
    if (quantity <= 1) {
      _showSnackBar('El plato queda en 1. Usa Cancelar carrito para vaciarlo.');
      return;
    }
    setState(() {
      _cart[dish.id] = quantity - 1;
    });
    _saveCartDraft();
  }

  bool _applyQrCode(String rawCode) {
    final String trimmedCode = rawCode.trim();
    final String? restaurantKeyFromUrl = restaurantKeyFromPublicMenuUrl(
      trimmedCode,
    );
    if (restaurantKeyFromUrl != null) {
      for (final RestaurantSummary restaurant in _restaurants) {
        if (restaurant.key == restaurantKeyFromUrl) {
          _selectRestaurant(restaurant.key);
          return true;
        }
      }
    }

    final String normalized = normalizeRestaurantValue(rawCode);
    for (final RestaurantSummary restaurant in _restaurants) {
      if (normalizeRestaurantValue(restaurant.qrCode) == normalized ||
          normalizeRestaurantValue(restaurant.name) == normalized ||
          normalizeRestaurantValue(restaurant.key) == normalized ||
          normalizeRestaurantValue(restaurant.id) == normalized) {
        _selectRestaurant(restaurant.key);
        return true;
      }
    }
    return false;
  }

  void _submitManualQr() {
    final String value = _manualQrController.text.trim();
    final bool found = _applyQrCode(value);
    setState(() {
      _restaurantSearchQuery = found ? '' : value;
    });
    _manualQrController.clear();
    _showSnackBar(
      found
          ? 'Restaurante actualizado.'
          : 'Busca el restaurante por nombre o QR.',
      backgroundColor: found
          ? const Color(0xFF163928)
          : const Color(0xFF4C1D1D),
    );
  }

  Future<void> _openScanner() async {
    final PermissionStatus status = await Permission.camera.status;
    PermissionStatus resolvedStatus = status;

    if (status.isDenied) {
      resolvedStatus = await Permission.camera.request();
    }

    if (!mounted) {
      return;
    }

    if (resolvedStatus.isPermanentlyDenied || resolvedStatus.isRestricted) {
      _showSnackBar(
        'La cámara está bloqueada para CruChef. Activa el permiso en ajustes.',
      );
      await openAppSettings();
      return;
    }

    if (!resolvedStatus.isGranted) {
      _showSnackBar('No se concedió el permiso de cámara.');
      return;
    }

    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator == null) {
      _showSnackBar('No se pudo abrir el escaner en este momento.');
      return;
    }

    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ScannerPage(
          onDetected: (String code) {
            final bool found = _applyQrCode(code);
            navigator.pop();
            if (!mounted) {
              return;
            }
            _showSnackBar(
              found
                  ? 'Restaurante cambiado a ${_selectedRestaurant?.name ?? ''}.'
                  : 'QR no reconocido.',
              backgroundColor: found
                  ? const Color(0xFF163928)
                  : const Color(0xFF4C1D1D),
            );
          },
        ),
      ),
    );
  }

  void _updateRestaurantSearch(String value) {
    setState(() {
      _restaurantSearchQuery = value;
    });
  }

  Future<void> _updateProfileName(String displayName) async {
    final User? user = _firebaseUser;
    final String trimmedName = displayName.trim();
    if (user == null || trimmedName.isEmpty) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await user.updateDisplayName(trimmedName);
      await _repository.updateUserProfile(
        user.uid,
        displayName: trimmedName,
        phone: _profilePhone,
        photoUrl: _profilePhotoUrl,
      );
      await user.reload();

      if (!mounted) {
        return;
      }

      setState(() {
        _isBusy = false;
      });

      _showSnackBar(
        'Perfil actualizado.',
        backgroundColor: const Color(0xFF163928),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
      });
      _showSnackBar('No se pudo actualizar el perfil: $error');
    }
  }

  Future<void> _updateProfileDetails({
    required String displayName,
    required String phone,
    required String photoUrl,
  }) async {
    final User? user = _firebaseUser;
    final String trimmedName = displayName.trim();
    if (user == null || trimmedName.isEmpty) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await user.updateDisplayName(trimmedName);
      await user.reload();
      await _repository.updateUserProfile(
        user.uid,
        displayName: trimmedName,
        phone: phone.trim(),
        photoUrl: photoUrl.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _profilePhone = phone.trim();
        _profilePhotoUrl = photoUrl.trim();
        _isBusy = false;
      });

      _showSnackBar(
        'Perfil actualizado.',
        backgroundColor: const Color(0xFF163928),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
      });
      _showSnackBar('No se pudo actualizar el perfil: $error');
    }
  }

  Future<void> _sendPasswordReset() async {
    final User? user = _firebaseUser;
    final String email = user?.email?.trim() ?? '';
    if (email.isEmpty) {
      _showSnackBar('Tu cuenta no tiene un correo disponible.');
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await _auth.sendPasswordResetEmail(email: email);

      if (!mounted) {
        return;
      }

      setState(() {
        _isBusy = false;
      });

      _showSnackBar(
        'Te enviamos un correo para cambiar tu contraseña.',
        backgroundColor: const Color(0xFF163928),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
      });
      _showSnackBar('No se pudo enviar el correo de recuperación: $error');
    }
  }

  Future<void> _refreshProfile() async {
    final User? user = _firebaseUser;
    if (user != null) {
      await user.reload();
    }
    await _bootstrap();
  }

  String? _validatePaymentDetails() {
    final String name = _paymentNameController.text.trim();
    final String phone = _paymentPhoneController.text.trim();
    final String reference = _paymentReferenceController.text.trim();
    final String document = _paymentDocumentController.text.trim();

    if (name.length < 3) {
      return 'Ingresa el nombre de quien paga.';
    }
    if (phone.length < 7) {
      return 'Ingresa un teléfono de contacto válido.';
    }

    switch (_selectedPaymentMethod) {
      case PaymentMethod.cash:
        return null;
      case PaymentMethod.card:
        if (document.length < 5) {
          return 'Ingresa el documento del titular para pago con tarjeta.';
        }
        return null;
      case PaymentMethod.transfer:
        if (reference.length < 4) {
          return 'Ingresa el número de referencia o comprobante del pago.';
        }
        return null;
    }
  }

  Future<bool> _confirmOrder() async {
    final BuildContext? context = _navigatorKey.currentContext;
    if (context == null) {
      return true;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar pedido'),
          content: Text(
            'Enviarás $_cartCount platos por ${formatPrice(_cartTotal)}. '
            'Método de pago: ${_selectedPaymentMethod.label}.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Revisar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enviar pedido'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _placeOrder() async {
    final User? user = _firebaseUser;
    final RestaurantSummary? restaurant = _selectedRestaurant;
    if (user == null || restaurant == null || _cartEntries.isEmpty) {
      return;
    }

    final String? paymentError = _validatePaymentDetails();
    if (paymentError != null) {
      _showSnackBar(paymentError);
      return;
    }

    final bool confirmed = await _confirmOrder();
    if (!confirmed) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      for (final CartEntry entry in _cartEntries) {
        await _repository.createOrder(
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
            notes: _orderNotesController.text.trim(),
            paymentMethod: _selectedPaymentMethod.name,
            paymentName: _paymentNameController.text.trim(),
            paymentDocument: _paymentDocumentController.text.trim(),
            paymentPhone: _paymentPhoneController.text.trim(),
            paymentReference: _paymentReferenceController.text.trim(),
          ),
        );
      }

      final List<OrderRecord> orders = await _repository.getOrders(
        customerUid: user.uid,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _orders = orders;
        _cart.clear();
        _orderNotesController.clear();
        _clearPaymentControllers();
        _selectedPaymentMethod = PaymentMethod.cash;
        _isBusy = false;
      });
      await _clearCartDraft();

      _showSnackBar(
        'Pedido enviado al restaurante.',
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
      await _repository.rateOrder(
        id: order.documentPath,
        rating: result.rating,
        reviewText: result.reviewText,
      );

      final User? user = _firebaseUser;
      if (user != null) {
        _orders = await _repository.getOrders(customerUid: user.uid);
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
      final String result = await _repository.textToDish(
        _voiceController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
      });
      _showSnackBar(result, backgroundColor: const Color(0xFF163928));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
      });
      _showSnackBar('No se pudo buscar el plato: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CruchefDesign.theme,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      home: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _firebaseUser == null
              ? LoginPage(
                  onLogin: _login,
                  isBusy: _isBusy,
                  errorMessage: _loginError,
                )
              : UserShell(
                  user: _firebaseUser!,
                  firebaseOnline: _firebaseOnline,
                  restaurants: _filteredRestaurants,
                  selectedRestaurant: _selectedRestaurant,
                  categories: _categories,
                  selectedCategory: _selectedCategory,
                  dishes: _visibleDishes,
                  cartEntries: _cartEntries,
                  cartCount: _cartCount,
                  cartTotal: _cartTotal,
                  selectedPaymentMethod: _selectedPaymentMethod,
                  trackingOrders: _trackingOrders,
                  historyOrders: _historyOrders,
                  manualQrController: _manualQrController,
                  voiceController: _voiceController,
                  orderNotesController: _orderNotesController,
                  paymentNameController: _paymentNameController,
                  paymentDocumentController: _paymentDocumentController,
                  paymentPhoneController: _paymentPhoneController,
                  paymentReferenceController: _paymentReferenceController,
                  onSelectRestaurant: _selectRestaurant,
                  onSelectCategory: _selectCategory,
                  onAddToCart: _addToCart,
                  onRemoveFromCart: _removeFromCart,
                  onCancelCart: _cancelCart,
                  onSelectPaymentMethod: _selectPaymentMethod,
                  onOrderNotesChanged: (String value) {
                    _updateOrderNotes(value);
                    _updatePaymentDetails(value);
                  },
                  onOpenScanner: _openScanner,
                  onSubmitManualQr: _submitManualQr,
                  onRestaurantSearchChanged: _updateRestaurantSearch,
                  onAnalyzeVoiceText: _analyzeVoiceText,
                  onPlaceOrder: _placeOrder,
                  onRateOrder: _rateOrder,
                  onRefresh: _bootstrap,
                  onRefreshProfile: _refreshProfile,
                  onUpdateProfileName: _updateProfileName,
                  onUpdateProfileDetails: _updateProfileDetails,
                  onSendPasswordReset: _sendPasswordReset,
                  onLogout: _logout,
                  profilePhone: _profilePhone,
                  profilePhotoUrl: _profilePhotoUrl,
                ),
          if (_isBusy) const BusyOverlay(),
        ],
      ),
    );
  }
}

class RatingResult {
  const RatingResult({required this.rating, required this.reviewText});

  final int rating;
  final String reviewText;
}

class ProfileRowData {
  const ProfileRowData({required this.label, required this.value});

  final String label;
  final String value;
}

class UserProfileData {
  const UserProfileData({this.phone = '', this.photoUrl = ''});

  final String phone;
  final String photoUrl;
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
    final String restaurantName = _readString(json, <String>[
      'restaurant',
      'restaurantName',
    ], fallback: 'CruChef');

    return Dish(
      id: _readString(json, <String>['id', '_id'], fallback: ''),
      ownerUid: _readString(json, <String>[
        'ownerUid',
        'owner_uid',
      ], fallback: ''),
      restaurantId: _readString(json, <String>[
        'restaurantId',
        'restaurant_id',
      ], fallback: slugify(restaurantName)),
      restaurantName: restaurantName,
      name: _readString(json, <String>['nombre', 'name'], fallback: 'Plato'),
      price: _readDouble(json, <String>['precio', 'price']),
      rating: _readDouble(json, <String>['rating'], fallback: 0),
      categoryId: _readString(json, <String>[
        'categoryId',
        'category_id',
      ], fallback: 'general'),
      imageKey: _readString(json, <String>['imageKey'], fallback: ''),
      imageUrl: _readString(json, <String>['imagen', 'imageUrl'], fallback: ''),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'nombre': name,
      'descripcion': '',
      'precio': price,
      'imagen': imageUrl,
      'name': name,
      'restaurant': restaurantName,
      'restaurantName': restaurantName,
      'restaurantId': restaurantId,
      'ownerUid': ownerUid,
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

  String get key => '$ownerUid:$id';

  RestaurantSummary copyWith({List<Dish>? dishes}) {
    return RestaurantSummary(
      id: id,
      ownerUid: ownerUid,
      name: name,
      qrCode: qrCode,
      dishes: dishes ?? this.dishes,
    );
  }
}

class CartEntry {
  const CartEntry({required this.dish, required this.quantity});

  final Dish dish;
  final int quantity;

  double get total => dish.price * quantity;
}

enum PaymentMethod {
  cash,
  card,
  transfer;

  String get label => switch (this) {
    PaymentMethod.cash => 'Pago en caja',
    PaymentMethod.card => 'Tarjeta',
    PaymentMethod.transfer => 'Transferencia / Nequi',
  };

  String get description => switch (this) {
    PaymentMethod.cash =>
      'Pagas en efectivo cuando recibas o retires el pedido.',
    PaymentMethod.card =>
      'Pagas con tarjeta en el datáfono del restaurante al recibir.',
    PaymentMethod.transfer =>
      'Registras el comprobante de transferencia, banco o Nequi.',
  };

  IconData get icon => switch (this) {
    PaymentMethod.cash => Icons.payments_outlined,
    PaymentMethod.card => Icons.credit_card,
    PaymentMethod.transfer => Icons.account_balance_outlined,
  };
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
    required this.documentPath,
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
    required this.paymentMethod,
    required this.paymentStatus,
    required this.rating,
    required this.reviewText,
  });

  final String id;
  final String documentPath;
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
  final String paymentMethod;
  final String paymentStatus;
  final double? rating;
  final String reviewText;

  double get total => unitPrice * quantity;

  String get statusLabel => status.label;

  bool get canRate => status == OrderStatus.delivered && rating == null;

  factory OrderRecord.fromJson(Map<String, dynamic> json) {
    return OrderRecord(
      id: _readString(json, <String>['id', '_id'], fallback: ''),
      documentPath: _readString(json, <String>['_path'], fallback: ''),
      ownerUid: _readString(json, <String>['ownerUid'], fallback: ''),
      restaurantId: _readString(json, <String>['restaurantId'], fallback: ''),
      restaurantName: _readString(json, <String>[
        'restaurantName',
      ], fallback: 'CruChef'),
      customerUid: _readString(json, <String>['customerUid'], fallback: ''),
      customerEmail: _readString(json, <String>['customerEmail'], fallback: ''),
      customerName: _readString(json, <String>['customerName'], fallback: ''),
      dishId: _readString(json, <String>['dishId'], fallback: ''),
      dishName: _readString(json, <String>['dishName'], fallback: 'Plato'),
      dishImageUrl: _readString(json, <String>['dishImageUrl'], fallback: ''),
      categoryId: _readString(json, <String>[
        'categoryId',
      ], fallback: 'general'),
      quantity: _readInt(json, <String>['quantity'], fallback: 1),
      unitPrice: _readDouble(json, <String>['unitPrice'], fallback: 0),
      status: parseOrderStatus(
        _readString(json, <String>['status'], fallback: 'pending'),
      ),
      createdAt: _readDateTime(json, <String>['createdAt', 'updatedAt']),
      notes: _readString(json, <String>['notes'], fallback: ''),
      paymentMethod: _readString(json, <String>[
        'paymentMethod',
      ], fallback: 'cash'),
      paymentStatus: _readString(json, <String>[
        'paymentStatus',
      ], fallback: 'pending'),
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
    required this.paymentMethod,
    required this.paymentName,
    required this.paymentDocument,
    required this.paymentPhone,
    required this.paymentReference,
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
  final String paymentMethod;
  final String paymentName;
  final String paymentDocument;
  final String paymentPhone;
  final String paymentReference;

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
      'paymentMethod': paymentMethod,
      'paymentName': paymentName,
      'paymentDocument': paymentDocument,
      'paymentPhone': paymentPhone,
      'paymentReference': paymentReference,
      'paymentDetails': <String, dynamic>{
        'name': paymentName,
        'document': paymentDocument,
        'phone': paymentPhone,
        'reference': paymentReference,
      },
      'serviceFee': 0,
      'totalPrice': quantity * unitPrice,
      'paymentStatus': paymentMethod == 'cash' ? 'pending' : 'pending_review',
    };
  }
}

class CruchefRepository {
  CruchefRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  Future<bool> health() async {
    await _restaurants.limit(1).get();
    return true;
  }

  Future<List<RestaurantSummary>> getRestaurants() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _restaurants
        .get();
    final List<RestaurantSummary> restaurants = snapshot.docs
        .map(_restaurantFromDocument)
        .where((RestaurantSummary restaurant) => restaurant.name.isNotEmpty)
        .toList(growable: false);
    restaurants.sort(
      (RestaurantSummary a, RestaurantSummary b) => a.name.compareTo(b.name),
    );
    return restaurants;
  }

  Future<List<Dish>> getDishes() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _dishes.get();
    final List<Dish> dishes = await Future.wait(
      snapshot.docs.map(_dishFromDocument).toList(growable: false),
    );
    dishes.sort((Dish a, Dish b) => a.name.compareTo(b.name));
    return dishes;
  }

  Future<Dish> createDish(Dish dish) async {
    final Map<String, dynamic> data = dish.toJson()
      ..['createdAt'] = FieldValue.serverTimestamp();
    final DocumentReference<Map<String, dynamic>> document =
        await _restaurantDishes(dish.ownerUid, dish.restaurantId).add(data);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await document
        .get();
    return _dishFromDocument(snapshot);
  }

  Future<Dish> updateDish(Dish dish) async {
    final DocumentReference<Map<String, dynamic>> document = _restaurantDishes(
      dish.ownerUid,
      dish.restaurantId,
    ).doc(dish.id);
    await document.set(
      dish.toJson()..['updatedAt'] = FieldValue.serverTimestamp(),
      SetOptions(merge: true),
    );
    return _dishFromDocument(await document.get());
  }

  Future<void> deleteDish(String id) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _dishes
        .where(FieldPath.documentId, isEqualTo: id)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.delete();
    }
  }

  Future<List<OrderRecord>> getOrders({
    String? ownerUid,
    String? customerUid,
    String? status,
  }) async {
    Query<Map<String, dynamic>> query;
    if (customerUid != null && customerUid.isNotEmpty) {
      query = _userOrders(customerUid);
    } else if (ownerUid != null && ownerUid.isNotEmpty) {
      query = _allOrders.where('ownerUid', isEqualTo: ownerUid);
    } else {
      query = _allOrders;
    }
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    final List<OrderRecord> orders = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> document) {
          return OrderRecord.fromJson(_withDocumentId(document));
        })
        .toList(growable: false);
    orders.sort(
      (OrderRecord a, OrderRecord b) => b.createdAt.compareTo(a.createdAt),
    );
    return orders;
  }

  Future<OrderRecord> createOrder(OrderCreatePayload payload) async {
    final Map<String, dynamic> data = payload.toJson()
      ..['status'] = OrderStatus.pending.name
      ..['rating'] = null
      ..['reviewText'] = ''
      ..['deliveredAt'] = null
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    final DocumentReference<Map<String, dynamic>> ownerOrder =
        await _restaurantOrders(
          payload.ownerUid,
          payload.restaurantId,
        ).add(data);
    final DocumentReference<Map<String, dynamic>> customerOrder = _userOrders(
      payload.customerUid,
    ).doc(ownerOrder.id);
    await customerOrder.set(<String, dynamic>{
      ...data,
      'ownerOrderPath': ownerOrder.path,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _createOwnerOrderNotification(
      payload: payload,
      orderId: ownerOrder.id,
    );
    return OrderRecord.fromJson(_withDocumentId(await customerOrder.get()));
  }

  Future<OrderRecord> updateOrderStatus({
    required String id,
    required String status,
  }) async {
    final DocumentReference<Map<String, dynamic>> document = _firestore.doc(id);
    await document.update(<String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return OrderRecord.fromJson(_withDocumentId(await document.get()));
  }

  Future<OrderRecord> rateOrder({
    required String id,
    required int rating,
    required String reviewText,
  }) async {
    final DocumentReference<Map<String, dynamic>> document = _firestore.doc(id);
    await document.update(<String, dynamic>{
      'rating': rating,
      'reviewText': reviewText,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return OrderRecord.fromJson(_withDocumentId(await document.get()));
  }

  Future<String> textToDish(String text) async {
    final String query = text.trim().toLowerCase();
    final List<Dish> dishes = await getDishes();
    for (final Dish dish in dishes) {
      if (query.contains(dish.name.toLowerCase()) ||
          dish.name.toLowerCase().contains(query)) {
        return 'Te recomiendo ${dish.name} por ${formatPrice(dish.price)}.';
      }
    }
    return 'No encontré un plato exacto. Intenta con otro nombre.';
  }

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Query<Map<String, dynamic>> get _dishes =>
      _firestore.collectionGroup('dishes');

  Query<Map<String, dynamic>> get _restaurants =>
      _firestore.collectionGroup('restaurants');

  Query<Map<String, dynamic>> get _allOrders =>
      _firestore.collectionGroup('orders');

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  CollectionReference<Map<String, dynamic>> _restaurantDishes(
    String ownerUid,
    String restaurantId,
  ) {
    return _firestore
        .collection('users')
        .doc(ownerUid)
        .collection('restaurants')
        .doc(restaurantId)
        .collection('dishes');
  }

  CollectionReference<Map<String, dynamic>> _restaurantOrders(
    String ownerUid,
    String restaurantId,
  ) {
    return _firestore
        .collection('users')
        .doc(ownerUid)
        .collection('restaurants')
        .doc(restaurantId)
        .collection('orders');
  }

  CollectionReference<Map<String, dynamic>> _userOrders(String userUid) {
    return _firestore.collection('users').doc(userUid).collection('orders');
  }

  Future<UserProfileData> getUserProfile(String userUid) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(userUid)
        .get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return const UserProfileData();
    }
    return UserProfileData(
      phone: _readString(data, <String>['phone', 'telefono', 'phoneNumber']),
      photoUrl: _readString(data, <String>[
        'photoUrl',
        'profilePhotoUrl',
        'avatarUrl',
      ]),
    );
  }

  Future<void> updateUserProfile(
    String userUid, {
    required String displayName,
    required String phone,
    required String photoUrl,
  }) async {
    await _firestore.collection('users').doc(userUid).set(<String, dynamic>{
      'displayName': displayName,
      'name': displayName,
      'phone': phone,
      'photoUrl': photoUrl,
      'profilePhotoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _createOwnerOrderNotification({
    required OrderCreatePayload payload,
    required String orderId,
  }) async {
    try {
      await _notifications.add(<String, dynamic>{
        'recipientUid': payload.ownerUid,
        'audience': 'owner',
        'type': 'order-created',
        'title': 'Nuevo pedido recibido',
        'message':
            '${payload.customerName} pidió ${payload.quantity} x ${payload.dishName}. Pago: ${paymentMethodLabel(payload.paymentMethod)}.',
        'orderId': orderId,
        'restaurantId': payload.restaurantId,
        'restaurantName': payload.restaurantName,
        'dishName': payload.dishName,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('No se pudo crear la notificación del pedido: $error');
    }
  }

  RestaurantSummary _restaurantFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = _withDocumentId(document);
    final String name = _readString(data, <String>['name', 'nombre']);
    return RestaurantSummary(
      id: document.id,
      ownerUid: _readString(data, <String>['ownerUid']),
      name: name,
      qrCode: _readString(data, <String>[
        'qrCode',
        'qr',
        'codigoQr',
      ], fallback: buildRestaurantQr(name)),
      dishes: const <Dish>[],
    );
  }

  Future<Dish> _dishFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final Map<String, dynamic> data = _withDocumentId(document);
    final String imageKey = _readString(data, <String>['imageKey']);
    final String imageUrl = _readString(data, <String>['imagen', 'imageUrl']);
    if (imageUrl.isEmpty && imageKey.isNotEmpty) {
      try {
        data['imagen'] = await _storage.ref(imageKey).getDownloadURL();
      } catch (_) {
        data['imagen'] = '';
      }
    }
    return Dish.fromJson(data);
  }
}

Map<String, dynamic> _withDocumentId(
  DocumentSnapshot<Map<String, dynamic>> document,
) {
  final List<String> segments = document.reference.path.split('/');
  final Map<String, dynamic> pathData = <String, dynamic>{};
  final int usersIndex = segments.indexOf('users');
  final int restaurantsIndex = segments.indexOf('restaurants');
  if (usersIndex >= 0 && usersIndex + 1 < segments.length) {
    pathData['ownerUid'] = segments[usersIndex + 1];
  }
  if (restaurantsIndex >= 0 && restaurantsIndex + 1 < segments.length) {
    pathData['restaurantId'] = segments[restaurantsIndex + 1];
  }

  return <String, dynamic>{
    ...pathData,
    ...?document.data(),
    'id': document.id,
    '_path': document.reference.path,
  };
}

String _firebaseErrorMessage(String collection, FirebaseException error) {
  switch (error.code) {
    case 'permission-denied':
      return 'No se pudo cargar $collection. Revisa tu conexión e intenta de nuevo.';
    case 'unavailable':
      return 'El servicio no está disponible ahora. Revisa tu conexión e intenta de nuevo.';
    case 'failed-precondition':
      return 'No se pudo preparar la consulta de $collection. Intenta más tarde.';
    case 'not-found':
      return 'No hay datos disponibles para $collection en este momento.';
    default:
      return 'No se pudo cargar $collection. Intenta nuevamente.';
  }
}

String loginErrorMessage(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'El correo o la contraseña no corresponden a una cuenta registrada.';
    case 'invalid-email':
      return 'Ingresa un correo electrónico válido.';
    case 'user-disabled':
      return 'Esta cuenta esta deshabilitada.';
    case 'too-many-requests':
      return 'Demasiados intentos. Espera un momento y vuelve a intentar.';
    case 'network-request-failed':
      return 'No hay conexión para iniciar sesión.';
    default:
      return error.message ?? 'No se pudo iniciar sesión.';
  }
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

int _readInt(Map<String, dynamic> json, List<String> keys, {int fallback = 0}) {
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

int _readDynamicInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

DateTime _readDateTime(Map<String, dynamic> json, List<String> keys) {
  for (final String key in keys) {
    final dynamic value = json[key];
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    if (value is String) {
      final DateTime? parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed.toLocal();
      }
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt()).toLocal();
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

PaymentMethod parsePaymentMethod(String value) {
  switch (value.toLowerCase()) {
    case 'card':
      return PaymentMethod.card;
    case 'transfer':
      return PaymentMethod.transfer;
    default:
      return PaymentMethod.cash;
  }
}

String paymentMethodLabel(String value) => parsePaymentMethod(value).label;

String? restaurantKeyFromPublicMenuUrl(String value) {
  Uri? uri = Uri.tryParse(value.trim());
  uri ??= Uri.tryParse('https://cruchef.local/$value');
  if (uri == null) {
    return null;
  }

  final List<String> segments = uri.pathSegments
      .map(Uri.decodeComponent)
      .where((String segment) => segment.trim().isNotEmpty)
      .toList(growable: false);
  final int publicIndex = segments.indexOf('public');
  if (publicIndex >= 0 &&
      publicIndex + 3 < segments.length &&
      segments[publicIndex + 1] == 'menu') {
    return '${segments[publicIndex + 2]}:${segments[publicIndex + 3]}';
  }

  final int menuIndex = segments.indexOf('menu');
  if (menuIndex >= 0 && menuIndex + 2 < segments.length) {
    return '${segments[menuIndex + 1]}:${segments[menuIndex + 2]}';
  }

  return null;
}

IconData iconForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'todas':
    case 'all':
      return Icons.room_service_outlined;
    case 'burgers':
    case 'burger':
    case 'hamburguesas':
      return Icons.lunch_dining;
    case 'pizza':
    case 'pizzas':
      return Icons.local_pizza;
    case 'tacos':
      return Icons.tapas;
    case 'sushi':
      return Icons.set_meal;
    case 'pasta':
    case 'pastas':
      return Icons.dinner_dining;
    case 'chicken':
    case 'pollo':
      return Icons.kebab_dining;
    case 'combo':
    case 'combos':
      return Icons.bento;
    case 'desserts':
    case 'dessert':
    case 'postres':
      return Icons.cake;
    case 'drinks':
    case 'bebidas':
      return Icons.local_drink;
    case 'breakfast':
    case 'desayunos':
      return Icons.breakfast_dining;
    case 'salads':
    case 'ensaladas':
      return Icons.eco;
    default:
      return Icons.fastfood;
  }
}

String categoryEmoji(String category) {
  switch (category.toLowerCase()) {
    case 'todas':
    case 'all':
      return '🍽️';
    case 'burgers':
    case 'burger':
    case 'hamburguesas':
      return '🍔';
    case 'pizza':
    case 'pizzas':
      return '🍕';
    case 'tacos':
      return '🌮';
    case 'sushi':
      return '🍣';
    case 'pasta':
    case 'pastas':
      return '🍝';
    case 'chicken':
    case 'pollo':
      return '🍗';
    case 'combo':
    case 'combos':
      return '🍱';
    case 'desserts':
    case 'dessert':
    case 'postres':
      return '🍰';
    case 'drinks':
    case 'bebidas':
      return '🥤';
    case 'breakfast':
    case 'desayunos':
      return '🥞';
    case 'salads':
    case 'ensaladas':
      return '🥗';
    case 'grill':
    case 'parrilla':
      return '🥩';
    case 'seafood':
    case 'mariscos':
      return '🦐';
    case 'fish':
    case 'pescados':
      return '🐟';
    case 'soups':
    case 'sopas':
      return '🍲';
    case 'rice':
    case 'arroces':
      return '🍚';
    case 'vegan':
    case 'vegano':
      return '🥦';
    case 'coffee':
    case 'cafe':
    case 'café':
      return '☕';
    case 'icecream':
    case 'helados':
      return '🍦';
    case 'bakery':
    case 'panaderia':
    case 'panadería':
      return '🥐';
    case 'hotdogs':
    case 'perros':
      return '🌭';
    case 'arepas':
      return '🫓';
    case 'healthy':
    case 'saludable':
      return '🥑';
    default:
      return '🍽️';
  }
}

String categoryLabel(String category) {
  switch (category.toLowerCase()) {
    case 'todas':
    case 'all':
      return 'Todas';
    case 'burgers':
      return 'Burger';
    case 'pizza':
      return 'Pizza';
    case 'tacos':
      return 'Tacos';
    case 'sushi':
      return 'Sushi';
    case 'pasta':
    case 'pastas':
      return 'Pastas';
    case 'chicken':
      return 'Pollo';
    case 'combo':
      return 'Combos';
    case 'desserts':
      return 'Postres';
    case 'drinks':
      return 'Bebidas';
    case 'breakfast':
      return 'Desayunos';
    case 'salads':
      return 'Ensaladas';
    case 'grill':
      return 'Parrilla';
    case 'seafood':
      return 'Mariscos';
    case 'fish':
      return 'Pescados';
    case 'soups':
      return 'Sopas';
    case 'rice':
      return 'Arroces';
    case 'vegan':
      return 'Vegano';
    case 'coffee':
      return 'Café';
    case 'icecream':
      return 'Helados';
    case 'bakery':
      return 'Panadería';
    case 'hotdogs':
      return 'Perros';
    case 'arepas':
      return 'Arepas';
    case 'healthy':
      return 'Saludable';
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

String formatProfileDate(DateTime? dateTime) {
  if (dateTime == null) {
    return 'No disponible';
  }
  final DateTime local = dateTime.toLocal();
  final String day = local.day.toString().padLeft(2, '0');
  final String month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
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
