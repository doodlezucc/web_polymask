class RingSearchError<T> {
  final List<T> ring;
  final List<T> other;
  final int errorInRing;
  final int offset;

  RingSearchError(this.ring, this.other, this.errorInRing, this.offset);
}

RingSearchError<T> ringMismatch<T>(List<T> ring, List<T> other) {
  if (ring.isEmpty) return null;

  RingSearchError<T> lastError = RingSearchError(ring, other, 0, 0);

  var offset = -1;
  while ((offset = other.indexOf(ring[0], offset + 1)) >= 0) {
    RingSearchError<T> error;

    for (var i = 0; i < ring.length; i++) {
      final item = ring[i];
      final pair = other[(i + offset) % ring.length];
      if (item != pair) {
        error = RingSearchError<T>(ring, other, i, offset);
        break;
      }
    }

    if (error == null) return null; // Found match
    lastError = error;
  }

  return lastError;
}
