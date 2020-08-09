package tests;

class TestAlias extends Test {
  @:before public function before() return createTables();
  @:after public function after() return dropTables();
  public function testAlias() {
    return insertUsers()
      .next(function (_)
        return db.PostAlias.insertOne({
          id: cast null,
          title: 'alias',
          author: 1,
          content: 'content',
        })
      ).next(function (_)
        return db.Post.insertOne({
          id: cast null,
          title: 'regular',
          author: 1,
          content: 'content',
        })
      ).next(function (_) 
        return db.PostAlias.update(
          function (fields) {
            return [fields.title.set('update')];
          },
          {where: function (alias) return alias.id == 1}
        )  
      ).next(function (_) 
        return db.PostAlias.join(db.Post.as('bar'))
          .on(PostAlias.id == bar.id).first()
      )
      .next(function (res)
        return assert(res.PostAlias.title == 'update' && res.bar.title == 'regular')
      );
  }
}