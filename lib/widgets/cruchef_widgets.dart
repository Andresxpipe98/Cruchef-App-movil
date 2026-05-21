part of '../main.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key, required this.onDetected});

  final ValueChanged<String> onDetected;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.lead,
  });

  final String eyebrow;
  final String title;
  final Widget lead;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        EyebrowText(eyebrow),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 12),
        DefaultTextStyle(
          style: const TextStyle(
            color: CruchefColors.muted,
            fontSize: 16,
            height: 1.55,
          ),
          child: lead,
        ),
      ],
    );
  }
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;
  bool _hasPermission = false;
  bool _isPreparing = true;
  PermissionStatus _permissionStatus = PermissionStatus.denied;

  Future<void> _prepareScanner() async {
    PermissionStatus status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isPreparing = false;
      _hasPermission = status.isGranted;
      _permissionStatus = status;
    });

    if (status.isGranted) {
      await _startScanner();
    } else {
      await _stopScanner();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareScanner();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startScanner() async {
    try {
      await _controller.start();
    } catch (_) {}
  }

  Future<void> _stopScanner() async {
    try {
      await _controller.stop();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_hasPermission || !_mountedForLifecycle) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _startScanner();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _stopScanner();
    }
  }

  bool get _mountedForLifecycle => mounted && !_handled;

  void _handleCode(String? value) {
    if (_handled || value == null || value.trim().isEmpty) {
      return;
    }
    _handled = true;
    _stopScanner();
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
      body: _isPreparing
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE34B4B)),
            )
          : !_hasPermission
          ? ScannerPermissionCard(
              permissionStatus: _permissionStatus,
              onRetry: _prepareScanner,
              onOpenSettings: () async {
                await openAppSettings();
              },
            )
          : Stack(
              fit: StackFit.expand,
              children: <Widget>[
                MobileScanner(
                  controller: _controller,
                  onDetect: (BarcodeCapture capture) {
                    final String? value = capture.barcodes.isEmpty
                        ? null
                        : capture.barcodes.first.rawValue;
                    _handleCode(value);
                  },
                ),
                const IgnorePointer(child: _ScannerOverlay()),
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Apunta la cámara al QR del restaurante.',
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          'Escanea el QR para entrar directo al restaurante',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await _controller.toggleTorch();
                          },
                          icon: const Icon(Icons.flashlight_on_outlined),
                          label: const Text('Linterna'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double frameSize = constraints.maxWidth < 360
            ? constraints.maxWidth * 0.72
            : constraints.maxWidth * 0.68;
        final double clampedSize = frameSize.clamp(220.0, 320.0).toDouble();

        return Center(
          child: Container(
            width: clampedSize,
            height: clampedSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xAAFFFFFF), width: 1.4),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: const <Widget>[
                _ScannerCorner(alignment: Alignment.topLeft),
                _ScannerCorner(alignment: Alignment.topRight),
                _ScannerCorner(alignment: Alignment.bottomLeft),
                _ScannerCorner(alignment: Alignment.bottomRight),
                _ScannerScanLine(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScannerCorner extends StatelessWidget {
  const _ScannerCorner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final bool isTop = alignment.y < 0;
    final bool isLeft = alignment.x < 0;

    return Align(
      alignment: alignment,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: isTop && isLeft ? const Radius.circular(22) : Radius.zero,
            topRight: isTop && !isLeft
                ? const Radius.circular(22)
                : Radius.zero,
            bottomLeft: !isTop && isLeft
                ? const Radius.circular(22)
                : Radius.zero,
            bottomRight: !isTop && !isLeft
                ? const Radius.circular(22)
                : Radius.zero,
          ),
          border: Border(
            top: isTop
                ? const BorderSide(color: Color(0xFFE34B4B), width: 4)
                : BorderSide.none,
            left: isLeft
                ? const BorderSide(color: Color(0xFFE34B4B), width: 4)
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(color: Color(0xFFE34B4B), width: 4)
                : BorderSide.none,
            bottom: !isTop
                ? const BorderSide(color: Color(0xFFE34B4B), width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ScannerScanLine extends StatefulWidget {
  const _ScannerScanLine();

  @override
  State<_ScannerScanLine> createState() => _ScannerScanLineState();
}

class _ScannerScanLineState extends State<_ScannerScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (BuildContext context, Widget? child) {
        return Align(
          alignment: Alignment(0, (_animationController.value * 1.6) - 0.8),
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 3,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: <Color>[
              Colors.transparent,
              Color(0xFFFF8C42),
              Color(0xFFE34B4B),
              Colors.transparent,
            ],
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x66E34B4B), blurRadius: 12),
          ],
        ),
      ),
    );
  }
}

class CruchefBrandMark extends StatelessWidget {
  const CruchefBrandMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFE34B4B), Color(0xFFFF8C42)],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x44E34B4B),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: Image.asset(
              'assets/images/logo_cruchef.png',
              width: size * 0.72,
              height: size * 0.72,
              fit: BoxFit.contain,
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
          CruchefBrandMark(size: 88),
          SizedBox(height: 20),
          Text(
            'BIENVENIDO',
            style: TextStyle(
              color: CruchefColors.red,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'CruChef',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              height: 0.95,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Ordena más rápido con QR, seguimiento y tu perfil centralizado.',
            style: TextStyle(
              color: CruchefColors.muted,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          SizedBox(height: 18),
          FeatureTile(
            icon: Icons.qr_code_scanner,
            text:
                'Escanea restaurantes, revisa platos y pide desde el celular.',
          ),
          SizedBox(height: 14),
          FeatureTile(
            icon: Icons.receipt_long,
            text: 'Sigue tus órdenes y califica las entregadas.',
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
    required this.errorMessage,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onLogin,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isBusy;
  final String? errorMessage;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: CruchefSurface(
          radius: CruchefRadii.authCard,
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: const <Widget>[
                  CruchefBrandMark(size: 44),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'CruChef',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
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
              if (errorMessage != null) ...<Widget>[
                const SizedBox(height: 14),
                StatusMessage(
                  message: errorMessage!,
                  tone: StatusMessageTone.error,
                ),
              ],
              const SizedBox(height: 18),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  suffixIcon: IconButton(
                    tooltip: obscurePassword
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    onPressed: onTogglePassword,
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: isBusy ? null : () => onLogin(),
                child: Text(isBusy ? 'Conectando...' : 'Entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum StatusMessageTone { success, error, warning }

class StatusMessage extends StatelessWidget {
  const StatusMessage({super.key, required this.message, required this.tone});

  final String message;
  final StatusMessageTone tone;

  @override
  Widget build(BuildContext context) {
    final Color background = switch (tone) {
      StatusMessageTone.success => CruchefColors.greenSoft,
      StatusMessageTone.error => CruchefColors.redSoft,
      StatusMessageTone.warning => const Color(0x1FFFD166),
    };
    final Color foreground = switch (tone) {
      StatusMessageTone.success => CruchefColors.green,
      StatusMessageTone.error => CruchefColors.error,
      StatusMessageTone.warning => const Color(0xFFFFD979),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(CruchefRadii.field),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: foreground,
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
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
    return CruchefSurface(
      padding: const EdgeInsets.all(18),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: CruchefDesign.redGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.restaurant_menu, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      selectedRestaurant?.name ?? 'Sin restaurantes',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.06,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      selectedRestaurant == null
                          ? 'No hay platos cargados.'
                          : '${selectedRestaurant!.dishes.length} platos disponibles',
                      style: const TextStyle(
                        color: CruchefColors.muted,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                constraints: const BoxConstraints(minWidth: 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x1FFF4B2F),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x36FF4B2F)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.shopping_bag_outlined, size: 17),
                    const SizedBox(width: 7),
                    Text(
                      '$cartCount',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _HeroMetaPill(
                icon: Icons.room_service_outlined,
                label: selectedRestaurant == null
                    ? 'Sin menu'
                    : '${selectedRestaurant!.dishes.length} platos',
              ),
              _HeroMetaPill(
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

class _HeroMetaPill extends StatelessWidget {
  const _HeroMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CruchefColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: CruchefColors.gold),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
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
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.96, end: selected ? 1.08 : 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        builder: (BuildContext context, double scale, Widget? child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: SizedBox(
          width: 88,
          height: 96,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 58 : 52,
                height: selected ? 58 : 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected ? CruchefDesign.redGradient : null,
                  color: selected ? null : const Color(0xFF333333),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: selected
                          ? const Color(0x66E34B4B)
                          : const Color(0x1FFFFFFF),
                      blurRadius: selected ? 16 : 1,
                      offset: selected ? const Offset(0, 8) : Offset.zero,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    categoryEmoji(category),
                    style: const TextStyle(fontSize: 25),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 82,
                child: Text(
                  categoryLabel(category),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected ? CruchefColors.text : CruchefColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QrAccessCard extends StatelessWidget {
  const QrAccessCard({super.key, required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onScan,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: CruchefDesign.redGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x44E34B4B),
              blurRadius: 24,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0x22FFFFFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: const Icon(Icons.qr_code_scanner, size: 32),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Escanear QR del restaurante',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Abre directo el menú publicado en la página web.',
                    style: TextStyle(color: Colors.white70, height: 1.35),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward),
          ],
        ),
      ),
    );
  }
}

class CartShortcutButton extends StatelessWidget {
  const CartShortcutButton({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
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
          color: CruchefColors.subtleSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CruchefColors.border),
        ),
        child: Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          child: const Icon(Icons.shopping_bag_outlined),
        ),
      ),
    );
  }
}

class RestaurantSelectionPanel extends StatefulWidget {
  const RestaurantSelectionPanel({
    super.key,
    required this.restaurants,
    required this.selectedRestaurant,
    required this.onSelectRestaurant,
  });

  final List<RestaurantSummary> restaurants;
  final RestaurantSummary? selectedRestaurant;
  final ValueChanged<String> onSelectRestaurant;

  @override
  State<RestaurantSelectionPanel> createState() =>
      _RestaurantSelectionPanelState();
}

class _RestaurantSelectionPanelState extends State<RestaurantSelectionPanel> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    if (widget.restaurants.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.storefront_outlined,
        title: 'Sin restaurantes visibles',
        subtitle: 'Busca por nombre o escanea el QR publicado en la web.',
      );
    }

    return CruchefSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(
            title: 'Selecciona restaurante',
            subtitle: Text('Toca una tarjeta para abrir su menú.'),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int columns = constraints.maxWidth >= 720 ? 3 : 1;
              const int initialCount = 4;
              final List<RestaurantSummary> visibleRestaurants = _showAll
                  ? widget.restaurants
                  : widget.restaurants
                        .take(initialCount)
                        .toList(growable: false);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visibleRestaurants.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 94,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final RestaurantSummary restaurant =
                      visibleRestaurants[index];
                  final bool selected =
                      restaurant.key == widget.selectedRestaurant?.key;
                  return RestaurantSelectionCard(
                    restaurant: restaurant,
                    selected: selected,
                    onTap: () => widget.onSelectRestaurant(restaurant.key),
                  );
                },
              );
            },
          ),
          if (widget.restaurants.length > 4) ...<Widget>[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _showAll = !_showAll;
                });
              },
              icon: Icon(_showAll ? Icons.expand_less : Icons.expand_more),
              label: Text(
                _showAll
                    ? 'Ver menos restaurantes'
                    : 'Ver más restaurantes (${widget.restaurants.length})',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RestaurantSelectionCard extends StatelessWidget {
  const RestaurantSelectionCard({
    super.key,
    required this.restaurant,
    required this.selected,
    required this.onTap,
  });

  final RestaurantSummary restaurant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: selected ? CruchefDesign.redGradient : null,
          color: selected ? null : CruchefColors.subtleSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? CruchefColors.gold : CruchefColors.strongBorder,
            width: selected ? 1.4 : 1,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 24,
              backgroundColor: selected
                  ? const Color(0x2E000000)
                  : const Color(0x1FFFD166),
              child: Text(
                categoryEmoji(
                  restaurant.dishes.isEmpty
                      ? 'all'
                      : restaurant.dishes.first.categoryId,
                ),
                style: const TextStyle(fontSize: 21),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${restaurant.dishes.length} platos disponibles',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white70 : CruchefColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.arrow_forward_ios,
              size: selected ? 22 : 16,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class RestaurantPill extends StatelessWidget {
  const RestaurantPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CruchefRadii.pill),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: selected ? CruchefDesign.redGradient : null,
          color: selected ? null : CruchefColors.subtleSurface,
          borderRadius: BorderRadius.circular(CruchefRadii.pill),
          border: Border.all(
            color: selected ? Colors.transparent : CruchefColors.strongBorder,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: CruchefColors.text,
            fontWeight: FontWeight.w700,
          ),
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
    required this.onAddToCart,
  });

  final List<Dish> dishes;
  final int columns;
  final ValueChanged<Dish> onAddToCart;

  @override
  Widget build(BuildContext context) {
    if (dishes.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.search_off,
        title: 'No hay platos en esta categoría',
        subtitle: 'Prueba con otro restaurante o categoría.',
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dishes.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: 328,
        mainAxisSpacing: 28,
        crossAxisSpacing: 18,
      ),
      itemBuilder: (BuildContext context, int index) {
        final Dish dish = dishes[index];
        return PolishedDishCard(dish: dish, onAdd: () => onAddToCart(dish));
      },
    );
  }
}

class DishCard extends StatelessWidget {
  const DishCard({super.key, required this.dish, required this.onAdd});

  final Dish dish;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 44),
      child: SizedBox(
        height: 284,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: <Widget>[
            Positioned.fill(
              child: CruchefSurface(
                padding: const EdgeInsets.fromLTRB(16, 70, 16, 16),
                radius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      dish.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatPrice(dish.price),
                      style: const TextStyle(
                        color: CruchefColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      dish.rating > 0
                          ? '★ ${dish.rating.toStringAsFixed(1)}'
                          : 'Sin calificaciones',
                      style: TextStyle(
                        color: dish.rating > 0
                            ? const Color(0xFFFFBE0B)
                            : const Color(0xFF8A8A8A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      dish.restaurantName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CruchefColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(top: -44, child: DishImageBadge(dish: dish)),
          ],
        ),
      ),
    );
  }
}

class DishImageBadge extends StatelessWidget {
  const DishImageBadge({super.key, required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Container(
      width: 118,
      height: 118,
      decoration: const BoxDecoration(
        color: CruchefColors.subtleSurface,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          categoryEmoji(dish.categoryId),
          style: const TextStyle(fontSize: 48),
        ),
      ),
    );

    if (dish.imageUrl.isEmpty) {
      return fallback;
    }

    return Container(
      width: 128,
      height: 128,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Image.network(
        dish.imageUrl,
        fit: BoxFit.contain,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                fallback,
      ),
    );
  }
}

class PolishedDishCard extends StatelessWidget {
  const PolishedDishCard({super.key, required this.dish, required this.onAdd});

  final Dish dish;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 306,
        child: CruchefSurface(
          padding: const EdgeInsets.all(14),
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PolishedDishImage(dish: dish),
              const SizedBox(height: 12),
              Text(
                dish.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      formatPrice(dish.price),
                      style: const TextStyle(
                        color: CruchefColors.gold,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x1FF5B942),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      dish.rating > 0
                          ? '★ ${dish.rating.toStringAsFixed(1)}'
                          : 'Nuevo',
                      style: TextStyle(
                        color: dish.rating > 0
                            ? CruchefColors.gold
                            : CruchefColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dish.restaurantName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CruchefColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Agregar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolishedDishImage extends StatelessWidget {
  const _PolishedDishImage({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Container(
      height: 112,
      decoration: BoxDecoration(
        color: CruchefColors.subtleSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CruchefColors.border),
      ),
      child: Center(
        child: Text(
          categoryEmoji(dish.categoryId),
          style: const TextStyle(fontSize: 46),
        ),
      ),
    );

    if (dish.imageUrl.isEmpty) {
      return fallback;
    }

    return Container(
      height: 112,
      decoration: BoxDecoration(
        color: CruchefColors.subtleSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CruchefColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        dish.imageUrl,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                fallback,
      ),
    );
  }
}

class CartPanel extends StatelessWidget {
  const CartPanel({
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
    if (entries.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.shopping_cart_outlined,
        title: 'Carrito vacío',
        subtitle: 'Agrega platos para crear tu pedido.',
      );
    }

    return CruchefSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Tu pedido',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ajusta las cantidades antes de confirmar.',
            style: TextStyle(color: CruchefColors.muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCancelCart,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancelar carrito'),
          ),
          const SizedBox(height: 16),
          ...entries.map(
            (CartEntry entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CartEntryTile(
                entry: entry,
                onAdd: () => onAddToCart(entry.dish),
                onRemove: () => onRemoveFromCart(entry.dish),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: notesController,
            maxLines: 3,
            maxLength: 250,
            decoration: const InputDecoration(
              labelText: 'Detalles para el restaurante',
              hintText: 'Mesa, nombre, hora de retiro, sin cebolla...',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            onChanged: onNotesChanged,
          ),
          const SizedBox(height: 10),
          const Text(
            'Método de pago',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...PaymentMethod.values.map(
            (PaymentMethod method) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PaymentMethodTile(
                method: method,
                selected: method == selectedPaymentMethod,
                onTap: () => onSelectPaymentMethod(method),
              ),
            ),
          ),
          const SizedBox(height: 6),
          PaymentDetailsForm(
            selectedPaymentMethod: selectedPaymentMethod,
            paymentNameController: paymentNameController,
            paymentDocumentController: paymentDocumentController,
            paymentPhoneController: paymentPhoneController,
            paymentReferenceController: paymentReferenceController,
            paymentCardNumberController: paymentCardNumberController,
            paymentCardExpiryController: paymentCardExpiryController,
            paymentCardCvvController: paymentCardCvvController,
            onChanged: onNotesChanged,
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
          FilledButton.icon(
            onPressed: () => onPlaceOrder(),
            icon: const Icon(Icons.shopping_bag),
            label: const Text('Confirmar pedido'),
          ),
        ],
      ),
    );
  }
}

class CartEntryTile extends StatelessWidget {
  const CartEntryTile({
    super.key,
    required this.entry,
    required this.onAdd,
    required this.onRemove,
  });

  final CartEntry entry;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CruchefColors.subtleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CruchefColors.strongBorder),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.dish.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatPrice(entry.dish.price)} c/u',
                  style: const TextStyle(
                    color: CruchefColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          QuantityStepper(
            quantity: entry.quantity,
            onAdd: onAdd,
            onRemove: onRemove,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 82,
            child: Text(
              formatPrice(entry.total),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: CruchefColors.surface,
        borderRadius: BorderRadius.circular(CruchefRadii.pill),
        border: Border.all(color: CruchefColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            onPressed: onRemove,
            icon: const Icon(Icons.remove, size: 18),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}

class PaymentDetailsForm extends StatelessWidget {
  const PaymentDetailsForm({
    super.key,
    required this.selectedPaymentMethod,
    required this.paymentNameController,
    required this.paymentDocumentController,
    required this.paymentPhoneController,
    required this.paymentReferenceController,
    required this.paymentCardNumberController,
    required this.paymentCardExpiryController,
    required this.paymentCardCvvController,
    required this.onChanged,
  });

  final PaymentMethod selectedPaymentMethod;
  final TextEditingController paymentNameController;
  final TextEditingController paymentDocumentController;
  final TextEditingController paymentPhoneController;
  final TextEditingController paymentReferenceController;
  final TextEditingController paymentCardNumberController;
  final TextEditingController paymentCardExpiryController;
  final TextEditingController paymentCardCvvController;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextField(
          controller: paymentNameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre de quien paga',
            prefixIcon: Icon(Icons.person_outline),
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: paymentPhoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: selectedPaymentMethod == PaymentMethod.transfer
                ? 'Numero Nequi o telefono de contacto'
                : 'Telefono de contacto',
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
          onChanged: onChanged,
        ),
        if (selectedPaymentMethod == PaymentMethod.card) ...<Widget>[
          const SizedBox(height: 12),
          TextField(
            controller: paymentDocumentController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Documento del titular',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: paymentCardNumberController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Numero de tarjeta',
              hintText: '1234 5678 9012 3456',
              prefixIcon: Icon(Icons.credit_card),
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: paymentCardExpiryController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Vencimiento',
                    hintText: 'MM/AA',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: paymentCardCvvController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'CVV',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ],
        if (selectedPaymentMethod == PaymentMethod.transfer) ...<Widget>[
          const SizedBox(height: 12),
          TextField(
            controller: paymentReferenceController,
            decoration: InputDecoration(
              labelText: 'Referencia o comprobante Nequi',
              hintText: 'Numero de aprobacion o comprobante',
              prefixIcon: const Icon(Icons.receipt_long_outlined),
            ),
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }
}

class PaymentMethodTile extends StatelessWidget {
  const PaymentMethodTile({
    super.key,
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? CruchefColors.redSoft : CruchefColors.subtleSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? CruchefColors.red : CruchefColors.strongBorder,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              method.icon,
              color: selected ? CruchefColors.gold : Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    method.label,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    method.description,
                    style: const TextStyle(
                      color: CruchefColors.muted,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? CruchefColors.gold : CruchefColors.dim,
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
    return CruchefSurface(
      padding: const EdgeInsets.all(19),
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
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatOrderTime(order.createdAt),
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
              OrderDishBadge(order: order),
              const SizedBox(width: 12),
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
              InfoPill(
                icon: parsePaymentMethod(order.paymentMethod).icon,
                label: parsePaymentMethod(order.paymentMethod).label,
              ),
            ],
          ),
        ],
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
    return CruchefSurface(
      padding: const EdgeInsets.all(19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  order.restaurantName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
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
              OrderDishBadge(order: order),
              const SizedBox(width: 12),
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
          const SizedBox(height: 12),
          InfoPill(
            icon: parsePaymentMethod(order.paymentMethod).icon,
            label: parsePaymentMethod(order.paymentMethod).label,
          ),
          if (onRate != null) ...<Widget>[
            const SizedBox(height: 14),
            FilledButton(onPressed: onRate, child: const Text('Calificar')),
          ],
        ],
      ),
    );
  }
}

class OrderDishBadge extends StatelessWidget {
  const OrderDishBadge({super.key, required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0x1FFFD166),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CruchefColors.border),
      ),
      child: Center(
        child: Text(
          categoryEmoji(order.categoryId),
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );

    if (order.dishImageUrl.isEmpty) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        order.dishImageUrl,
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                fallback,
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.displayName,
    required this.photoUrl,
  });

  final String displayName;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? image = photoUrl.isEmpty
        ? null
        : NetworkImage(photoUrl);
    return CircleAvatar(
      radius: 34,
      backgroundColor: CruchefColors.red,
      backgroundImage: image,
      child: image == null
          ? Text(
              buildInitials(displayName),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            )
          : null,
    );
  }
}

class ProfileInfoCard extends StatelessWidget {
  const ProfileInfoCard({super.key, required this.title, required this.rows});

  final String title;
  final List<ProfileRowData> rows;

  @override
  Widget build(BuildContext context) {
    return CruchefSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
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
                      style: const TextStyle(color: CruchefColors.muted),
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
    );
  }
}

class ProfileMetric extends StatelessWidget {
  const ProfileMetric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return CruchefSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: CruchefColors.muted)),
        ],
      ),
    );
  }
}

