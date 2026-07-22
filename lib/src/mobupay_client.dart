import 'dart:convert';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Client de l'API Mobupay.
///
/// SÉCURITÉ : utilise la clé secrète `sk_…`. À n'utiliser QUE côté backend ou en
/// développement/test. NE JAMAIS embarquer une clé `sk_live_` dans une app
/// distribuée : côté application mobile, la session doit être créée par VOTRE
/// backend, qui renvoie le `checkoutUrl` à présenter via [MobupayCheckout].
class MobupayClient {
  final String apiKey;
  final String apiBase;
  final http.Client _http;

  MobupayClient(
    this.apiKey, {
    this.apiBase = 'https://api.mobupay.nc',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// Convertit un montant décimal en unité mineure (centimes EUR ; XPF sans décimale).
  static int toMinorUnits(num amount, String currency) =>
      (amount * (currency.toUpperCase() == 'XPF' ? 1 : 100)).round();

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async {
    final res = await _http.post(
      Uri.parse('$apiBase$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      },
      body: jsonEncode(body),
    );
    return _decode(res, path);
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await _http.get(
      Uri.parse('$apiBase$path'),
      headers: {'Authorization': 'Bearer $apiKey'},
    );
    return _decode(res, path);
  }

  Map<String, dynamic> _decode(http.Response res, String path) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      json = {};
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw MobupayException(
        'Mobupay $path a échoué (${res.statusCode})',
        statusCode: res.statusCode,
        responseBody: json,
      );
    }
    return json;
  }

  /// Crée une session de paiement (page hébergée). `amount` en unité mineure.
  ///
  /// [customerEmail] (optionnel) : si fourni, le champ email n'est pas demandé
  /// sur la page hébergée et le reçu est envoyé par email ; au succès, la page
  /// redirige automatiquement vers [redirectUrl] (doit être une URL http(s)).
  Future<CheckoutSession> createCheckoutSession({
    required String reference,
    required int amount,
    required String currency,
    required String redirectUrl,
    String? notificationUrl,
    String? externalId,
    String? customerEmail,
    String? idempotencyKey,
  }) async {
    final json = await _post(
      '/api/v1/payments/sessions',
      {
        'order': {'reference': reference, 'amount': amount, 'currency': currency},
        'redirectUrl': redirectUrl,
        if (notificationUrl != null) 'notificationUrl': notificationUrl,
        if (externalId != null) 'externalId': externalId,
        if (customerEmail != null) 'email': customerEmail,
      },
      idempotencyKey: idempotencyKey ?? reference,
    );
    return CheckoutSession.fromJson(json);
  }

  /// Crée un lien de paiement partageable. `amount` en unité mineure.
  Future<CheckoutSession> createCheckoutLink({
    required String reference,
    required int amount,
    required String currency,
    String? redirectUrl,
    String? notificationUrl,
    String? externalId,
    String? customerEmail,
    String? idempotencyKey,
  }) async {
    final json = await _post(
      '/api/v1/payments/links',
      {
        'order': {'reference': reference, 'amount': amount, 'currency': currency},
        if (redirectUrl != null) 'redirectUrl': redirectUrl,
        if (notificationUrl != null) 'notificationUrl': notificationUrl,
        if (externalId != null) 'externalId': externalId,
        if (customerEmail != null) 'email': customerEmail,
      },
      idempotencyKey: idempotencyKey ?? reference,
    );
    return CheckoutSession.fromJson(json);
  }

  /// Lit l'état d'un paiement.
  Future<Payment> retrievePayment(String paymentId) async {
    final json = await _get('/api/v1/payments/${Uri.encodeComponent(paymentId)}');
    return Payment.fromJson(json);
  }

  /// Rembourse un paiement (total si `amount` null, sinon partiel en unité mineure).
  Future<void> refund(String paymentId, {int? amount, String? idempotencyKey}) async {
    await _post(
      '/api/v1/payments/${Uri.encodeComponent(paymentId)}/refund',
      {if (amount != null) 'amount': amount},
      idempotencyKey: idempotencyKey,
    );
  }

  void close() => _http.close();
}
