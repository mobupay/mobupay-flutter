/// SDK Flutter Mobupay.
///
/// Deux briques :
///  - [MobupayCheckout] : présente la page de paiement hébergée Mobupay. Deux
///    modes : [MobupayCheckout.presentInApp] (WebView native DANS l'app, barre
///    d'app + marque, recommandé) ou [MobupayCheckout.present] (navigateur
///    système, sans WebView). À utiliser DANS l'application mobile.
///  - [MobupayClient] : client API (créer session/lien, lire un paiement,
///    rembourser). Il utilise la clé secrète `sk_…` : à n'utiliser QUE côté
///    backend ou en développement/test. Ne JAMAIS embarquer une clé `sk_live_`
///    dans une application distribuée (elle serait extractible du binaire).
library mobupay;

export 'src/models.dart';
export 'src/mobupay_client.dart';
export 'src/mobupay_checkout.dart';
export 'src/mobupay_webview.dart';
