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

	plan(11);

	json1 := array of byte "  false  ";

	mem:=getmem(); for(i:=0; i<10000; i++)
	{ t1 := Token.new(json1); t1.getbool(); }
	ok_mem(mem);
	
	t := Token.new(array of byte "  ");
	ex := "";
	{ t.getbool(); } exception e { "*" => ex=e; }
	eq(ex, "unexpected EOF", "unexpected EOF");
	
	t = Token.new(array of byte " null ");
	ex = "";
	{ t.getbool(); } exception e { "*" => ex=e; }
	eq(ex, "expected true or false", "expected true or false");
	
	t = Token.new(array of byte "tru");
	ex = "";
	{ t.getbool(); } exception e { "*" => ex=e; }
	eq(ex, "unexpected EOF", "unexpected EOF");
	
	t = Token.new(array of byte "fals");
	ex = "";
	{ t.getbool(); } exception e { "*" => ex=e; }
	eq(ex, "unexpected EOF", "unexpected EOF");
	
	t = Token.new(array of byte "true");
	eq_int(t.getbool(), 1, "return 1 on true");

	t = Token.new(array of byte "false");
	eq_int(t.getbool(), 0, "return 0 on false");

	t = Token.new(array of byte "tttt");
	eq_int(t.getbool(), 1, "INTENTIONAL BUG detect true by first 't'");

	t = Token.new(array of byte "fffff");
	eq_int(t.getbool(), 0, "INTENTIONAL BUG detect false by first 'f'");

	t = Token.new(array of byte "  true , false  ");
	eq_int(t.getbool(), 1, "return 1 on true");
	eq_int(t.pos, 9, "pos changed");
}

