package tests;

@:asserts
class TestCount extends Test {
  @:before public function before() return createTables();
  @:after public function after() return dropTables();
  
  @:variant(this.db.User.all(), 0)
  @:variant(this.db.Post.all(), 0)
  @:variant(this.db.PostTags.all(), 0)
  public function count<T>(query:Promise<Array<T>>, expected:Int) {
    return query.next(function(a:Array<T>) return assert(a.length == expected));
  }

  
  @:variant(this.db.User.all.bind(), 5)
  @:variant(this.db.User.where(User.name == 'Evan').all.bind(), 0)
  @:variant(this.db.User.where(User.name == 'Alice').all.bind(), 1)
  @:variant(this.db.User.where(User.name == 'Dave').all.bind(), 2)
  public function insertedCount<T>(query:Lazy<Promise<Array<T>>>, expected:Int)
    return insertUsers().next(function(_) return count(query.get(), expected, asserts));
}