# Changelog — SDK Flutter Mobupay

Le versionnage suit [SemVer](https://semver.org/lang/fr/). Pré-1.0 : l'API publique
peut évoluer (breaking changes signalés ici).

## 0.2.0 — 2026-07-10

Checkout **WebView in-app** (PLAN-260) : la page de paiement hébergée s'affiche
désormais DANS l'application (barre d'app + marque marchand, pas de barre d'URL ni
croix navigateur), au lieu du seul navigateur système.

- **`MobupayCheckout.presentInApp(context, checkoutUrl, theme)`** (recommandé) :
  présente la page hébergée dans un écran natif plein écran (`webview_flutter`).
  - Détection de fin de parcours par URL, sur le host du `checkoutUrl` :
    `/checkout/success` (succès), `/checkout/failed` (échec),
    `/api/internal/checkout-cancel` (annulation), `/expired` (expiration).
  - **Comportement succès (mix)** : si le reçu est envoyé par email (email fourni au
    paiement), le serveur redirige hors host -> fermeture automatique ; sinon la page
    reçu Mobupay s'affiche dans l'app avec un bouton **« Terminé »**.
  - **3DS préservée** : les domaines bancaires (atteints avant le succès, sur un
    autre host) ne sont jamais interceptés.
- **`MobupayCheckoutTheme`** : personnalisation du cadre natif (couleur/texte de la
  barre, titre, bouton fermer, cadenas, couleur de chargement). La page de paiement
  elle-même n'est pas personnalisable depuis l'app (page hébergée, agent non-PSP).
- **`MobupayCheckout.present(...)`** (navigateur système) est **conservé** comme
  alternative. `MobupayCheckoutOutcome` enrichi : `returned` / `failed` / `cancelled`
  / `expired`.
- Dépendance ajoutée : `webview_flutter: ^4.4.0` (résolu 4.14.1). Flutter `>=3.16.0`.
- Icônes de la barre d'app (cadenas, croix de fermeture) dessinées en **vectoriel
  autonome** (`CustomPaint`) au lieu de la police MaterialIcons : le SDK n'exige plus
  `uses-material-design: true` chez le marchand (sinon les icônes s'affichaient en
  carrés). Zéro dépendance ajoutée. `AppBar.automaticallyImplyLeading: false` pour
  supprimer le bouton retour auto (CloseButton Material -> carré, en doublon avec notre
  croix themée).
- `createCheckoutSession` / `createCheckoutLink` acceptent un `customerEmail` optionnel
  (mappé sur le champ API `email`) : si fourni, le champ email n'est pas demandé sur la
  page hébergée et la WebView se ferme automatiquement au succès (reçu envoyé par email).
- `flutter analyze` : 0 issue (SDK + exemple).

Rappel inchangé : le résultat renvoyé n'est PAS une preuve de paiement ; la source de
vérité reste le **webhook signé** reçu côté backend marchand.

## 0.1.0 — 2026-07-02

Version initiale.

- `MobupayCheckout.present(checkoutUrl, callbackUrlScheme)` : ouvre la page de
  paiement hébergée dans le **navigateur système** (ASWebAuthenticationSession /
  Chrome Custom Tabs, via `flutter_web_auth_2`), pas de WebView. Remonte un
  `MobupayCheckoutResult`.
- `MobupayClient` : `createCheckoutSession`, `createCheckoutLink`,
  `retrievePayment`, `refund` (clé `sk_…`, backend / dev-test uniquement).
- Modèles : `CheckoutSession`, `Payment`, `MobupayStatus`, `MobupayCheckoutResult`,
  `MobupayException`. `toMinorUnits` (EUR ×100, XPF ×1).

### Compatibilité (testé / cible)

- **Dart SDK** : développé et analysé avec **Dart 3.10.1** (stable, nov. 2025).
  Contrainte : `>=3.0.0 <4.0.0`.
- **Flutter** : `>=3.10.0`.
- **Dépendances** : `flutter_web_auth_2: ^5.0.0`, `http: ^1.2.0`.
  (Les `flutter_web_auth_2` 3.x utilisent l'ancien embedding Android `Registrar`,
  retiré des Flutter récents -> ne compilent pas sur Flutter 3.38+. `>=5` requis.)

> Si une évolution de Dart/Flutter ou de `flutter_web_auth_2` casse la compat,
> incrémenter la version ici et mettre à jour les contraintes de `pubspec.yaml`.

### À faire (prochaine itération)

- Validation e2e sur device réel (schéma de rappel iOS/Android + acceptation du
  `redirectUrl` custom-scheme par la page hébergée Mobupay).
- Publication sur pub.dev.
