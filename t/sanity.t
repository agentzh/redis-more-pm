use strict;
use Test::More 'no_plan';

use lib 'lib';
use Redis::More qw(build_query parse_resp);

my $req = build_query(['set', 'foo', 'hello, world']);
is $req, "*3\r\n\$3\r\nset\r\n\$3\r\nfoo\r\n\$12\r\nhello, world\r\n";

is parse_resp("+Timed out\r\nhello"), "+Timed out\r\n";
is parse_resp("-Error occured\r\nhello"), "-Error occured\r\n";
is parse_resp("-Error occured\r"), undef;
is parse_resp("-Error occured"), undef;
is parse_resp("-"), undef;
is parse_resp(""), undef;
is parse_resp(":-10\r\nhello\r\n"), ":-10\r\n";
is parse_resp(":-10\r"), undef;
is parse_resp(":"), undef;

is parse_resp("\$"), undef;
is parse_resp("\$3\r"), undef;
is parse_resp("\$3\r\n"), undef;
is parse_resp("\$3\r\ns"), undef;
is parse_resp("\$3\r\nse"), undef;
is parse_resp("\$3\r\nset"), undef;
is parse_resp("\$3\r\nset\r"), undef;

is parse_resp("\$3\r\nset\r\n"), "\$3\r\nset\r\n";
is parse_resp("\$3\r\ns\r\n\r\n"), "\$3\r\ns\r\n\r\n";
is parse_resp("\$3\r\ns\r\n\r\n"), "\$3\r\ns\r\n\r\n";
is parse_resp("\$-1\r\nhi"), "\$-1\r\n";

is parse_resp("*1\r\n\$3\r\nset\r\n"), "*1\r\n\$3\r\nset\r\n";
is parse_resp("*2\r\n\$3\r\nset\r\n\$-1\r\n"), "*2\r\n\$3\r\nset\r\n\$-1\r\n";
is parse_resp("*2\r\n\$3\r\nset\r\n\$-1\r\n\r\n"), "*2\r\n\$3\r\nset\r\n\$-1\r\n";
is parse_resp("*0\r\n"), "*0\r\n";

