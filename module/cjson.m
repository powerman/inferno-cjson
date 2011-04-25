CJSON: module
{
	PATH: con "$CJSON";

	END_OBJ: con -1;
	UNK_KEY: con -2;

	makekeys: fn(a: array of string): Keys;

	# These bugs are intentional, to increase speed:
	# - key names doesn't unquoted and must match literally
	# - true/false/null detected by first letter
	# - numbers with leading zeroes allowed
	# - structure doesn't 100% validated: '{"a":"b",}' and '1,' are valid json
	Token: adt{
		new:		fn(a: array of byte): ref Token;
		openobj:	fn(t: self ref Token);
		closeobj:	fn(t: self ref Token);
		openarr:	fn(t: self ref Token);
		closearr:	fn(t: self ref Token): int;
		getkey:		fn(t: self ref Token, k: Keys): int;
		getnull:	fn(t: self ref Token): int;
		getbool:	fn(t: self ref Token): int;
		gets:		fn(t: self ref Token): string;
		getr:		fn(t: self ref Token): real;
		getn:		fn(t: self ref Token): int;
		skip:		fn(t: self ref Token);
		gettype:	fn(t: self ref Token): int;
		end:		fn(t: self ref Token);

		# Internal:
		buf:		array of byte;
		pos:		int;
		stack:		array of byte;
		depth:		int;
	};

	# Internal:
	Node: adt{
		tail:	array of byte;
		id:	int;
		n:	cyclic array of ref Node;
	};
	Keys: type array of ref Node;
};
