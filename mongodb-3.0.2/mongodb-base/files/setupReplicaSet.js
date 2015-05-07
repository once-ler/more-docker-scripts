rs.add('@SERVER2@:27017');
cfg = rs.conf();
cfg.members[0].host = '@SERVER1@:27017';
rs.reconfig(cfg);