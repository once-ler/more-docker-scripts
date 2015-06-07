db.runCommand( { enableSharding : "test_db" } );
sh.shardCollection( "test_db.testData", { _id: "hashed" } );