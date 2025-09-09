/// A platform-agnostic representation of a subscription offer.
/// Used to display offers consistently, whether they come from RevenueCat or a mock source.
class SubscriptionOffer {
  final String id;
  final String title;
  final String price;
  final List<String> features;
  final bool isRecommended;

  SubscriptionOffer({
    required this.id,
    required this.title,
    required this.price,
    required this.features,
    this.isRecommended = false,
  });
}
