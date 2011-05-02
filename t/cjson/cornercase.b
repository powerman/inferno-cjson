implement T;

include "opt/powerman/tap/module/t.m";
include "cjson.m";
	cjson: CJSON;
	JSON2Token, Token2JSON, END_OBJ, UNK_KEY, EMPTY_KEY: import cjson;

test()
{
	cjson = load CJSON CJSON->PATH;
	if(cjson == nil)
		bail_out("fail to load CJSON");

	plan(30);

	keys : ref CJSON->Keys;
	t : ref JSON2Token;
	j : ref Token2JSON;

	keys = cjson->makekeys(nil);
	ok(keys != nil, "makekeys(nil)");
	ok(keys.id2key != nil, nil);
	ok(keys.key2id != nil, nil);
	eq_int(len keys.id2key, 0, nil);

	keys = cjson->makekeys(array[0] of string);
	ok(keys != nil, "makekeys(array[0])");
	ok(keys.id2key != nil, nil);
	ok(keys.key2id != nil, nil);
	eq_int(len keys.id2key, 0, nil);

	keys = cjson->makekeys(array[] of { "" });
	ok(keys != nil, "makekeys(array[] of { \"\" })");
	ok(keys.id2key != nil, nil);
	ok(keys.key2id != nil, nil);
	eq_int(len keys.id2key, 1, nil);

	keys = cjson->makekeys(array[] of { "", "", "" });
	ok(keys != nil, "makekeys(array[] of { \"\", \"\", \"\" })");
	ok(keys.id2key != nil, nil);
	ok(keys.key2id != nil, nil);
	eq_int(len keys.id2key, 3, nil);

	t = JSON2Token.new(nil);
	ok(t != nil, "JSON2Token.new(nil)");

	t = JSON2Token.new(array[0] of byte);
	ok(t != nil, "JSON2Token.new(array[0] of byte)");

	t = JSON2Token.new(array of byte "\"\":");
	eq_int(t.getkey(keys), EMPTY_KEY, "getkey() on empty key");

	{ t.getkey(nil); } exception e { "*" => catched(e); }
	raised("cjson:prepare keys with makekeys() first", nil);

	j = Token2JSON.new(-1);
	ok(j != nil, "Token2JSON.new(-1)");
	j = Token2JSON.new(0);
	ok(j != nil, "Token2JSON.new(0)");
	{ Token2JSON.new(16r7FFFFFFF); } exception e { "*" => catched(e); }
	raised("out of memory: heap", nil);

	{ j.key(nil, 0); } exception e { "*" => catched(e); }
	raised("cjson:prepare keys with makekeys() first", nil);
	{ j.key(keys, -1); } exception e { "*" => catched(e); }
	raised("cjson:no such key", nil);
	{ j.key(keys, 0); } exception e { "*" => catched(e); }
	raised("cjson:use EMPTY_KEY constant", nil);
	{ j.key(keys, 2); } exception e { "*" => catched(e); }
	raised("cjson:use EMPTY_KEY constant", nil);
	{ j.key(keys, 3); } exception e { "*" => catched(e); }
	raised("cjson:no such key", nil);

	{ j.str(nil); } exception e { "*" => catched(e); }
	raised("", nil);
	eq(string j.encode(), "\"\"", nil);
}

