package tests;

import tink.unit.AssertionBuffer;

@:await
@:asserts
class TestUpdate extends Test {
  @:before public function before() return createTables();
  @:after public function after() return dropTables();
  
  public function update() {
    await(runUpdate, asserts);
    return asserts;
  }
  
  function await(run:AssertionBuffer->Promise<Noise>, asserts:AssertionBuffer)
    run(asserts).handle(function(o) switch o {
      case Success(_): asserts.done();
      case Failure(e): asserts.fail(Std.string(e));
    });

  // this is what we do if we want to use tink_await while also want to return the assertbuffer early...
  @:async function runUpdate(asserts:AssertionBuffer) {
    @:await insertUsers();
    var results = @:await Future.ofMany([
      insertPost('test', 'Alice', ['test', 'off-topic']),
      insertPost('test2', 'Alice', ['test']),
      insertPost('Some ramblings', 'Alice', ['off-topic']),
      insertPost('Just checking', 'Bob', ['test']),
    ]);

    for (x in results)
      asserts.assert(x.isSuccess());

    asserts.assert((@:await db.PostTags.join(db.Post).on(PostTags.post == Post.id && PostTags.tag == 'off-topic').all()).length == 2);
    asserts.assert((@:await db.PostTags.join(db.Post).on(PostTags.post == Post.id && PostTags.tag == 'test').all()).length == 3);

    var update = @:await db.User.update(function (u) return [u.name.set('Donald')], { where: function (u) return u.name == 'Dave' } );
    asserts.assert(update.rowsAffected == 2);

    return Noise;
  }
}