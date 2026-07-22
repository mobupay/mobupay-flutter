import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import 'models.dart';
import 'mobupay_webview.dart';

/// Point d'entrée pour présenter la page de paiement hébergée Mobupay dans une
/// application Flutter. Deux modes :
///
///  - [presentInApp] (recommandé) : la page hébergée s'affiche DANS l'app, via
///    une WebView native (barre d'app + marque marchand, pas de barre d'URL).
///  - [present] : la page hébergée s'ouvre dans le NAVIGATEUR SYSTÈME (Chrome
///    Custom Tabs / ASWebAuthenticationSession). Plus robuste pour la 3DS et sans
///    WebView, mais montre l'URL Mobupay et la croix du navigateur.
///
/// Dans les deux cas, le résultat renvoyé n'est PAS une preuve de paiement : la
/// source de vérité est le webhook signé reçu par VOTRE backend.
class MobupayCheckout {
  /// Présente [checkoutUrl] dans une WebView native plein écran (dans l'app).
  ///
  /// [context] : contexte de navigation (pour pousser l'écran).
  /// [theme] : personnalisation du cadre natif (barre d'app), voir
  /// [MobupayCheckoutTheme]. La page de paiement elle-même n'est pas
  /// personnalisable depuis l'app (page hébergée, agent non-PSP).
  ///
  /// Détecte la fin du parcours par l'URL (succès / échec / annulation /
  /// expiration) sans casser la 3DS. Renvoie un [MobupayCheckoutResult] ;
  /// un retour système (bouton back) équivaut à une annulation.
  static Future<MobupayCheckoutResult> presentInApp({
    required BuildContext context,
    required String checkoutUrl,
    MobupayCheckoutTheme theme = const MobupayCheckoutTheme(),
  }) async {
    final result = await Navigator.of(context).push<MobupayCheckoutResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MobupayCheckoutView(checkoutUrl: checkoutUrl, theme: theme),
      ),
    );
    return result ??
        MobupayCheckoutResult(outcome: MobupayCheckoutOutcome.cancelled);
  }
  /// Ouvre [checkoutUrl] et attend la redirection vers une URL commençant par
  /// [callbackUrlScheme] (schéma d'application, ex. `monapp`, déclaré côté iOS
  /// et Android). Le `redirectUrl` de la session Mobupay doit renvoyer vers ce
  /// schéma (ou un lien universel/app-link routé vers l'app).
  ///
  /// Retourne un [MobupayCheckoutResult]. Le statut lu dans l'URL de retour
  /// n'est PAS une preuve de paiement : confirmez via votre backend (webhook
  /// signé), source de vérité.
  static Future<MobupayCheckoutResult> present({
    required String checkoutUrl,
    required String callbackUrlScheme,
  }) async {
    try {
      final resultUrl = await FlutterWebAuth2.authenticate(
        url: checkoutUrl,
        callbackUrlScheme: callbackUrlScheme,
      );
      final uri = Uri.tryParse(resultUrl);
      final status = uri?.queryParameters['status'];
      return MobupayCheckoutResult(
        outcome: status == 'cancelled'
            ? MobupayCheckoutOutcome.cancelled
            : MobupayCheckoutOutcome.returned,
        reportedStatus: status,
        paymentId: uri?.queryParameters['paymentId'],
        returnUri: uri,
      );
    } on Exception {
      // L'utilisateur a fermé le navigateur système sans terminer.
      return MobupayCheckoutResult(outcome: MobupayCheckoutOutcome.cancelled);
    }
  }
}
