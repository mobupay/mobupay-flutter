import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'models.dart';

/// Écran plein écran qui présente la page de paiement hébergée Mobupay DANS
/// l'application, via une WebView native (pas de navigateur système, pas de
/// barre d'URL). La saisie carte reste sur la page hébergée (widget Monext) :
/// la donnée carte ne touche jamais le code de l'app (agent non-PSP, hors PCI).
///
/// À utiliser via [MobupayCheckout.presentInApp] plutôt que directement.
///
/// Détection de fin de parcours (par URL, sur le host de [checkoutUrl]) :
///  - `/checkout/success`  -> succès. Comportement MIX :
///     * sans email : la page reçu Mobupay s'affiche, l'utilisateur ferme via
///       « Terminé » ;
///     * avec email : le serveur redirige (302) hors du host Mobupay -> on
///       ferme automatiquement (le reçu est envoyé par email).
///  - `/checkout/failed`               -> échec
///  - `/api/internal/checkout-cancel`  -> annulation
///  - `/expired`                       -> expiration
///
/// La 3DS (redirection top-level vers la banque) se produit AVANT le succès et
/// sur un autre host : elle n'est jamais interceptée.
class MobupayCheckoutView extends StatefulWidget {
  final String checkoutUrl;
  final MobupayCheckoutTheme theme;

  const MobupayCheckoutView({
    super.key,
    required this.checkoutUrl,
    this.theme = const MobupayCheckoutTheme(),
  });

  @override
  State<MobupayCheckoutView> createState() => _MobupayCheckoutViewState();
}

class _MobupayCheckoutViewState extends State<MobupayCheckoutView> {
  late final WebViewController _controller;
  late final String _origin;
  bool _loading = true;
  bool _successSeen = false; // /checkout/success atteint
  bool _showDone = false; // page reçu affichée (cas sans email) -> bouton « Terminé »
  bool _finished = false; // garde anti double-fermeture

  @override
  void initState() {
    super.initState();
    _origin = _originOf(widget.checkoutUrl);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigation,
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: _onPageFinished,
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  /// Origin (`scheme://host:port`) d'une URL http(s) ; chaîne vide sinon.
  static String _originOf(String url) {
    final u = Uri.tryParse(url);
    if (u == null || !u.hasScheme || !u.scheme.startsWith('http')) return '';
    return u.origin;
  }

  bool _isMobupay(Uri uri) =>
      _origin.isNotEmpty &&
      uri.hasScheme &&
      uri.scheme.startsWith('http') &&
      uri.origin == _origin;

  NavigationDecision _onNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.navigate;

    if (_isMobupay(uri)) {
      switch (uri.path) {
        case '/checkout/success':
          // Succès : on laisse la page se rendre (cas sans email -> reçu).
          _successSeen = true;
          return NavigationDecision.navigate;
        case '/checkout/failed':
          _finish(MobupayCheckoutOutcome.failed, uri);
          return NavigationDecision.prevent;
        case '/api/internal/checkout-cancel':
          _finish(MobupayCheckoutOutcome.cancelled, uri);
          return NavigationDecision.prevent;
        case '/expired':
          _finish(MobupayCheckoutOutcome.expired, uri);
          return NavigationDecision.prevent;
      }
      return NavigationDecision.navigate;
    }

    // Hors host Mobupay : la 3DS (banque) arrive AVANT le succès -> laisser passer.
    // Un départ hors host APRÈS le succès = 302 vers le redirectUrl marchand (cas
    // email) -> on ferme (le reçu est déjà envoyé par email).
    if (_successSeen) {
      _finish(MobupayCheckoutOutcome.returned, uri);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _onPageFinished(String url) {
    if (mounted) setState(() => _loading = false);
    final uri = Uri.tryParse(url);
    // Cas sans email : la page reçu Mobupay s'est rendue -> proposer « Terminé ».
    if (uri != null && _isMobupay(uri) && uri.path == '/checkout/success') {
      if (mounted) setState(() => _showDone = true);
    }
  }

  /// Ferme l'écran en renvoyant le résultat (une seule fois).
  void _finish(MobupayCheckoutOutcome outcome, Uri? uri) {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pop(
      MobupayCheckoutResult(
        outcome: outcome,
        reportedStatus: uri?.queryParameters['status'],
        paymentId: uri?.queryParameters['paymentId'],
        returnUri: uri,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(t.appBarColor),
        foregroundColor: Color(t.appBarTextColor),
        // Pas de bouton retour auto : en fullscreenDialog, Material insère un
        // CloseButton (police MaterialIcons -> carré si non embarquée) qui ferait
        // doublon avec notre croix themée à droite. On gère la fermeture nous-mêmes.
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (t.showLockIcon) ...[
              // Icône vectorielle autonome (pas de police MaterialIcons requise
              // chez le marchand — le SDK reste auto-suffisant).
              SizedBox(
                width: 18,
                height: 18,
                child: CustomPaint(
                  painter: _LockGlyphPainter(Color(t.appBarTextColor)),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(t.title, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          if (_showDone)
            TextButton(
              onPressed: () => _finish(MobupayCheckoutOutcome.returned, null),
              child: Text(
                'Terminé',
                style: TextStyle(
                  color: Color(t.appBarTextColor),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (t.showCloseButton)
            IconButton(
              tooltip: 'Fermer',
              // Croix vectorielle autonome (pas de police MaterialIcons requise).
              icon: SizedBox(
                width: 22,
                height: 22,
                child: CustomPaint(
                  painter: _CloseGlyphPainter(Color(t.appBarTextColor)),
                ),
              ),
              onPressed: () => _finish(MobupayCheckoutOutcome.cancelled, null),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            LinearProgressIndicator(
              color: Color(t.progressColor ?? t.appBarColor),
              backgroundColor: Colors.transparent,
            ),
        ],
      ),
    );
  }
}

/// Cadenas dessiné en vectoriel (corps + anse), sans dépendre d'une police
/// d'icônes. Trait à la couleur passée.
class _LockGlyphPainter extends CustomPainter {
  final Color color;
  const _LockGlyphPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    final bodyTop = h * 0.46;
    // Corps du cadenas (rectangle arrondi, moitié basse).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.20, bodyTop, w * 0.80, h * 0.92),
        Radius.circular(w * 0.12),
      ),
      p,
    );
    // Anse (arc en U inversé).
    final cx = w / 2;
    final r = w * 0.19;
    final shackle = Path()
      ..moveTo(cx - r, bodyTop)
      ..lineTo(cx - r, h * 0.36)
      ..arcToPoint(
        Offset(cx + r, h * 0.36),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(cx + r, bodyTop);
    canvas.drawPath(shackle, p);
  }

  @override
  bool shouldRepaint(covariant _LockGlyphPainter old) => old.color != color;
}

/// Croix (fermeture) dessinée en vectoriel, sans police d'icônes.
class _CloseGlyphPainter extends CustomPainter {
  final Color color;
  const _CloseGlyphPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final inset = size.width * 0.28;
    canvas.drawLine(
      Offset(inset, inset),
      Offset(size.width - inset, size.height - inset),
      p,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _CloseGlyphPainter old) => old.color != color;
}
