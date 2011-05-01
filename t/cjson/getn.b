implement T;

include "opt/powerman/tap/module/t.m";
include "cjson.m";
	cjson: CJSON;
	JSON2Token: import cjson;

test()
{
	cjson = load CJSON CJSON->PATH;
	if(cjson == nil)
		bail_out("fail to load CJSON");

	plan(14);

	json1 := array of byte "  -2 ,  ";

	mem:=getmem(); for(i:=0; i<10000; i++)
	{ t1 := JSON2Token.new(json1); t1.getn(); }
	ok_mem(mem);
	
	t := JSON2Token.new(array of byte "  ");
	{ t.getn(); } exception e { "*" => catched(e); }
	raised("cjson:unexpected EOF", nil);
	
	t = JSON2Token.new(array of byte " null ");
	{ t.getn(); } exception e { "*" => catched(e); }
	raised("cjson:expected number", nil);
	
	t = JSON2Token.new(array of byte " \"0 ");
	{ t.getn(); } exception e { "*" => catched(e); }
	raised("cjson:non-terminated string", nil);
	
	t = JSON2Token.new(array of byte "  \"-2\" ,  null  ");
	eq_int(t.getn(), -2, "\"-2\"");
	eq_int(t.pos, 10, "pos changed");

	t = JSON2Token.new(array of byte "  -2 ,  null  ");
	eq_int(t.getn(), -2, "-2");
	eq_int(t.pos, 8, "pos changed");

	t = JSON2Token.new(array of byte "0");
	eq_int(t.getn(), 0, "0");
	eq_int(t.pos, 1, "pos changed");

	t = JSON2Token.new(array of byte "-123");
	eq_int(t.getn(), -123, "-123");

	t = JSON2Token.new(array of byte "+123");
	eq_int(t.getn(), 123, "+123");

	t = JSON2Token.new(array of byte "123");
	eq_int(t.getn(), 123, "123");

	t = JSON2Token.new(array of byte "123.456E-1");
	eq_int(t.getn(), 123, "123.456E-1");
}

