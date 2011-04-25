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

	plan(8);

	json1 := array of byte "  []  ";

	mem:=getmem(); for(i:=0; i<10000; i++)
	{ t1 := Token.new(json1); t1.openarr(); t1.closearr(); }
	ok_mem(mem);
	
	t := Token.new(array of byte "  ");
	ex := "";
	{ t.closearr(); } exception e { "*" => ex=e; }
	eq(ex, "unexpected EOF", "unexpected EOF");
	
	t = Token.new(array of byte " true ");
	eq_int(t.closearr(), 0, "return 0");
	eq_int(t.pos, 1, "pos wan't changed");

	t = Token.new(array of byte " ] ");
	ex = "";
	{ t.closearr(); } exception e { "*" => ex=e; }
	eq(ex, "closing non-opened array", "closing non-opened array");

	t = Token.new(array of byte " ] ");
	t.stack[0] = byte '{';
	t.depth = 1;
	ex = "";
	{ t.closearr(); } exception e { "*" => ex=e; }
	eq(ex, "closing non-opened array", "closing non-opened array");

	t = Token.new(array of byte " []  ,  true ");
	t.openarr();
	eq_int(t.closearr(), 1, "return 1");
	eq_int(t.pos, 8, "pos == 8");
}

