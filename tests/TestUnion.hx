package tests;

@:asserts
class TestUnion extends Test {
  @:before public function before() return createTables();
  @:after public function after() return dropTables();
  
  public function unionTest() {
    return insertUsers().next(function (_)
      return db.User.union(db.User).first()
    ).next(function (res)
      return assert(res.id == 1)
    );
  }
}