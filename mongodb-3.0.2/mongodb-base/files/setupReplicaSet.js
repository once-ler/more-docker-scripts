rs.add('mongos@WORKERNUM@r2:27017');
cfg = rs.conf();
cfg.members[0].host = 'mongos@WORKERNUM@r1:27017';
rs.reconfig(cfg);