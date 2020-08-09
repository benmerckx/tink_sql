package tests;

@:asserts
class TestJoins extends Test {
  @:before public function before() return createTables();
  @:after public function after() return dropTables();

  public function leftJoinTest() {
    return insertUsers().next(function (_)
      return db.User.leftJoin(db.Post).on(User.id == Post.author).first()
    ).next(function (res)
      return assert(res.User.id == 1 && res.Post == null)
    );
  }
}