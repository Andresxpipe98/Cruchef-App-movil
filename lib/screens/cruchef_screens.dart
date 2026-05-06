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
    required this.onRestaurantSearchChanged,
    required this.onAnalyzeVoiceText,
    required this.onPlaceOrder,
    required this.onRateOrder,
    required this.onRefresh,
    required this.onRefreshProfile,
    required this.onUpdateProfileName,
    required this.onSendPasswordReset,
    required this.onLogout,
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
  final ValueChanged<String> onRestaurantSearchChanged;
  final Future<void> Function() onAnalyzeVoiceText;
  final Future<void> Function() onPlaceOrder;
  final Future<void> Function(OrderRecord order) onRateOrder;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRefreshProfile;
  final Future<void> Function(String displayName) onUpdateProfileName;
  final Future<void> Function() onSendPasswordReset;
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
        firebaseOnline: widget.firebaseOnline,
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
        onRestaurantSearchChanged: widget.onRestaurantSearchChanged,
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
        ordersCount: widget.trackingOrders.length,
        historyCount: widget.historyOrders.length,
        onRefresh: widget.onRefreshProfile,
        onUpdateProfileName: widget.onUpdateProfileName,
        onSendPasswordReset: widget.onSendPasswordReset,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: CruchefPageBackground(
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
    required this.firebaseOnline,
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
    required this.onRestaurantSearchChanged,
    required this.onAnalyzeVoiceText,
    required this.onPlaceOrder,
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
  final ValueChanged<String> onRestaurantSearchChanged;
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
                          const EyebrowText('Vista de usuario'),
                          const SizedBox(height: 8),
                          const Text(
                            'Menu',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text.rich(
                            TextSpan(
                              text: 'Estas viendo el menu de ',
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
                    _RoundIconButton(
                      icon: Icons.qr_code_scanner,
                      onTap: onOpenScanner,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                StatusBanner(isOnline: firebaseOnline),
                const SizedBox(height: 16),
                RestaurantHero(
                  selectedRestaurant: selectedRestaurant,
                  cartCount: cartCount,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: manualQrController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Buscar restaurante o pegar QR',
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
                TextField(
                  controller: voiceController,
                  decoration: InputDecoration(
                    hintText: 'Buscar recomendacion de plato',
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
                  child: restaurants.isEmpty
                      ? const Center(
                          child: Text(
                            'No encontramos restaurantes con esa busqueda.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: restaurants.length,
                          separatorBuilder: (BuildContext context, int index) =>
                              const SizedBox(width: 10),
                          itemBuilder: (BuildContext context, int index) {
                            final RestaurantSummary restaurant =
                                restaurants[index];
                            final bool selected =
                                restaurant.key == selectedRestaurant?.key;
                            return RestaurantPill(
                              label: restaurant.name,
                              selected: selected,
                              onTap: () => onSelectRestaurant(restaurant.key),
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
        ScreenHeader(
          eyebrow: 'Vista de usuario',
          title: 'Historial',
          lead: Text.rich(
            TextSpan(
              text: 'Aqui aparecen tus ',
              children: <InlineSpan>[
                TextSpan(
                  text: '${orders.length}',
                  style: const TextStyle(
                    color: CruchefColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(text: ' ordenes entregadas o canceladas.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
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
    required this.ordersCount,
    required this.historyCount,
    required this.onRefresh,
    required this.onUpdateProfileName,
    required this.onSendPasswordReset,
    required this.onLogout,
  });

  final User user;
  final int ordersCount;
  final int historyCount;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String displayName) onUpdateProfileName;
  final Future<void> Function() onSendPasswordReset;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final String displayName = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : 'Cliente CruChef';
    final String email = user.email?.trim() ?? 'Sin correo vinculado';
    final String phone = user.phoneNumber?.trim().isNotEmpty ?? false
        ? user.phoneNumber!.trim()
        : 'No registrado';
    final String memberSince = formatProfileDate(user.metadata.creationTime);
    final String verificationLabel = user.emailVerified
        ? 'Correo verificado'
        : 'Correo pendiente';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      children: <Widget>[
        CruchefSurface(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 30,
                backgroundColor: CruchefColors.redSoft,
                child: Text(
                  buildInitials(displayName),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const EyebrowText('Perfil'),
                    const SizedBox(height: 6),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 24,
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
            const SizedBox(width: 12),
            Expanded(
              child: ProfileMetric(
                label: 'Estado',
                value: user.emailVerified ? 'OK' : 'Pend.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ProfileInfoCard(
          title: 'Informacion personal',
          rows: <ProfileRowData>[
            ProfileRowData(label: 'Nombre', value: displayName),
            ProfileRowData(label: 'Correo', value: email),
            ProfileRowData(label: 'Telefono', value: phone),
            ProfileRowData(label: 'Verificacion', value: verificationLabel),
            ProfileRowData(label: 'Miembro desde', value: memberSince),
          ],
        ),
        const SizedBox(height: 16),
        CruchefSurface(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Opciones de perfil',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  final String? updatedName = await showDialog<String>(
                    context: context,
                    builder: (BuildContext context) =>
                        EditProfileNameDialog(initialValue: displayName),
                  );
                  if (updatedName == null || updatedName.trim().isEmpty) {
                    return;
                  }
                  await onUpdateProfileName(updatedName);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: CruchefColors.gold,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar nombre'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await onSendPasswordReset();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: CruchefColors.subtleSurface,
                ),
                icon: const Icon(Icons.lock_reset),
                label: const Text('Cambiar contrasena'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CruchefSurface(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: <Widget>[
              FilledButton.icon(
                onPressed: () {
                  onRefresh();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0x2952C483),
                ),
                icon: const Icon(Icons.sync),
                label: const Text('Actualizar perfil'),
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
                label: const Text('Cerrar sesion'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
