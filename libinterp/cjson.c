#include <lib9.h>
#include <isa.h>
#include <interp.h>
#include "runt.h"
#include "raise.h"
#include "cjsonmod.h"

static char exEmptyKey[]		= "empty keys not supported";
static char exDupKey[]			= "duplicate keys";
static char exTokenEOF[]		= "unexpected EOF";
static char exTokenStack[]		= "stack overflow";
static char exTokenStackNonObj[]	= "closing non-opened object";
static char exTokenStackNonArr[]	= "closing non-opened array";
static char exTokenExpectObj[]		= "expected '{'";
static char exTokenExpectEndObj[]	= "expected '}'";
static char exTokenExpectArr[]		= "expected '['";
static char exTokenExpectStr[]		= "expected '\"'";
static char exTokenNonTerminatedStr[]	= "non-terminated string";
static char exTokenExpectColon[]	= "expected ':'";
static char exTokenExpectBool[]		= "expected true or false";
static char exTokenBadUnicode[]		= "bad \\u in string";
static char exTokenExpectNumber[]	= "expected number";
static char exTokenExpectEOF[]		= "expected EOF";
static char exTokenExpectToken[]	= "expected json token";

static Type* TNode;
static Type* TToken;
static uchar Node_map[]			= CJSON_Node_map;
static uchar Token_map[]		= CJSON_Token_map;

#define SKIPSP()				\
	for(; t->pos < buflen; t->pos++)	\
		if(buf[t->pos] != ' ' && buf[t->pos] != '\t' && buf[t->pos] != '\n') \
			break;

void
cjsonmodinit(void)
{
	builtinmod("$CJSON", CJSONmodtab, CJSONmodlen);

	TNode = dtype(freeheap, CJSON_Node_size, Node_map, sizeof(Node_map));
	TToken = dtype(freeheap, CJSON_Token_size, Token_map, sizeof(Token_map));
}

static Array*
slice(Array* sa, int s, int e)
{
        Type *t;
        Heap *h;
        Array *a;

	if(s < 0 || s > e || e > sa->len)
		error(exBounds);

        t = sa->t;
        h = heap(&Tarray);
        a = H2D(Array*, h);
        a->len = e - s;
        a->data = sa->data + s*t->size;
        a->t = t;
        t->ref++;

        if(sa->root != H)                       /* slicing a slice */
                sa = sa->root;

        a->root = sa;
        h = D2H(sa);
        h->ref++;
        Setmark(h);

        return a;
}

void
CJSON_makekeys(void *fp)
{
	F_CJSON_makekeys *f;
	Array *a;
	void *tmp;
	Array *keys, *k;
	int i, j;
	uchar *b, c;
	int blen;
	String **adata;
	CJSON_Node **kdata, **ndata;
	CJSON_Node *n, *n2;

	f = fp;
	a = f->a;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);
	adata = (String**)a->data;

	keys = H2D(Array*, heaparray(&Tptr, 256));

	for(i = 0; i < a->len; i++){
		k = keys;
		b = string2c(adata[i]);
		blen = strlen(b);
		if(blen == 0)
			error(exEmptyKey);
		for(j = 0; j < blen; j++){
			c = b[j];
			kdata = (CJSON_Node**)k->data;
			n = kdata[c];
			if(n == H){
				n = kdata[c] = H2D(CJSON_Node*, heap(TNode));
				n->id = i;
				if(j + 1 < blen){
					n->tail = H2D(Array*, heaparray(&Tbyte, blen-(j+1)));
					memmove(n->tail->data, b+j+1, n->tail->len);
				}
				break;
			}
			if(n->n == H){
				n->n = H2D(Array*, heaparray(&Tptr, 256));
				if(n->tail != H){
					c = n->tail->data[0];
					ndata = (CJSON_Node**)n->n->data;
					n2 = ndata[c] = H2D(CJSON_Node*, heap(TNode));
					n2->id = n->id;
					if(n->tail->len > 1)
						n2->tail = slice(n->tail, 1, n->tail->len);
					n->id = CJSON_UNK_KEY;
					destroy(n->tail);
					n->tail = H;
				}
			}
			if(j + 1 == blen && n->tail == H){
				if(n->id != CJSON_UNK_KEY)
					error(exDupKey);
				n->id = i;
				break;
			}
			k = n->n;
		}
	}

	*f->ret = keys;
}

