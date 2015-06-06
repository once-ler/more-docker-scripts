db.runCommand( { enableSharding : "test" } );
sh.shardCollection( "test.testData", { _id: "hashed" } );