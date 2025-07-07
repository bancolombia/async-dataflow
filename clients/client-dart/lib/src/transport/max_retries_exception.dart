class MaxRetriesException implements Exception {
  final String message;
  MaxRetriesException(this.message);

  @override
  String toString() => 'MaxRetriesException: $message';
}