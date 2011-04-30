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

	plan(13);

	json1 := array of byte "  null  ";

	mem:=getmem(); for(i:=0; i<10000; i++)
	{ t1 := JSON2Token.new(json1); t1.gettype(); }
	ok_mem(mem);
	
	t := JSON2Token.new(array of byte "  ");
	eq_int(t.gettype(), 0, "return 0 on EOF");
	
	t = JSON2Token.new(array of byte " X ");
	eq_int(t.gettype(), -1, "return -1 on error");

	t = JSON2Token.new(array of byte " \"-2.3e+2\" ");
	eq_int(t.gettype(), '"', "return '\"' on string");

	t = JSON2Token.new(array of byte " -2.3e+2 ");
	eq_int(t.gettype(), '0', "return '0' on number");

	t = JSON2Token.new(array of byte " true ");
	eq_int(t.gettype(), 't', "return 't' on true");

	t = JSON2Token.new(array of byte " false ");
	eq_int(t.gettype(), 'f', "return 'f' on false");

	t = JSON2Token.new(array of byte " null ");
	eq_int(t.gettype(), 'n', "return 'n' on null");

	t = JSON2Token.new(array of byte " { ");
	eq_int(t.gettype(), '{', "return '{' on open object");

	t = JSON2Token.new(array of byte " } ");
	eq_int(t.gettype(), '}', "return '}' on close object");

	t = JSON2Token.new(array of byte " [ ");
	eq_int(t.gettype(), '[', "return '[' on open array");

	t = JSON2Token.new(array of byte " ] ");
	eq_int(t.gettype(), ']', "return ']' on close array");
	eq_int(t.pos, 1, "pos not changed");
}