void
Token_new(void *fp)
{
	F_Token_new *f;
	Array *a;
	void *tmp;
	CJSON_Token *t;
	Heap *h;
	uchar *buf;
	int buflen;

	f = fp;
	a = f->a;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);

	t = H2D(CJSON_Token*, heap(TToken));
	t->buf = a;
	h = D2H(a);
	h->ref++;
	Setmark(h);
	t->pos = 0;
	t->stack = H2D(Array*, heaparray(&Tbyte, 16));
	t->depth = 0;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	SKIPSP();

	*f->ret = t;
}

void
Token_openobj(void *fp)
{
	F_Token_openobj *f;
	CJSON_Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);
	if(buf[t->pos] != '{')
		error(exTokenExpectObj);
	
	t->pos++;

	if(t->depth == t->stack->len)
		error(exTokenStack);
	t->stack->data[t->depth++] = '{';

	SKIPSP();
}

void
Token_closeobj(void *fp)
{
	F_Token_closeobj *f;
	CJSON_Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);
	if(buf[t->pos] != '}')
		error(exTokenExpectEndObj);

	t->pos++;

	if(t->depth == 0 || t->stack->data[--t->depth] != '{')
		error(exTokenStackNonObj);
	
	SKIPSP();
	if(t->pos != buflen && buf[t->pos] == ','){
		t->pos++;
		SKIPSP();
	}
}

void
Token_openarr(void *fp)
{
	F_Token_openarr *f;
	CJSON_Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);
	if(buf[t->pos] != '[')
		error(exTokenExpectArr);
	
	t->pos++;

	if(t->depth == t->stack->len)
		error(exTokenStack);
	t->stack->data[t->depth++] = '[';

	SKIPSP();
}

void
Token_closearr(void *fp)
{
	F_Token_closearr *f;
	CJSON_Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);
	if(buf[t->pos] != ']'){
		*f->ret = 0;
		return;
	}

	t->pos++;

	if(t->depth == 0 || t->stack->data[--t->depth] != '[')
		error(exTokenStackNonArr);
	
	SKIPSP();
	if(t->pos != buflen && buf[t->pos] == ','){
		t->pos++;
		SKIPSP();
	}

	*f->ret = 1;
}

void
Token_getkey(void *fp)
{
	F_Token_getkey *f;
	CJSON_Token *t;
	Array *k;
	uchar *buf;
	int buflen;
	int s, l;
	int i, j, lt;
	CJSON_Node *n;

	f = fp;
	t = f->t;
	k = f->k;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);
	if(buf[t->pos] == '}'){
		*f->ret = CJSON_END_OBJ;
		return;
	}
	if(buf[t->pos] != '"')
		error(exTokenExpectStr);

	t->pos++;
	s = t->pos;
	for(; t->pos < buflen && buf[t->pos] != '"'; t->pos++)
		if(buf[t->pos] == '\\')
			t->pos++;	// keys not unquoted for speed
	if(t->pos >= buflen)
		error(exTokenNonTerminatedStr);
	l = t->pos - s;
	t->pos++;

	SKIPSP();
	
	if(buf[t->pos] != ':')
		error(exTokenExpectColon);
	t->pos++;

	SKIPSP();

	for(i = 0; i < l; i++){
		n = ((CJSON_Node**)k->data)[ buf[s+i] ];
		if(n == H)
			goto UNK_KEY;
		if(n->n == H || i == l - 1){
			lt = n->tail == H ? 0 : n->tail->len;
			if(l - i - 1 != lt)
				goto UNK_KEY;
			for(j = 0; j < lt; j++){
				if(buf[s+i+1+j] != n->tail->data[j])
					goto UNK_KEY;
			}
			*f->ret = n->id; // n.id may be UNK_KEY when n.tail==nil
			return;
		}
		k = n->n;
	}

UNK_KEY:
	*f->ret = CJSON_UNK_KEY;
}

void
Token_getnull(void *fp)
{
	F_Token_getnull *f;
	CJSON_Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen){
		*f->ret = 0;
		return;
	}

	if(buf[t->pos] == 'n'){
		t->pos += 4;
	
		if(t->pos > buflen)
			error(exTokenEOF);

		SKIPSP();
		if(t->pos != buflen && buf[t->pos] == ','){
			t->pos++;
			SKIPSP();
		}

		*f->ret = 1;
		return;
	}

	*f->ret = 0;
}

