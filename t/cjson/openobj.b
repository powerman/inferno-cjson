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

	plan(6);

	json1 := array of byte "  {\"key\":\"value\"}  ";

	mem:=getmem(); for(i:=0; i<10000; i++)
	{ t1 := JSON2Token.new(json1); t1.obj(); }
	ok_mem(mem);
	
	t := JSON2Token.new(array of byte "  ");
	{ t.obj(); } exception e { "*" => catched(e); }
	raised("cjson:unexpected EOF", nil);
	
	t = JSON2Token.new(array of byte " true ");
	{ t.obj(); } exception e { "*" => catched(e); }
	raised("cjson:expected '{'", nil);

	t = JSON2Token.new(array of byte " {{{{{{{{{{{{{{{{{ ");
	for(i=0;i<16;i++)
		t.obj();
	eq_int(t.depth, 16, "depth == 16");
	{ t.obj(); } exception e { "*" => catched(e); }
	raised("cjson:stack overflow", nil);

	t = JSON2Token.new(array of byte " { \"key\":46 } ");
	t.obj();
	eq_int(t.pos, 3, "pos == 3");
}

