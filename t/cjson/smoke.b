implement T;

include "opt/powerman/tap/module/t.m";
include "cjson.m";
	cjson: CJSON;
	JSON2Token, END_OBJ, UNK_KEY: import cjson;

Struct: adt{
	str: string;
	i: int;
	r: real;
	bool: int;
	opt1: int;
	opt2: int;
	opt3: int;
	arr: list of int;
};

F_ARR,
F_STR,
F_INT,
F_REAL,
F_BOOL,
F_OPT1,
F_OPT2,
F_OPT3: con iota;

test()
{
	cjson = load CJSON CJSON->PATH;
	if(cjson == nil)
		bail_out("fail to load CJSON");

	plan(11);

	keys := cjson->makekeys(array[] of {
		F_ARR	=> "arr",
		F_STR	=> "str",
		F_INT	=> "int",
		F_REAL	=> "real",
		F_BOOL	=> "bool",
		F_OPT1	=> "opt1",
		F_OPT2	=> "opt2",
		F_OPT3	=> "opt3",
	});

	t := JSON2Token.new(array of byte (
		  "{\n"
		+ "\"str\":	\"Text…\",\n"
		+ "\"int\":	-12,\n"
		+ "\"int\":	-21,\n"
		+ "\"real\":	2.3e+2,\n"
		+ "\"bool\":	true,\n"
		+ "\"opt1\":	null,\n"
		+ "\"opt2\":	46,\n"
		+ "\"extra\":	false,\n"
		+ "\"arr\":	[10,20]\n"
		+ "}"
	));

	struct := ref Struct;
	struct.opt1 = -1;
	struct.opt2 = -2;
	struct.opt3 = -3;

	t.obj();
OBJ:	for(;;) case t.getkey(keys) {
	END_OBJ =>	break OBJ;
	UNK_KEY =>	t.skip();
			ok(1, "UNK_KEY (extra)");
	F_STR =>	struct.str = t.gets();
	F_INT =>	struct.i = t.getn();
	F_REAL =>	struct.r = t.getr();
	F_BOOL =>	struct.bool = t.getbool();
	F_OPT1 =>	if(!t.getnull())
				struct.opt1 = t.getn();
	F_OPT2 =>	if(!t.getnull())
				struct.opt2 = t.getn();
	F_OPT3 =>	if(!t.getnull())
				struct.opt3 = t.getn();
	F_ARR =>	t.arr();
			while(!t.close())
				struct.arr = t.getn() :: struct.arr;
	}
	t.close();
	t.end();

	eq(struct.str, "Text…",	"str");
	eq_int(struct.i, -21,	"int");
	ok(struct.r == 2.3e2,	"real");
	eq_int(struct.bool, 1,	"bool");
	eq_int(struct.opt1, -1,	"opt1");
	eq_int(struct.opt2, 46,	"opt2");
	eq_int(struct.opt3, -3,	"opt3");
	eq_int(len struct.arr, 2, "arr len 2");
	eq_int(hd struct.arr, 20, "arr[0]");
	eq_int(hd tl struct.arr, 10, "arr[1]");
}