void
Token_getbool(void *fp)
{
	F_Token_getbool *f;
	CJSON_Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);

	if(buf[t->pos] == 't'){
		t->pos += 4;
	
		if(t->pos > buflen)
			error(exTokenEOF);

		SKIPSP();
		if(t->pos != buflen && buf[t->pos] == ','){
			t->pos++;
			SKIPSP();
		}

		*f->ret = 1;
		return;
	}

	if(buf[t->pos] == 'f'){
		t->pos += 5;
	
		if(t->pos > buflen)
			error(exTokenEOF);

		SKIPSP();
		if(t->pos != buflen && buf[t->pos] == ','){
			t->pos++;
			SKIPSP();
		}

		*f->ret = 0;
		return;
	}

	error(exTokenExpectBool);
}

void
Token_gets(void *fp)
{
	F_Token_gets *f;
	CJSON_Token *t;
	void *tmp;
	uchar *buf;
	int buflen;
	int s, l;
	int quote_pos;
	uchar *str;
	int i;
	uchar h;
	Rune c;

	f = fp;
	t = f->t;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);
	if(buf[t->pos] != '"')
		error(exTokenExpectStr);

	quote_pos = 0;
	t->pos++;
	s = t->pos;
	for(; t->pos < buflen && buf[t->pos] != '"'; t->pos++)
		if(buf[t->pos] == '\\')
			if(quote_pos == 0)
				quote_pos = t->pos++;
			else
				t->pos++;
	if(t->pos >= buflen)
		error(exTokenNonTerminatedStr);
	l = t->pos - s;
	t->pos++;

	SKIPSP();

	if(buf[t->pos] == ','){
		t->pos++;
		SKIPSP();
	}

	if(quote_pos == 0){
		*f->ret = c2string(buf+s, l);
		return;
	}

	str = malloc(l);
	if(str == nil)
		error(exNomem);
	buflen = s + l;
	l = 0;
        // buflen        now cut buf at end of string (point to closing ")
        // l             real length of str
        // s             start pos in buf of next chunk to copy to str
        // quote_pos     end   pos in buf of next chunk to copy to str (point to next \)
	for(;;){
		memmove(str+l, buf+s, quote_pos - s);
		l += quote_pos - s;
		switch(buf[quote_pos+1]){
		default:
			str[l++] = buf[quote_pos+1];
			s = quote_pos + 2;
			break;
		case 'b':
			str[l++] = '\b';
			s = quote_pos + 2;
			break;
		case 'f':
			str[l++] = '\f';
			s = quote_pos + 2;
			break;
		case 'n':
			str[l++] = '\n';
			s = quote_pos + 2;
			break;
		case 'r':
			str[l++] = '\r';
			s = quote_pos + 2;
			break;
		case 't':
			str[l++] = '\t';
			s = quote_pos + 2;
			break;
		case 'u':
			s = quote_pos + 6;
			if(s > buflen){
				free(str);
				error(exTokenBadUnicode);
			}
			c = 0;
			for(i = 0; i < 4; i++){
				h = buf[quote_pos+2+i];
				if('0' <= h && h <= '9')
					c = (c<<4) | (h-'0');
				else if('a' <= h && h <= 'f')
					c = (c<<4) | (10+(h-'a'));
				else if('A' <= h && h <= 'F')
					c = (c<<4) | (10+(h-'A'));
				else{
					free(str);
					error(exTokenBadUnicode);
				}
			}
			l += runetochar(str+l, &c);
		}
		for(quote_pos = s; buf[quote_pos] != '\\'; quote_pos++)
			if(quote_pos == buflen){
				memmove(str+l, buf+s, quote_pos - s);
				l += quote_pos - s;
				*f->ret = c2string(str, l);
				free(str);
				return;
			}
	}
}

void
Token_getr(void *fp)
{
	F_Token_getr *f;
	CJSON_Token *t;
	uchar *buf;
	int buflen;
	int is_str;
	double d;
	char *s, *e;
	int l;

	f = fp;
	t = f->t;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);

	is_str = 0;
	if(buf[t->pos] == '"'){
		t->pos++;
		is_str = 1;
	}

	l = buflen - t->pos;
	s = malloc(l + 1);
	if(s == nil)
		error(exNomem);
	memmove(s, buf+t->pos, l);
	s[l] = 0;

	d = strtod(s, &e);
	l = e - s;
	free(s);
	if(l <= 0)
		error(exTokenExpectNumber);
	t->pos += l;

	if(is_str)
		if(buf[t->pos] == '"')
			t->pos++;
		else
			error(exTokenNonTerminatedStr);
	
	SKIPSP();

	if(buf[t->pos] == ','){
		t->pos++;
		SKIPSP();
	}

	*f->ret = d;
}

