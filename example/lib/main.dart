import 'package:flutter/material.dart';
import 'package:mobupay/mobupay.dart';

// Exemple minimal du mode WebView in-app (MobupayCheckout.presentInApp).
// En production, la session est créée par VOTRE backend (avec sk_) qui renvoie
// le checkoutUrl ; ici on la crée dans l'app avec une clé de TEST fournie via
// --dart-define (jamais commité, jamais sk_live_ en prod).
//
// Lancer (tout sur UNE seule ligne sous Git Bash / bash) :
//   flutter run -d <device> --dart-define=MOBUPAY_API_BASE=... --dart-define=MOBUPAY_API_KEY=sk_test_...
//
// Pour tester le cas « email déjà fourni » (champ email masqué sur la page +
// fermeture automatique de la WebView au succès, reçu envoyé par email), ajouter :
//   --dart-define=MOBUPAY_CUSTOMER_EMAIL=ext-robin@needeat.nc
const String kApiBase =
    String.fromEnvironment('MOBUPAY_API_BASE', defaultValue: 'https://api.mobupay.nc');
const String kApiKey = String.fromEnvironment('MOBUPAY_API_KEY');

// Email du client. Vide -> la page hébergée demande l'email et affiche le reçu
// au succès (bouton « Terminé »). Renseigné -> champ email masqué et la WebView
// se ferme automatiquement au succès.
const String kCustomerEmail =
    String.fromEnvironment('MOBUPAY_CUSTOMER_EMAIL', defaultValue: '');

// Mode WebView in-app : le redirectUrl doit être une URL http(s). Quand un email
// est fourni, le serveur y redirige (302) au succès ; la WebView intercepte ce
// départ hors du host Mobupay et se ferme (la page n'est jamais chargée).
const String kReturnUrl = String.fromEnvironment(
  'MOBUPAY_RETURN_URL',
  defaultValue: 'https://example.com/paiement-retour',
);

void main() => runApp(const MobupayExampleApp());

class MobupayExampleApp extends StatelessWidget {
  const MobupayExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Mobupay Example',
      debugShowCheckedModeBanner: false, // masque le bandeau rouge DEBUG
      home: CheckoutPage(),
    );
  }
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String _message = 'Prêt.';
  bool _busy = false;

  Future<void> _payer() async {
    setState(() {
      _busy = true;
      _message = 'Création de la session…';
    });
    final client = MobupayClient(kApiKey, apiBase: kApiBase);
    try {
      // En prod : cet appel se fait côté backend, pas dans l'app.
      final session = await client.createCheckoutSession(
        reference: 'DEMO-${DateTime.now().millisecondsSinceEpoch}',
        amount: MobupayClient.toMinorUnits(5.00, 'EUR'),
        currency: 'EUR',
        redirectUrl: kReturnUrl,
        notificationUrl: 'https://example.com/mobupay-webhook', // requis par l'API
        externalId: 'demo-flutter',
        customerEmail: kCustomerEmail.isEmpty ? null : kCustomerEmail,
      );
      setState(() => _message = 'Ouverture de la page Mobupay…');

      if (!mounted) return;
      // Mode recommandé : la page hébergée s'affiche DANS l'app (WebView native).
      final result = await MobupayCheckout.presentInApp(
        context: context,
        checkoutUrl: session.checkoutUrl,
        theme: const MobupayCheckoutTheme(title: 'Paiement sécurisé'),
      );

      if (result.outcome == MobupayCheckoutOutcome.cancelled) {
        setState(() => _message = 'Retour annulé. Vérification du statut…');
      }
      // Confirmation via l'API (en prod : via votre backend / webhook signé).
      final p = await client.retrievePayment(session.paymentId);
      setState(() => _message = p.status.isPaid
          ? 'PAIEMENT CONFIRMÉ (${p.status.name}) — ${session.paymentId}'
          : 'En attente (${p.status.name}) — ${session.paymentId}');
    } on MobupayException catch (e) {
      setState(() => _message = 'Erreur : ${e.message} '
          '${e.responseBody ?? ''}');
    } finally {
      client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mobupay')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _busy ? null : _payer,
                child: const Text('Payer 5,00 EUR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
