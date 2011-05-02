implement T;

include "opt/powerman/tap/module/t.m";
include "cjson.m";
	cjson: CJSON;
	JSON2Token, Token2JSON, EMPTY_KEY: import cjson;

MyEmptyKey: con iota;

test()
{
	cjson = load CJSON CJSON->PATH;
	if(cjson == nil)
		bail_out("fail to load CJSON");

	plan(7);

	keys : ref CJSON->Keys;
	t    : ref JSON2Token;
	j    : ref Token2JSON;
	json := "{\"\":0}";

	keys = cjson->makekeys(nil);
	t    = JSON2Token.new(array of byte json);
	j    = Token2JSON.new(16);

	t.obj();
	eq_int(t.getkey(keys), EMPTY_KEY, "getkey()");
	eq_int(t.getn(), 0, "getn()");
	t.close();
	t.end();

	j.obj().key(keys, EMPTY_KEY).num(0).close();
	eq(string j.encode(), json, "key()");

	keys = cjson->makekeys(array[] of {
		MyEmptyKey => "",
	});
	t    = JSON2Token.new(array of byte json);
	j    = Token2JSON.new(16);

	t.obj();
	eq_int(t.getkey(keys), EMPTY_KEY, "getkey()");
	eq_int(t.getn(), 0, "getn()");
	t.close();
	t.end();

	j.obj().key(keys, EMPTY_KEY).num(0).close();
	eq(string j.encode(), json, "key()");
	
	{ j.obj().key(keys, MyEmptyKey); } exception e { "*" => catched(e); }
	raised("cjson:use EMPTY_KEY constant", nil);
}