void
Token_getn(void *fp)
{
	F_Token_getn *f;
	CJSON_Token *t;
	uchar *buf;
	int buflen;
	int is_str;
	int n;
	char *s, *e;
	int l;

	f = fp;
	t = f->t;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);

	is_str = 0;
	if(buf[t->pos] == '"'){
		t->pos++;
		is_str = 1;
	}

	l = buflen - t->pos;
	s = malloc(l + 1);
	if(s == nil)
		error(exNomem);
	memmove(s, buf+t->pos, l);
	s[l] = 0;

	n = strtol(s, &e, 10);
	l = e - s;
	free(s);
	if(l <= 0)
		error(exTokenExpectNumber);
	t->pos += l;

	if(is_str)
		if(buf[t->pos] == '"')
			t->pos++;
		else
			error(exTokenNonTerminatedStr);
	
	SKIPSP();

	if(buf[t->pos] == ','){
		t->pos++;
		SKIPSP();
	}

	*f->ret = n;
}

void
Token_skip(void *fp)
{
	F_Token_gets *f;
	CJSON_Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;
	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);

	if(buf[t->pos] == '"'){
		t->pos++;
		for(; t->pos < buflen && buf[t->pos] != '"'; t->pos++)
			if(buf[t->pos] == '\\')
				t->pos++;
		if(t->pos >= buflen)
			error(exTokenNonTerminatedStr);
		t->pos++;
	}
	else if(buf[t->pos] == '-' || ('0' <= buf[t->pos] && buf[t->pos] <= '9')){
		t->pos++;
		while(t->pos < buflen && ('0' <= buf[t->pos] && buf[t->pos] <= '9'))
			t->pos++;
		if(t->pos < buflen && buf[t->pos] == '.'){
			t->pos++;
			while(t->pos < buflen && ('0' <= buf[t->pos] && buf[t->pos] <= '9'))
				t->pos++;
		}
		if(t->pos < buflen && (buf[t->pos] == 'e' || buf[t->pos] == 'E')){
			t->pos++;
			if(buf[t->pos] == '+' || buf[t->pos] == '-')
				t->pos++;
			while(t->pos < buflen && ('0' <= buf[t->pos] && buf[t->pos] <= '9'))
				t->pos++;
		}
	}
	else if(buf[t->pos] == 't')
		t->pos += 4;
	else if(buf[t->pos] == 'f')
		t->pos += 5;
	else if(buf[t->pos] == 'n')
		t->pos += 4;
	else if(buf[t->pos] == '['){
		t->pos++;

		SKIPSP();

		while(t->pos < buflen && buf[t->pos] != ']')
			Token_skip(fp);
		if(t->pos >= buflen)
			error(exTokenEOF);
		t->pos++;
	}
	else if(buf[t->pos] == '{'){
		t->pos++;

		SKIPSP();

		while(t->pos < buflen && buf[t->pos] != '}'){
			if(buf[t->pos] != '"')
				error(exTokenExpectStr);

			t->pos++;
			for(; t->pos < buflen && buf[t->pos] != '"'; t->pos++)
				if(buf[t->pos] == '\\')
					t->pos++;
			if(t->pos >= buflen)
				error(exTokenNonTerminatedStr);
			t->pos++;

			SKIPSP();
			
			if(buf[t->pos] != ':')
				error(exTokenExpectColon);
			t->pos++;

			SKIPSP();

			Token_skip(fp);
		}
		if(t->pos >= buflen)
			error(exTokenEOF);
		t->pos++;
	}
	else
		error(exTokenExpectToken);

	SKIPSP();
	
	if(buf[t->pos] == ','){
		t->pos++;
		SKIPSP();
	}
}

void
Token_gettype(void *fp)
{
	F_Token_gettype *f;
	CJSON_Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;
	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		*f->ret = 0;
	else if(buf[t->pos] == '"')
		*f->ret = '"';
	else if(buf[t->pos] == '-' || ('0' <= buf[t->pos] && buf[t->pos] <= '9'))
		*f->ret = '0';
	else if(buf[t->pos] == '{')
		*f->ret = '{';
	else if(buf[t->pos] == '}')
		*f->ret = '}';
	else if(buf[t->pos] == '[')
		*f->ret = '[';
	else if(buf[t->pos] == ']')
		*f->ret = ']';
	else if(buf[t->pos] == 't')
		*f->ret = 't';
	else if(buf[t->pos] == 'f')
		*f->ret = 'f';
	else if(buf[t->pos] == 'n')
		*f->ret = 'n';
	else
		*f->ret = -1;
}

void
Token_end(void *fp)
{
	F_Token_end *f;
	CJSON_Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;
	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos != buflen)
		error(exTokenExpectEOF);
}