class ProfileActionButton extends StatelessWidget {
  const ProfileActionButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CruchefColors.subtleSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CruchefColors.strongBorder),
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0x1FFFD166),
              child: Icon(icon, color: CruchefColors.gold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: CruchefColors.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: CruchefColors.muted),
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
      OrderStatus.pending => const Color(0x1FE65151),
      OrderStatus.accepted => const Color(0x1FFFD166),
      OrderStatus.preparing => const Color(0x1FFFD166),
      OrderStatus.ready => const Color(0x1FFFD166),
      OrderStatus.delivered => const Color(0x2952C483),
      OrderStatus.cancelled => const Color(0x14FFFFFF),
    };
    final Color foreground = switch (status) {
      OrderStatus.pending => CruchefColors.error,
      OrderStatus.accepted => CruchefColors.gold,
      OrderStatus.preparing => CruchefColors.gold,
      OrderStatus.ready => CruchefColors.gold,
      OrderStatus.delivered => CruchefColors.green,
      OrderStatus.cancelled => const Color(0xFFC7C7C7),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
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

    return Column(
      children: <Widget>[
        Row(
          children: List<Widget>.generate(steps.length, (int index) {
            final bool active = activeIndex >= index;
            return Expanded(
              child: Container(
                height: 8,
                margin: EdgeInsets.only(
                  right: index == steps.length - 1 ? 0 : 8,
                ),
                decoration: BoxDecoration(
                  gradient: active ? CruchefDesign.redGradient : null,
                  color: active ? null : Colors.white10,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: active
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x33FF4B2F),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List<Widget>.generate(steps.length, (int index) {
            final bool active = activeIndex >= index;
            return Expanded(
              child: Container(
                height: 18,
                margin: EdgeInsets.only(
                  right: index == steps.length - 1 ? 0 : 8,
                ),
                alignment: Alignment.topCenter,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    steps[index].label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 11,
                      color: active ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
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
  const ScannerPermissionCard({
    super.key,
    required this.permissionStatus,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final PermissionStatus permissionStatus;
  final Future<void> Function() onRetry;
  final Future<void> Function() onOpenSettings;

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
              children: <Widget>[
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0x22E34B4B),
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFFE34B4B),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Permiso de cámara requerido',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  permissionStatus.isPermanentlyDenied ||
                          permissionStatus.isRestricted
                      ? 'Android bloqueó la cámara para CruChef. Abre ajustes y habilita el permiso manualmente.'
                      : 'Acepta el permiso del sistema para leer el QR del restaurante.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, height: 1.4),
                ),
                const SizedBox(height: 16),
                if (!(permissionStatus.isPermanentlyDenied ||
                    permissionStatus.isRestricted))
                  FilledButton.icon(
                    onPressed: () async {
                      await onRetry();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE34B4B),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Permitir cámara'),
                  ),
                if (!(permissionStatus.isPermanentlyDenied ||
                    permissionStatus.isRestricted))
                  const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    await onOpenSettings();
                  },
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(
                    permissionStatus.isPermanentlyDenied ||
                            permissionStatus.isRestricted
                        ? 'Abrir ajustes de permisos'
                        : 'Abrir ajustes',
                  ),
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
  const FeatureTile({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CruchefColors.subtleSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CruchefColors.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: CruchefColors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: CruchefColors.muted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onTap});

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
          color: CruchefColors.subtleSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CruchefColors.border),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _RoundIconButton extends RoundIconButton {
  const _RoundIconButton({required super.icon, required super.onTap});
}

class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CruchefColors.subtleSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CruchefColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: CruchefColors.gold),
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
        color: CruchefColors.subtleSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CruchefColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: CruchefColors.muted),
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
            decoration: const InputDecoration(labelText: 'Comentario'),
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

class CruchefSnackBarContent extends StatelessWidget {
  const CruchefSnackBarContent({
    super.key,
    required this.message,
    required this.backgroundColor,
  });

  final String message;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bool isSuccess = backgroundColor == const Color(0xFF163928);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isSuccess ? const Color(0xFF163928) : const Color(0xFF4C1D1D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSuccess ? const Color(0x6652C483) : const Color(0x66E65151),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white10,
            child: Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: isSuccess ? CruchefColors.green : CruchefColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
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

class CameraPermissionDialog extends StatelessWidget {
  const CameraPermissionDialog({
    super.key,
    required this.isPermanentlyDenied,
    required this.onOpenSettings,
  });

  final bool isPermanentlyDenied;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Permiso de cámara'),
      content: Text(
        isPermanentlyDenied
            ? 'La cámara está bloqueada para CruChef. Activa el permiso desde ajustes.'
            : 'CruChef necesita la cámara para escanear el QR del restaurante.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        if (isPermanentlyDenied)
          FilledButton(
            onPressed: () async {
              await onOpenSettings();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Abrir ajustes'),
          )
        else
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
      ],
    );
  }
}

class ProfileEditResult {
  const ProfileEditResult({
    required this.displayName,
    required this.phone,
    required this.photoUrl,
  });

  final String displayName;
  final String phone;
  final String photoUrl;
}

class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({
    super.key,
    required this.initialName,
    required this.initialPhone,
    required this.initialPhotoUrl,
    required this.onPickPhoto,
  });

  final String initialName;
  final String initialPhone;
  final String initialPhotoUrl;
  final Future<String?> Function() onPickPhoto;

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _phoneController = TextEditingController(
    text: widget.initialPhone,
  );
  late final TextEditingController _photoController = TextEditingController(
    text: widget.initialPhotoUrl,
  );
  String _photoUrl = '';

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.initialPhotoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar perfil'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre visible'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CruchefColors.subtleSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: CruchefColors.strongBorder),
              ),
              child: Row(
                children: <Widget>[
                  ProfileAvatar(
                    displayName: _nameController.text,
                    photoUrl: _photoUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final String? photoUrl = await widget.onPickPhoto();
                        if (photoUrl == null || !mounted) {
                          return;
                        }
                        setState(() {
                          _photoUrl = photoUrl;
                          _photoController.text = photoUrl;
                        });
                      },
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Subir foto'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              ProfileEditResult(
                displayName: _nameController.text.trim(),
                phone: _phoneController.text.trim(),
                photoUrl: _photoController.text.trim(),
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
