final class EverEvents {
  const EverEvents({
    this.onComputing,
    this.onComputed,
    this.onInvalidated,
  });

  final void Function()? onComputing;
  final void Function()? onComputed;
  final void Function()? onInvalidated;
}
