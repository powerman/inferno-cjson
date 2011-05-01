CJSON: module
{
	PATH: con "$CJSON";

	END_OBJ: con -1;
	UNK_KEY: con -2;
	EMPTY_KEY: con -3;

	makekeys: fn(a: array of string): ref Keys;

	JSON2Token: adt{
		new:	fn(a: array of byte): ref JSON2Token;
		obj:	fn(t: self ref JSON2Token);
		arr:	fn(t: self ref JSON2Token);
		close:	fn(t: self ref JSON2Token): int;
		getkey:	fn(t: self ref JSON2Token, k: ref Keys): int;
		getnull:fn(t: self ref JSON2Token): int;
		getbool:fn(t: self ref JSON2Token): int;
		gets:	fn(t: self ref JSON2Token): string;
		getr:	fn(t: self ref JSON2Token): real;
		getn:	fn(t: self ref JSON2Token): int;
		skip:	fn(t: self ref JSON2Token);
		gettype:fn(t: self ref JSON2Token): int;
		end:	fn(t: self ref JSON2Token);

		# Internal:
		buf:	array of byte;
		pos:	int;
		stack:	array of byte;
		depth:	int;
	};

	Token2JSON: adt{
		new:	fn(sizehint: int): ref Token2JSON;
		obj:	fn(j: self ref Token2JSON): ref Token2JSON;
		arr:	fn(j: self ref Token2JSON): ref Token2JSON;
		close:	fn(j: self ref Token2JSON): ref Token2JSON;
		key:	fn(j: self ref Token2JSON, k: ref Keys, id: int): ref Token2JSON;
		str:	fn(j: self ref Token2JSON, s: string): ref Token2JSON;
		num:	fn(j: self ref Token2JSON, n: int): ref Token2JSON;
		bignum:	fn(j: self ref Token2JSON, n: big): ref Token2JSON;
		realnum:fn(j: self ref Token2JSON, n: real): ref Token2JSON;
		bool:	fn(j: self ref Token2JSON, n: int): ref Token2JSON;
		null:	fn(j: self ref Token2JSON): ref Token2JSON;
		encode:	fn(j: self ref Token2JSON): array of byte;

		# Internal:
		buf:	array of byte;
		size:	int;
		stack:	array of byte;
		depth:	int;
		expect: int;
	};

	# Internal:
	Node: adt{
		tail:	array of byte;
		id:	int;
		n:	cyclic array of ref Node;
	};
	Keys: adt{
		id2key: array of array of byte;
		key2id:	array of ref Node;
	};
};
