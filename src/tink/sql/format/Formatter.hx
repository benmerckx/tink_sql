package tink.sql.format;

import tink.sql.Info;
import tink.sql.format.Statement;

interface Formatter<ColInfo, KeyInfo> {
  function format<Db, Result>(query:Query<Db, Result>):Statement;
  function defineColumn(column:Column):String;
  function defineKey(key:Key):String;
  function isNested<Db, Result>(query:Query<Db,Result>):Bool;
  function parseColumn(col:ColInfo):Column;
  function parseKeys(keys:Array<KeyInfo>):Array<Key>;
}