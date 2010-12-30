use strict;
use warnings;

use Test::More 'no_plan';

use lib 'lib';
use Anadis::Util qw(connect do_command);

#my $port = 6379;
my $port = 1234;

my $sock = connect('localhost', $port);
ok $sock, 'connect ok';

my $res = do_command($sock, ['flush_all']);
is $res, "-ERR unknown command 'flush_all'\r\n";

$res = do_command($sock, ['set', 'one', 'first']);
is $res, "+OK\r\n";

