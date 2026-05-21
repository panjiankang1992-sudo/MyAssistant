class ConflictResolver {
  Map<String, dynamic> resolve(Map<String, dynamic> local, Map<String, dynamic> remote) {
    final localUpdatedAt = DateTime.tryParse(local['updatedAt'] as String? ?? '');
    final remoteUpdatedAt = DateTime.tryParse(remote['updatedAt'] as String? ?? '');

    if (localUpdatedAt == null && remoteUpdatedAt == null) return remote;
    if (localUpdatedAt == null) return remote;
    if (remoteUpdatedAt == null) return local;

    return remoteUpdatedAt.isAfter(localUpdatedAt) ? remote : local;
  }

  bool shouldOverride(Map<String, dynamic> local, Map<String, dynamic> remote) {
    final localVersion = local['version'] as int? ?? 0;
    final remoteVersion = remote['version'] as int? ?? 0;
    if (remoteVersion > localVersion) return true;

    final localUpdatedAt = DateTime.tryParse(local['updatedAt'] as String? ?? '');
    final remoteUpdatedAt = DateTime.tryParse(remote['updatedAt'] as String? ?? '');
    if (localUpdatedAt != null && remoteUpdatedAt != null) {
      return remoteUpdatedAt.isAfter(localUpdatedAt);
    }
    return false;
  }
}
