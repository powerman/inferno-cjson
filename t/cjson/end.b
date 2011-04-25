implement T;

include "opt/powerman/tap/module/t.m";
include "cjson.m";
	cjson: CJSON;
	Token: import cjson;

test()
{
	cjson = load CJSON CJSON->PATH;
	if(cjson == nil)
		bail_out("fail to load CJSON");

	plan(3);

	json1 := array of byte "  ";

	mem:=getmem(); for(i:=0; i<10000; i++)
	{ t1 := Token.new(json1); t1.end(); }
	ok_mem(mem);
	
	t := Token.new(array of byte " null ");
	ex := "";
	{ t.end(); } exception e { "*" => ex=e; }
	eq(ex, "expected EOF", "expected EOF");

	t = Token.new(array of byte "  ");
	t.end();
	ok(1, "got EOF");
}

