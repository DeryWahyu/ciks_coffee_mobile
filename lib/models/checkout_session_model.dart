/// Persisted reservation metadata, including uploads whose outcome is unknown.
class CheckoutSession {
  const CheckoutSession(this.data);

  factory CheckoutSession.fromQuote(
    Map<String, dynamic> quote, {
    String? localCartId,
    bool submissionPending = false,
  }) => CheckoutSession({
    'request_key': quote['request_key'],
    'items': quote['items'],
    'expected_total': quote['total'],
    'checkout_id': quote['id'],
    'local_cart_id': localCartId,
    'expires_at': quote['expires_at'],
    'can_pay': quote['can_pay'],
    'status': quote['status'],
    'submission_pending': submissionPending || quote['order'] is Map,
  });

  final Map<String, dynamic> data;

  DateTime? get expiresAt => DateTime.tryParse('${data['expires_at'] ?? ''}');

  // Never discard an upload simply because its reservation expired while the
  // server response was lost. Reconcile the same request before starting over.
  bool get needsReview =>
      data['submission_pending'] == true ||
      data['order'] is Map ||
      const ['submitted', 'replayed'].contains(data['status']);

  bool endedAt(DateTime now) =>
      !needsReview &&
      ((expiresAt != null && !expiresAt!.isAfter(now)) ||
          data['can_pay'] == false ||
          const ['cancelled', 'expired'].contains(data['status']));
}
