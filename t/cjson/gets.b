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

	plan(19);

	json1 := array of byte "  \"this is a string\" ,  ";

	mem:=getmem(); for(i:=0; i<10000; i++)
	{ t1 := Token.new(json1); t1.gets(); }
	ok_mem(mem);
	
	t := Token.new(array of byte "  ");
	ex := "";
	{ t.gets(); } exception e { "*" => ex=e; }
	eq(ex, "unexpected EOF", "unexpected EOF");
	
	t = Token.new(array of byte " null ");
	ex = "";
	{ t.gets(); } exception e { "*" => ex=e; }
	eq(ex, "expected '\"'", "expected '\"'");
	
	t = Token.new(array of byte " \" ");
	ex = "";
	{ t.gets(); } exception e { "*" => ex=e; }
	eq(ex, "non-terminated string", "non-terminated string");
	
	t = Token.new(array of byte "  \"this is a string\" ,  null  ");
	eq(t.gets(), "this is a string", "return string");
	eq_int(t.pos, 24, "pos changed");

	t = Token.new(array of byte "  \"this is a \\\"quoted\\\" string\" ,  null  ");
	eq(t.gets(), "this is a \"quoted\" string", "return quoted string");

	t = Token.new(array of byte "  \"\\n\" ,  null  ");
	eq(t.gets(), "\n", "return \\n");
	t = Token.new(array of byte "  \"\\b\\f\\n\\r\\t\\\\\\'\\\"\" ,  null  ");
	eq(t.gets(), "\b\f\n\r\t\\'\"", "return \\b\\f\\n\\r\\t\\'\"");
	t = Token.new(array of byte "  \"\\\\\" ,  null  ");
	eq(t.gets(), "\\", "return \\");
	t = Token.new(array of byte "  \"\\Q\" ,  null  ");
	eq(t.gets(), "Q", "return Q");

	t = Token.new(array of byte "  \"\\u\" ,  null  ");
	ex = "";
	{ t.gets(); } exception e { "*" => ex=e; }
	eq(ex, "bad \\u in string", "bad \\u in string");

	t = Token.new(array of byte "  \"\\u123-\" ,  null  ");
	ex = "";
	{ t.gets(); } exception e { "*" => ex=e; }
	eq(ex, "bad \\u in string", "bad \\u in string");

	t = Token.new(array of byte "  \"<\\u0020>\" ,  null  ");
	eq(t.gets(), "< >", "return \\u0020");
	t = Token.new(array of byte "  \"<\\u00fF>\" ,  null  ");
	eq(t.gets(), "<\u00ff>", "return \\u00fF");
	t = Token.new(array of byte "  \"<\\u0000>\" ,  null  ");
	eq(t.gets(), "<\0>", "return \\u0000");
	t = Token.new(array of byte "  \"<\\u2026>\" ,  null  ");
	eq(t.gets(), "<…>", "return …");
	t = Token.new(array of byte "  \"<\\ufFfF>\" ,  null  ");
	eq(t.gets(), "<\uffff>", "return \\ufFfF");

	json2 := array of byte "  \"this is a quoted \\ufFfF \\u2026 \\u0000 \\b\\f\\n\\r\\t\\\\\\'\\\" string\" ,  ";

	mem=getmem(); for(i=0; i<10000; i++)
	{ t1 := Token.new(json2); t1.gets(); }
	ok_mem(mem);
}

