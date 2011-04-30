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

	plan(17);

	json1 := array of byte "  -2.3e-3 ,  ";

	mem:=getmem(); for(i:=0; i<10000; i++)
	{ t1 := JSON2Token.new(json1); t1.getr(); }
	ok_mem(mem);
	
	t := JSON2Token.new(array of byte "  ");
	ex := "";
	{ t.getr(); } exception e { "*" => ex=e; }
	eq(ex, "unexpected EOF", "unexpected EOF");
	
	t = JSON2Token.new(array of byte " null ");
	ex = "";
	{ t.getr(); } exception e { "*" => ex=e; }
	eq(ex, "expected number", "expected number");
	
	t = JSON2Token.new(array of byte " \"0 ");
	ex = "";
	{ t.getr(); } exception e { "*" => ex=e; }
	eq(ex, "non-terminated string", "non-terminated string");
	
	t = JSON2Token.new(array of byte "  \"-2.3e-3\" ,  null  ");
	ok(t.getr() == -2.3e-3, "\"-2.3e-3\"");
	eq_int(t.pos, 15, "pos changed");

	t = JSON2Token.new(array of byte "  -2.3e-3 ,  null  ");
	ok(t.getr() == -2.3e-3, "-2.3e-3");
	eq_int(t.pos, 13, "pos changed");

	t = JSON2Token.new(array of byte "0");
	ok(t.getr() == 0.0, "0");
	eq_int(t.pos, 1, "pos changed");

	t = JSON2Token.new(array of byte "-123");
	ok(t.getr() == -123.0, "-123");

	t = JSON2Token.new(array of byte "+123.456");
	ok(t.getr() == 123.456, "+123.456");

	t = JSON2Token.new(array of byte "123.456e1");
	ok(t.getr() == 1234.56, "123.456e1");

	t = JSON2Token.new(array of byte "123.456E-1");
	ok(t.getr() == 12.3456, "123.456E-1");

	t = JSON2Token.new(array of byte "1E3");
	ok(t.getr() == 1E3, "1E3");

	t = JSON2Token.new(array of byte "123.456E-1.1");
	ok(t.getr() == 12.3456, "123.456E-1");
	eq_int(t.pos, 10, "pos changed");
}

