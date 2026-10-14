enum ItemServerStatus {
  checking,
  online,
  reconnecting,
  offline,
  databaseUnavailable,
}

extension ItemServerStatusLabel on ItemServerStatus {
  String get label => switch (this) {
    ItemServerStatus.checking => 'Checking',
    ItemServerStatus.online => 'Online',
    ItemServerStatus.reconnecting => 'Reconnecting',
    ItemServerStatus.offline => 'Offline',
    ItemServerStatus.databaseUnavailable => 'Database unavailable',
  };
}
