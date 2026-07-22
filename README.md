# Mobupay — SDK Flutter

Encaissez par carte dans une app Flutter avec Mobupay. Modèle **redirect / page
hébergée** : le client paie sur la page sécurisée Mobupay (widget Monext), et la
commande est confirmée par **webhook signé** côté serveur.

Deux façons de présenter la page hébergée :
- **`presentInApp` (recommandé)** : la page s'affiche **dans l'app**, dans une WebView
  native (ta barre d'app + ta marque, pas de barre d'URL ni croix navigateur).
- **`present`** : la page s'ouvre dans le **navigateur système** (Chrome Custom Tabs /
  ASWebAuthenticationSession). Plus robuste pour la 3DS, mais montre l'URL Mobupay.

Dans les deux cas, la saisie carte reste sur la page hébergée (widget Monext) : la
donnée carte ne touche jamais le code de l'app (Mobupay = agent non-PSP → **pas de
champ carte natif possible**, et ton app reste hors périmètre PCI).

## Modèle de sécurité (à lire avant tout)

- **Ne jamais embarquer de clé `sk_…` dans l'app.** Elle serait extractible du
  binaire. La session de paiement est créée par **votre backend** (avec la clé
  secrète), qui renvoie le `checkoutUrl` à l'app.
- L'app **présente** ce `checkoutUrl` via `MobupayCheckout.present` (navigateur
  système, anti-phishing) et récupère le retour.
- Le statut lu au retour (`?status=`) **n'est pas une preuve de paiement**. La
  vérité vient du **webhook signé** reçu par votre backend. Confirmez la commande
  côté serveur avant livraison.
- `MobupayClient` (clé `sk_…`) est fourni pour le **backend** ou le **dev/test**
  local uniquement.

Ce découpage (secret côté serveur, page hébergée dans le navigateur système) est
le même principe que le SDK mobile Stripe pour les flux redirect / 3DS.

## Installation

```yaml
dependencies:
  mobupay: ^0.2.0
```

`presentInApp` s'appuie sur [`webview_flutter`](https://pub.dev/packages/webview_flutter)
(^4.4.0). `present` (navigateur système) s'appuie sur
[`flutter_web_auth_2`](https://pub.dev/packages/flutter_web_auth_2) (^5.0.0).

## Utilisation recommandée — WebView in-app

```dart
import 'package:mobupay/mobupay.dart';

// 1. VOTRE backend crée la session (avec sk_) et renvoie checkoutUrl.
final checkoutUrl = await monBackend.creerSessionMobupay(montant: 2500);

// 2. La page hébergée s'affiche DANS l'app (WebView native, thémable).
final result = await MobupayCheckout.presentInApp(
  context: context,
  checkoutUrl: checkoutUrl,
  theme: const MobupayCheckoutTheme(
    title: 'Paiement sécurisé',
    appBarColor: 0xFF13C1C7, // ta couleur de marque
  ),
);

// 3. Confirme TOUJOURS via ton backend (webhook signé), pas via result.
if (result.outcome == MobupayCheckoutOutcome.returned) {
  await monBackend.confirmerCommande(); // lit l'état réel (webhook)
}
```

Comportement au succès : si un **email** a été fourni au paiement, le reçu est envoyé
par mail et la WebView se ferme automatiquement ; **sinon** la page reçu Mobupay
s'affiche dans l'app avec un bouton **« Terminé »**. La **3DS** (redirection vers la
banque) est préservée : elle n'est jamais interceptée. Aucune config de schéma /
App Links nécessaire pour ce mode (contrairement au navigateur système ci-dessous).

`MobupayCheckoutTheme` personnalise seulement le **cadre natif** (barre d'app,
chargement). La page de paiement elle-même est la page hébergée Mobupay (non
modifiable depuis l'app).

## Alternative — navigateur système (`present`)

### Méthode de retour : App Links / Universal Links (recommandé)

Pour un retour **fiable** dans l'app, le `redirectUrl` de la session doit être une
**URL `https` que votre app revendique** (Android App Links / iOS Universal Links) :
- Une URL `https` se déclenche toujours dans le navigateur, et l'OS la **route vers
  l'app** au lieu de l'ouvrir dans le navigateur → retour automatique.
- Setup : héberger `/.well-known/assetlinks.json` (Android) et
  `apple-app-site-association` (iOS) sur le domaine du `redirectUrl`, avec
  l'empreinte de signature de l'app. Puis déclarer l'`intent-filter`
  `android:autoVerify="true"` (Android) et l'`associated domain` (iOS).

Passez alors `callbackUrlScheme: 'https'` et un `redirectUrl` de la forme
`https://votre-domaine/paiement-retour`.

### Schéma custom (dépannage / test rapide seulement)

Un schéma custom (`monapp://`) est plus simple à câbler mais **peu fiable** :
Chrome Custom Tabs bloque souvent la navigation vers un schéma externe, et le
retour peut ne pas se déclencher. À réserver aux essais.

- **Android** : activité de callback dans `AndroidManifest.xml` avec
  `<data android:scheme="monapp" />`.
- **iOS** : déclarer le schéma d'URL dans `Info.plist`.

### Utilisation (navigateur système)

```dart
import 'package:mobupay/mobupay.dart';

// 1. Votre backend crée la session (avec sk_) et renvoie checkoutUrl.
//    redirectUrl = un schéma de VOTRE app, ex. 'monapp://paiement-retour'.
final checkoutUrl = await monBackend.creerSessionMobupay(montant: 2500);

// 2. L'app présente la page hébergée dans le navigateur système.
final result = await MobupayCheckout.present(
  checkoutUrl: checkoutUrl,
  callbackUrlScheme: 'monapp',
);

// 3. Confirmez TOUJOURS via votre backend (webhook signé), pas via result.reportedStatus.
if (result.outcome == MobupayCheckoutOutcome.returned) {
  await monBackend.confirmerCommande(); // lit l'état réel (webhook)
}
```

## Client API (backend / dev-test uniquement)

```dart
final client = MobupayClient('sk_test_…'); // JAMAIS sk_live_ dans une app distribuée

final session = await client.createCheckoutSession(
  reference: 'CMD-1042',
  amount: MobupayClient.toMinorUnits(25.00, 'EUR'), // 2500
  currency: 'EUR',
  redirectUrl: 'monapp://paiement-retour',
  externalId: '1042',
);
// session.checkoutUrl -> à présenter via MobupayCheckout.present

final paiement = await client.retrievePayment(session.paymentId);
if (paiement.status.isPaid) { /* … */ }

await client.refund(session.paymentId);          // total
await client.refund(session.paymentId, amount: 1000); // partiel (10,00 EUR)
```

## Devises

EUR et XPF (montants en unité mineure : centimes EUR, XPF sans décimale). Utilisez
`MobupayClient.toMinorUnits`.

## Statut

Version 0.2.0 (checkout WebView in-app, PLAN-260). `flutter analyze` : 0 issue.
**Validé e2e sur émulateur Android le 2026-07-10** (mode `presentInApp`) : paiement
carte Monext, cas « email fourni » (champ masqué + fermeture auto) et cas « sans
email » (reçu in-app + « Terminé »), icônes vectorielles OK. Publication pub.dev à
venir (cf. `CHANGELOG.md`).
