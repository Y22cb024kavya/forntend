/// Which flow initiated the current processing indicator. Drives the copy
/// shown in the branded AhviProcessingBubble.
enum AhviProcessingContext {
  styleRecommendation,
  styleThis,
  wardrobe,
  buildOutfit,
  shuffle,
  general,
  calendar,

  /// Stage 2 of a visual-board flow: response parsed, board visuals loading.
  arrangingBoard,
}

/// Resolve the processing copy for [context]. For [AhviProcessingContext.styleThis]
/// pass the initiating wardrobe [itemName] (e.g. "Pink Shirt"); when it is
/// missing we fall back to the general message rather than an empty name.
String ahviProcessingMessage(
  AhviProcessingContext context, {
  String? itemName,
}) {
  const fallback = 'AHVI is thinking';
  switch (context) {
    case AhviProcessingContext.styleRecommendation:
      return 'Curating your look';
    case AhviProcessingContext.styleThis:
      final name = itemName?.trim();
      return (name != null && name.isNotEmpty)
          ? 'Styling around your $name'
          : fallback;
    case AhviProcessingContext.wardrobe:
      return 'Checking your wardrobe';
    case AhviProcessingContext.buildOutfit:
      return 'Putting the outfit together';
    case AhviProcessingContext.shuffle:
      return 'Refreshing unlocked pieces';
    case AhviProcessingContext.calendar:
      return 'Preparing your plan';
    case AhviProcessingContext.arrangingBoard:
      return 'Arranging your Style Board';
    case AhviProcessingContext.general:
      return fallback;
  }
}
