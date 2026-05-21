part of '../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLogin,
    required this.isBusy,
    required this.errorMessage,
  });

  final Future<void> Function(String email, String password) onLogin;
  final bool isBusy;
  final String? errorMessage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CruchefPageBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool isWide = constraints.maxWidth > 880;
              final double minContentHeight = constraints.maxHeight > 48
                  ? constraints.maxHeight - 48
                  : 0;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minContentHeight),
                  child: isWide
                      ? SizedBox(
                          height: minContentHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              const Expanded(child: LoginIntroPanel()),
                              const SizedBox(width: 32),
                              Expanded(
                                child: LoginFormCard(
                                  emailController: _emailController,
                                  passwordController: _passwordController,
                                  isBusy: widget.isBusy,
                                  errorMessage: widget.errorMessage,
                                  obscurePassword: _obscurePassword,
                                  onTogglePassword: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  onLogin: () => widget.onLogin(
                                    _emailController.text,
                                    _passwordController.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                              errorMessage: widget.errorMessage,
                              obscurePassword: _obscurePassword,
                              onTogglePassword: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              onLogin: () => widget.onLogin(
                                _emailController.text,
                                _passwordController.text,
                              ),
                            ),
                          ],
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
    required this.firebaseOnline,
    required this.restaurants,
    required this.selectedRestaurant,
    required this.categories,
    required this.selectedCategory,
    required this.dishes,
    required this.cartEntries,
    required this.cartCount,
    required this.cartTotal,
    required this.selectedPaymentMethod,
    required this.trackingOrders,
    required this.historyOrders,
    required this.manualQrController,
    required this.voiceController,
    required this.orderNotesController,
    required this.paymentNameController,
    required this.paymentDocumentController,
    required this.paymentPhoneController,
    required this.paymentReferenceController,
    required this.paymentCardNumberController,
    required this.paymentCardExpiryController,
    required this.paymentCardCvvController,
    required this.onSelectRestaurant,
    required this.onSelectCategory,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.onCancelCart,
    required this.onSelectPaymentMethod,
    required this.onOrderNotesChanged,
    required this.onOpenScanner,
    required this.onSubmitManualQr,
    required this.onRestaurantSearchChanged,
    required this.onAnalyzeVoiceText,
    required this.onPlaceOrder,
    required this.onRateOrder,
    required this.onRefresh,
    required this.onRefreshProfile,
    required this.onUpdateProfileName,
    required this.onUpdateProfileDetails,
    required this.onPickProfilePhoto,
    required this.onSendPasswordReset,
    required this.onLogout,
    required this.profilePhone,
    required this.profilePhotoUrl,
  });

  final User user;
  final bool firebaseOnline;
  final List<RestaurantSummary> restaurants;
  final RestaurantSummary? selectedRestaurant;
  final List<String> categories;
  final String selectedCategory;
  final List<Dish> dishes;
  final List<CartEntry> cartEntries;
  final int cartCount;
  final double cartTotal;
  final PaymentMethod selectedPaymentMethod;
  final List<OrderRecord> trackingOrders;
  final List<OrderRecord> historyOrders;
  final TextEditingController manualQrController;
  final TextEditingController voiceController;
  final TextEditingController orderNotesController;
  final TextEditingController paymentNameController;
  final TextEditingController paymentDocumentController;
  final TextEditingController paymentPhoneController;
  final TextEditingController paymentReferenceController;
  final TextEditingController paymentCardNumberController;
  final TextEditingController paymentCardExpiryController;
  final TextEditingController paymentCardCvvController;
  final ValueChanged<String> onSelectRestaurant;
  final ValueChanged<String> onSelectCategory;
  final ValueChanged<Dish> onAddToCart;
  final ValueChanged<Dish> onRemoveFromCart;
  final VoidCallback onCancelCart;
  final ValueChanged<PaymentMethod> onSelectPaymentMethod;
  final ValueChanged<String> onOrderNotesChanged;
  final VoidCallback onOpenScanner;
  final VoidCallback onSubmitManualQr;
  final ValueChanged<String> onRestaurantSearchChanged;
  final Future<void> Function() onAnalyzeVoiceText;
  final Future<void> Function() onPlaceOrder;
  final Future<void> Function(OrderRecord order) onRateOrder;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRefreshProfile;
  final Future<void> Function(String displayName) onUpdateProfileName;
  final Future<void> Function({
    required String displayName,
    required String phone,
    required String photoUrl,
  })
  onUpdateProfileDetails;
  final Future<String?> Function() onPickProfilePhoto;
  final Future<void> Function() onSendPasswordReset;
  final Future<void> Function() onLogout;
  final String profilePhone;
  final String profilePhotoUrl;

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
        firebaseOnline: widget.firebaseOnline,
        restaurants: widget.restaurants,
        selectedRestaurant: widget.selectedRestaurant,
        categories: widget.categories,
        selectedCategory: widget.selectedCategory,
        dishes: widget.dishes,
        cartEntries: widget.cartEntries,
        cartCount: widget.cartCount,
        manualQrController: widget.manualQrController,
        voiceController: widget.voiceController,
        onSelectRestaurant: widget.onSelectRestaurant,
        onSelectCategory: widget.onSelectCategory,
        onAddToCart: widget.onAddToCart,
        onOpenScanner: widget.onOpenScanner,
        onOpenCart: () {
          setState(() {
            _tabIndex = 1;
          });
        },
        onSubmitManualQr: widget.onSubmitManualQr,
        onRestaurantSearchChanged: widget.onRestaurantSearchChanged,
        onAnalyzeVoiceText: widget.onAnalyzeVoiceText,
        onRefresh: widget.onRefresh,
      ),
      CartPage(
        entries: widget.cartEntries,
        total: widget.cartTotal,
        selectedPaymentMethod: widget.selectedPaymentMethod,
        notesController: widget.orderNotesController,
        paymentNameController: widget.paymentNameController,
        paymentDocumentController: widget.paymentDocumentController,
        paymentPhoneController: widget.paymentPhoneController,
        paymentReferenceController: widget.paymentReferenceController,
        paymentCardNumberController: widget.paymentCardNumberController,
        paymentCardExpiryController: widget.paymentCardExpiryController,
        paymentCardCvvController: widget.paymentCardCvvController,
        onAddToCart: widget.onAddToCart,
        onRemoveFromCart: widget.onRemoveFromCart,
        onCancelCart: widget.onCancelCart,
        onSelectPaymentMethod: widget.onSelectPaymentMethod,
        onNotesChanged: widget.onOrderNotesChanged,
        onPlaceOrder: widget.onPlaceOrder,
      ),
      TrackingPage(orders: widget.trackingOrders),
      HistoryPage(
        orders: widget.historyOrders,
        onRateOrder: widget.onRateOrder,
      ),
      ProfilePage(
        user: widget.user,
        ordersCount: widget.trackingOrders.length,
        historyCount: widget.historyOrders.length,
        onRefresh: widget.onRefreshProfile,
        onUpdateProfileName: widget.onUpdateProfileName,
        onUpdateProfileDetails: widget.onUpdateProfileDetails,
        onPickProfilePhoto: widget.onPickProfilePhoto,
        onSendPasswordReset: widget.onSendPasswordReset,
        onLogout: widget.onLogout,
        profilePhone: widget.profilePhone,
        profilePhotoUrl: widget.profilePhotoUrl,
      ),
    ];

    return Scaffold(
      body: CruchefPageBackground(
        child: SafeArea(
          child: IndexedStack(index: _tabIndex, children: pages),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _tabIndex = index;
          });
        },
        destinations: <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Menú',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: widget.cartCount > 0,
              label: Text('${widget.cartCount}'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: widget.cartCount > 0,
              label: Text('${widget.cartCount}'),
              child: const Icon(Icons.shopping_bag),
            ),
            label: 'Carrito',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Seguimiento',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
          const NavigationDestination(
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
    required this.firebaseOnline,
    required this.restaurants,
    required this.selectedRestaurant,
    required this.categories,
    required this.selectedCategory,
    required this.dishes,
    required this.cartEntries,
    required this.cartCount,
    required this.manualQrController,
    required this.voiceController,
    required this.onSelectRestaurant,
    required this.onSelectCategory,
    required this.onAddToCart,
    required this.onOpenScanner,
    required this.onOpenCart,
    required this.onSubmitManualQr,
    required this.onRestaurantSearchChanged,
    required this.onAnalyzeVoiceText,
    required this.onRefresh,
  });

  final User user;
  final bool firebaseOnline;
  final List<RestaurantSummary> restaurants;
  final RestaurantSummary? selectedRestaurant;
  final List<String> categories;
  final String selectedCategory;
  final List<Dish> dishes;
  final List<CartEntry> cartEntries;
  final int cartCount;
  final TextEditingController manualQrController;
  final TextEditingController voiceController;
  final ValueChanged<String> onSelectRestaurant;
  final ValueChanged<String> onSelectCategory;
  final ValueChanged<Dish> onAddToCart;
  final VoidCallback onOpenScanner;
  final VoidCallback onOpenCart;
  final VoidCallback onSubmitManualQr;
  final ValueChanged<String> onRestaurantSearchChanged;
  final Future<void> Function() onAnalyzeVoiceText;
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
                          const EyebrowText('Vista de usuario'),
                          const SizedBox(height: 8),
                          const Text(
                            'Restaurantes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text.rich(
                            TextSpan(
                              text:
                                  'Elige, escanea o busca un restaurante. Ahora estás en ',
                              children: <InlineSpan>[
                                TextSpan(
                                  text: selectedRestaurant?.name ?? 'CruChef',
                                  style: const TextStyle(
                                    color: CruchefColors.gold,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                            style: const TextStyle(
                              color: CruchefColors.muted,
                              fontSize: 16,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CartShortcutButton(count: cartCount, onTap: onOpenCart),
                    const SizedBox(width: 10),
                    _RoundIconButton(
                      icon: Icons.qr_code_2,
                      onTap: onOpenScanner,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: manualQrController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Buscar restaurante o pegar el enlace del QR',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: onSubmitManualQr,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                  onChanged: onRestaurantSearchChanged,
                  onSubmitted: (_) => onSubmitManualQr(),
                ),
                const SizedBox(height: 14),
                QrAccessCard(onScan: onOpenScanner),
                const SizedBox(height: 14),
                RestaurantSelectionPanel(
                  restaurants: restaurants,
                  selectedRestaurant: selectedRestaurant,
                  onSelectRestaurant: onSelectRestaurant,
                ),
                const SizedBox(height: 16),
                RestaurantHero(
                  selectedRestaurant: selectedRestaurant,
                  cartCount: cartCount,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: voiceController,
                  decoration: InputDecoration(
                    hintText: 'Buscar recomendación de plato',
                    prefixIcon: const Icon(Icons.mic_none),
                    suffixIcon: IconButton(
                      onPressed: () {
                        onAnalyzeVoiceText();
                      },
                      icon: const Icon(Icons.auto_awesome),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(width: 12),
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
                DishGrid(
                  dishes: dishes,
                  columns: isWide ? columns : 1,
                  onAddToCart: onAddToCart,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CartPage extends StatelessWidget {
  const CartPage({
    super.key,
    required this.entries,
    required this.total,
    required this.selectedPaymentMethod,
    required this.notesController,
    required this.paymentNameController,
    required this.paymentDocumentController,
    required this.paymentPhoneController,
    required this.paymentReferenceController,
    required this.paymentCardNumberController,
    required this.paymentCardExpiryController,
    required this.paymentCardCvvController,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.onCancelCart,
    required this.onSelectPaymentMethod,
    required this.onNotesChanged,
    required this.onPlaceOrder,
  });

  final List<CartEntry> entries;
  final double total;
  final PaymentMethod selectedPaymentMethod;
  final TextEditingController notesController;
  final TextEditingController paymentNameController;
  final TextEditingController paymentDocumentController;
  final TextEditingController paymentPhoneController;
  final TextEditingController paymentReferenceController;
  final TextEditingController paymentCardNumberController;
  final TextEditingController paymentCardExpiryController;
  final TextEditingController paymentCardCvvController;
  final ValueChanged<Dish> onAddToCart;
  final ValueChanged<Dish> onRemoveFromCart;
  final VoidCallback onCancelCart;
  final ValueChanged<PaymentMethod> onSelectPaymentMethod;
  final ValueChanged<String> onNotesChanged;
  final Future<void> Function() onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      children: <Widget>[
        ScreenHeader(
          eyebrow: 'Compra en pausa',
          title: 'Carrito',
          lead: const Text(
            'Revisa tu pedido, ajusta cantidades y escoge cómo vas a pagar.',
          ),
        ),
        const SizedBox(height: 22),
        CartPanel(
          entries: entries,
          total: total,
          selectedPaymentMethod: selectedPaymentMethod,
          notesController: notesController,
          paymentNameController: paymentNameController,
          paymentDocumentController: paymentDocumentController,
          paymentPhoneController: paymentPhoneController,
          paymentReferenceController: paymentReferenceController,
          paymentCardNumberController: paymentCardNumberController,
          paymentCardExpiryController: paymentCardExpiryController,
          paymentCardCvvController: paymentCardCvvController,
          onAddToCart: onAddToCart,
          onRemoveFromCart: onRemoveFromCart,
          onCancelCart: onCancelCart,
          onSelectPaymentMethod: onSelectPaymentMethod,
          onNotesChanged: onNotesChanged,
          onPlaceOrder: onPlaceOrder,
        ),
      ],
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
        ScreenHeader(
          eyebrow: 'Vista de usuario',
          title: 'Pedidos activos',
          lead: Text.rich(
            TextSpan(
              text: 'Tienes ',
              children: <InlineSpan>[
                TextSpan(
                  text: '${orders.length}',
                  style: const TextStyle(
                    color: CruchefColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(
                  text: ' pedidos en proceso con los propietarios.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (orders.isEmpty)
          const EmptyStateCard(
            icon: Icons.receipt_long_outlined,
            title: 'No hay compras en curso',
            subtitle: 'Cuando confirmes un pedido lo verás aquí.',
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
        ScreenHeader(
          eyebrow: 'Vista de usuario',
          title: 'Historial',
          lead: Text.rich(
            TextSpan(
              text: 'Aquí aparecen tus ',
              children: <InlineSpan>[
                TextSpan(
                  text: '${orders.length}',
                  style: const TextStyle(
                    color: CruchefColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(text: ' órdenes entregadas o canceladas.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (orders.isEmpty)
          const EmptyStateCard(
            icon: Icons.history_outlined,
            title: 'Sin historial',
            subtitle: 'Tus órdenes entregadas y canceladas aparecerán aquí.',
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
    required this.ordersCount,
    required this.historyCount,
    required this.onRefresh,
    required this.onUpdateProfileName,
    required this.onUpdateProfileDetails,
    required this.onPickProfilePhoto,
    required this.onSendPasswordReset,
    required this.onLogout,
    required this.profilePhone,
    required this.profilePhotoUrl,
  });

  final User user;
  final int ordersCount;
  final int historyCount;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String displayName) onUpdateProfileName;
  final Future<void> Function({
    required String displayName,
    required String phone,
    required String photoUrl,
  })
  onUpdateProfileDetails;
  final Future<String?> Function() onPickProfilePhoto;
  final Future<void> Function() onSendPasswordReset;
  final Future<void> Function() onLogout;
  final String profilePhone;
  final String profilePhotoUrl;

  @override
  Widget build(BuildContext context) {
    final String displayName = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : 'Cliente CruChef';
    final String email = user.email?.trim() ?? 'Sin correo vinculado';
    final String phone = profilePhone.trim().isNotEmpty
        ? profilePhone.trim()
        : 'No registrado';
    final String photoUrl = profilePhotoUrl.trim();
    final String memberSince = formatProfileDate(user.metadata.creationTime);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      children: <Widget>[
        CruchefSurface(
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CruchefRadii.card),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0x33E65151), Color(0x00121212)],
              ),
            ),
            child: Row(
              children: <Widget>[
                ProfileAvatar(displayName: displayName, photoUrl: photoUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const EyebrowText('Mi cuenta'),
                      const SizedBox(height: 6),
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(color: CruchefColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: ProfileMetric(label: 'Activas', value: '$ordersCount'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ProfileMetric(label: 'Historial', value: '$historyCount'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ProfileInfoCard(
          title: 'Datos de contacto',
          rows: <ProfileRowData>[
            ProfileRowData(label: 'Nombre', value: displayName),
            ProfileRowData(label: 'Correo', value: email),
            ProfileRowData(label: 'Teléfono', value: phone),
            ProfileRowData(label: 'Desde', value: memberSince),
          ],
        ),
        const SizedBox(height: 16),
        CruchefSurface(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Preferencias de cuenta',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              ProfileActionButton(
                icon: Icons.badge_outlined,
                title: 'Editar perfil',
                subtitle: 'Actualiza tu nombre, teléfono y foto.',
                onPressed: () async {
                  final ProfileEditResult? result =
                      await showDialog<ProfileEditResult>(
                        context: context,
                        builder: (BuildContext context) => EditProfileDialog(
                          initialName: displayName,
                          initialPhone: profilePhone,
                          initialPhotoUrl: profilePhotoUrl,
                          onPickPhoto: onPickProfilePhoto,
                        ),
                      );
                  if (result == null || result.displayName.trim().isEmpty) {
                    return;
                  }
                  await onUpdateProfileDetails(
                    displayName: result.displayName,
                    phone: result.phone,
                    photoUrl: result.photoUrl,
                  );
                },
              ),
              const SizedBox(height: 12),
              ProfileActionButton(
                icon: Icons.lock_reset,
                title: 'Cambiar contraseña',
                subtitle: 'Te enviaremos un correo para recuperarla.',
                onPressed: () async {
                  await onSendPasswordReset();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CruchefSurface(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: <Widget>[
              ProfileActionButton(
                icon: Icons.sync,
                title: 'Actualizar datos',
                subtitle: 'Recarga tu perfil y tus compras recientes.',
                onPressed: () {
                  onRefresh();
                },
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  onLogout();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: const Color(0xFFE34B4B),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
