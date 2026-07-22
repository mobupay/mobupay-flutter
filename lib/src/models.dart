// Modèles Mobupay.

/// Exception levée par le SDK (erreur API, réseau, ou parsing).
class MobupayException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? responseBody;

  MobupayException(this.message, {this.statusCode, this.responseBody});

  @override
  String toString() =>
      'MobupayException($message${statusCode != null ? ', HTTP $statusCode' : ''})';
}

/// Statut d'un paiement Mobupay.
enum MobupayStatus {
  pending,
  authorized,
  captured,
  transit,
  failed,
  cancelled,
  refunded,
  unknown;

  static MobupayStatus parse(String? raw) {
    switch (raw) {
      case 'pending':
        return MobupayStatus.pending;
      case 'authorized':
        return MobupayStatus.authorized;
      case 'captured':
        return MobupayStatus.captured;
      case 'transit':
        return MobupayStatus.transit;
      case 'failed':
        return MobupayStatus.failed;
      case 'cancelled':
        return MobupayStatus.cancelled;
      case 'refunded':
        return MobupayStatus.refunded;
      default:
        return MobupayStatus.unknown;
    }
  }

  /// Le paiement est-il abouti (encaissé ou en transit vers le compte) ?
  bool get isPaid =>
      this == MobupayStatus.captured ||
      this == MobupayStatus.authorized ||
      this == MobupayStatus.transit;
}

/// Session de paiement créée via l'API (contient l'URL de la page hébergée).
class CheckoutSession {
  final String paymentId;
  final String checkoutUrl;
  final MobupayStatus status;
  final String? externalId;
  final DateTime? expiresAt;

  CheckoutSession({
    required this.paymentId,
    required this.checkoutUrl,
    required this.status,
    this.externalId,
    this.expiresAt,
  });

  factory CheckoutSession.fromJson(Map<String, dynamic> j) => CheckoutSession(
        paymentId: (j['paymentId'] ?? '') as String,
        // /sessions renvoie checkoutUrl ; /links renvoie linkUrl.
        checkoutUrl: (j['checkoutUrl'] ?? j['linkUrl'] ?? '') as String,
        status: MobupayStatus.parse(j['status'] as String?),
        externalId: j['externalId'] as String?,
        expiresAt: j['expiresAt'] != null
            ? DateTime.tryParse(j['expiresAt'] as String)
            : null,
      );
}

/// Détail d'un paiement (retrievePayment).
class Payment {
  final String paymentId;
  final MobupayStatus status;
  final int? amount; // unité mineure
  final String? currency;
  final String? externalId;
  final Map<String, dynamic> raw;

  Payment({
    required this.paymentId,
    required this.status,
    this.amount,
    this.currency,
    this.externalId,
    this.raw = const {},
  });

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        paymentId: (j['paymentId'] ?? j['id'] ?? '') as String,
        status: MobupayStatus.parse(j['status'] as String?),
        amount: j['amount'] as int?,
        currency: j['currency'] as String?,
        externalId: j['externalId'] as String?,
        raw: j,
      );
}

/// Issue du retour de la page de paiement hébergée dans l'app.
///
/// ATTENTION : aucune de ces valeurs n'est une PREUVE de paiement (le retour
/// navigateur est falsifiable). La source de vérité est le webhook signé reçu
/// côté serveur. Confirmez toujours via votre backend (ou
/// [MobupayClient.retrievePayment] en test) avant de livrer la commande.
///
/// - [returned] : le client est revenu après un parcours abouti (succès).
/// - [failed] : le paiement a échoué (refus carte, etc.).
/// - [cancelled] : le client a fermé la page / abandonné.
/// - [expired] : la session / le lien a expiré.
enum MobupayCheckoutOutcome { returned, failed, cancelled, expired }

class MobupayCheckoutResult {
  final MobupayCheckoutOutcome outcome;

  /// Statut indicatif lu dans l'URL de retour (`?status=`), non fiable.
  final String? reportedStatus;
  final String? paymentId;
  final Uri? returnUri;

  MobupayCheckoutResult({
    required this.outcome,
    this.reportedStatus,
    this.paymentId,
    this.returnUri,
  });
}

/// Personnalisation de l'écran WebView in-app ([MobupayCheckout.presentInApp]).
///
/// Seul le CADRE natif (barre d'app, indicateur de chargement) est personnalisable :
/// la page de paiement elle-même est la page hébergée Mobupay (widget carte Monext),
/// non modifiable depuis l'app (agent non-PSP). Pour thémer la page hébergée
/// (logo/couleurs marchand), c'est un réglage côté backend Mobupay.
class MobupayCheckoutTheme {
  /// Couleur de fond de la barre d'app (défaut : teal Mobupay `#13C1C7`).
  final int appBarColor;

  /// Couleur du texte / des icônes de la barre d'app (défaut : blanc).
  final int appBarTextColor;

  /// Titre de la barre d'app (défaut : « Paiement sécurisé »).
  final String title;

  /// Affiche un bouton de fermeture (croix) dans la barre (défaut : true).
  /// Avant la fin du paiement, il équivaut à une annulation.
  final bool showCloseButton;

  /// Affiche une petite icône cadenas devant le titre (défaut : true).
  final bool showLockIcon;

  /// Couleur de l'indicateur de chargement (défaut : couleur de la barre).
  final int? progressColor;

  const MobupayCheckoutTheme({
    this.appBarColor = 0xFF13C1C7,
    this.appBarTextColor = 0xFFFFFFFF,
    this.title = 'Paiement sécurisé',
    this.showCloseButton = true,
    this.showLockIcon = true,
    this.progressColor,
  });
}
