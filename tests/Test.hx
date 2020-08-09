package tests;

import tink.sql.Driver;

class Test {
	var db:Db;
	
	public function new(db)
		this.db = db;

  function createTables() {
    return Future.ofMany([
      db.User.create(),
      db.Post.create(),
      db.PostAlias.create(),
      db.PostTags.create(),
    ]).map(function(o) {
      // for(o in o) trace(Std.string(o));
      return Noise;
    });
  }

  function dropTables() {
    return Future.ofMany([
      db.User.drop(),
      db.Post.drop(),
      db.PostAlias.drop(),
      db.PostTags.drop(),
    ]).map(function(o) {
      // for(o in o) trace(Std.string(o));
      return Noise;
    });
	}
	
  function insertUsers() {
    return db.User.insertMany([{
      id: cast null,
      name: 'Alice',
      email: 'alice@example.com',
      location: 'Atlanta',
    },{
      id: cast null,
      name: 'Bob',
      email: 'bob@example.com',
      location: null,
    },{
      id: cast null,
      name: 'Christa',
      email: 'christa@example.com',
      location: 'Casablanca',
    },{
      id: cast null,
      name: 'Dave',
      email: 'dave@example.com',
      location: 'Deauville',
    },{
      id: cast null,
      name: 'Dave',
      email: 'dave2@example.com',
      location: 'Deauville',
    }]);
  }

  function insertPost(title:String, author:String, tags:Array<String>)
    return
      db.User.where(User.name == author).first()
        .next(function (author:User) {
          return db.Post.insertOne({
            id: cast null,
            title: title,
            author: author.id,
            content: 'A wonderful post about "$title"',
          });
        })
        .next(function (post:Int) {
          return db.PostTags.insertMany([for (tag in tags) {
            tag: tag,
            post: post,
          }]);
        });
}
