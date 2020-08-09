package tests;

@:asserts
class TestDelete extends Test {
  @:before public function before() return createTables();
  @:after public function after() return dropTables();
  
  public function deleteUser() {
    return insertUsers().next(function (_)
      return db.User.delete({where: function (u) return u.id == 1})
    ).next(function (res) {
      asserts.assert(res.rowsAffected == 1);
      return db.User.count();
    }).next(function (count) {
      asserts.assert(count == 4);
      return asserts.done();
    });
  }
}