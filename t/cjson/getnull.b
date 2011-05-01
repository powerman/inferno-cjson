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

	plan(11);

	json1 := array of byte "  null  ";

	mem:=getmem(); for(i:=0; i<10000; i++)
	{ t1 := JSON2Token.new(json1); t1.getnull(); }
	ok_mem(mem);
	
	t := JSON2Token.new(array of byte "  ");
	eq_int(t.getnull(), 0, "return 0 on EOF");
	
	t = JSON2Token.new(array of byte " true ");
	eq_int(t.getnull(), 0, "return 0 on non-null");
	eq_int(t.pos, 1, "pos wasn't changed");
	
	t = JSON2Token.new(array of byte " [null] ");
	eq_int(t.getnull(), 0, "return 0 on non-null");
	eq_int(t.pos, 1, "pos wasn't changed");
	
	t = JSON2Token.new(array of byte " nonsense ");
	eq_int(t.getnull(), 1, "INTENTIONAL BUG detect null by first 'n'");
	eq_int(t.pos, 5, "pos changed");

	t = JSON2Token.new(array of byte " non");
	{ t.getnull(); } exception e { "*" => catched(e); }
	raised("cjson:unexpected EOF", nil);

	t = JSON2Token.new(array of byte " null, ");
	eq_int(t.getnull(), 1, "null");
	eq_int(t.pos, 7, "pos changed");
}

