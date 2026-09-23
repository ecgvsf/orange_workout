String formatTimeSeconds(int totalSeconds) {
  if (totalSeconds < 60) {
    return '${totalSeconds}s';
  }
  final int minutes = totalSeconds ~/ 60;
  final int remainingSeconds = totalSeconds % 60;
  if (remainingSeconds == 0) {
    return '${minutes}m';
  }
  return '${minutes}m ${remainingSeconds}s';
}
