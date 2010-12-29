package Anadis::Util;

use strict;
use warnings;

use base 'Exporter';
use POSIX qw(EAGAIN);
use IO::Select;
use IO::Socket;

use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);

our @EXPORT_OK = qw(
    safe_print
    safe_read
    build_query
    connect
    parse_resp
);

our $Timeout = 1;

sub build_query {
    my $args = shift;
    return '*' . scalar(@$args) . "\r\n" .
        join "", map { "\$" . length($_) . "\r\n" . $_ . "\r\n" } @$args;
}

sub parse_resp ($);

sub parse_resp ($) {
    my $resp = shift;
    return undef unless length $resp;
    if ($resp =~ /^[-+:]/) {
        if ($resp =~ /.*\r\n/) {
            return $&;
        }

        return undef;
    }

    if ($resp =~ /^\$/) {
        if ($resp =~ /^\$-\d+\r\n/) {
            return $&;
        }

        if ($resp =~ /^\$(\d+)\r\n(.*)/s) {
            my ($n, $t) = ($1, $2);
            #warn "n: $n, t: $t";
            if ($t =~ /^.{$n}\r\n/s) {
                return "\$$n\r\n$&";
            }

            return undef;
        }

        return undef;
    }

    if ($resp =~ /^\*/) {
        if ($resp =~ /^\*0\r\n/) {
            return $&;
        }

        if ($resp =~ /^\*(\d+)\r\n(.*)/s) {
            my ($bulks, $t) = ($1, $2);
            my $parsed = "*$bulks\r\n";
            for my $i (1 .. $bulks) {
                my $r = parse_resp($t);
                if (!defined $r) {
                    return $r;
                }
                $parsed .= $r;
                $t = substr($t, length($r));
            }

            return $parsed;
        }

        return undef;
    }

    die "Invalid response: $resp\n";
}

sub safe_print ($$$) {
    my $sock = shift;
    my $timeout = pop;

    my $sel = IO::Select->new($sock);
    my $ctx = {
        buf => \$_[0],
        offset => 0,
        rest => length($_[0]),
    };
    while (($sock) = $sel->can_write($timeout)) {
        my $res = _do_print($sock, $ctx);
        if (!defined $res) {
            # an error occurred
            return (0, $ctx->{err});
        }
        next if $res == -1;
        return ($res);
    }

    return (undef, "timed out ($timeout sec)");
}

sub _do_print ($$) {
    my ($sock, $ctx) = @_;

    while (1) {
        return 1 if $ctx->{rest} == 0;

        if ($ctx->{rest} > 0) {
            my $bytes = syswrite($sock, ${ $ctx->{buf} }, $ctx->{rest}, $ctx->{offset});

            if (!defined $bytes) {
                if ($! == EAGAIN) {
                    #warn "write again...";
                    #sleep 0.002;
                    return -1;
                }
                my $errmsg = "write failed: $!";
                #warn "$errmsg\n";
                $ctx->{err} = "$errmsg";
                return undef;
            }

            #warn "wrote $bytes bytes.\n";
            $ctx->{offset} += $bytes;
            $ctx->{rest} -= $bytes;
        }
    }

    # impossible to reach here...
}

sub safe_read ($$$$) {
    my $sock = shift;
    my $timeout = pop;
    my $len = pop;
    my $buf = \$_[0];

    my $sel = IO::Select->new($sock);
    my $ctx = {
        rest => $len,
        buf => $buf,
        offset => 0,
    };

    while (($sock) = $sel->can_read($timeout)) {
        my $res = _do_read($sock, $ctx);
        if (!defined $res) {
            # an error occurred
            return (0, $ctx->{err});
        }
        next if $res == -1;
        return ($res);
    }

    return (undef, "timed out ($timeout sec)");
}

sub _do_read ($$) {
    my ($sock, $ctx) = @_;

    while (1) {
        my $bytes = sysread($sock, ${ $ctx->{buf} }, 1024 * 4, $ctx->{offset});

        if (!defined $bytes) {
            if ($! == EAGAIN) {
                #warn "read again...";
                #sleep 0.002;
                return -1;
            }
            $ctx->{err} = "500 read failed: $!";
            return undef;
        }

        if ($bytes == 0) {
            # connection closed

            if ($ctx->{rest} > 0) {
                $ctx->{err} = "response truncated, $ctx->{buf_size} remaining, $ctx->{offset} read";
                return undef;
            }

            return 1;
        }

        $ctx->{offset} += $bytes;
        $ctx->{rest} -= $bytes;
        #warn "read $bytes ($read_buf) bytes.\n";
    }

    # impossible to reach here...
    return undef;
}

sub connect ($$) {
    my ($host, $port) = @_;
    my $sock = IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => $port,
        Proto    => 'tcp',
        timeout  => 1,
    ) or
        die "Can't connect to $host:$port: $!\n";

    $sock->timeout($Timeout);

    my $flags = fcntl $sock, F_GETFL, 0
        or die "Failed to get flags: $!\n";

    fcntl $sock, F_SETFL, $flags | O_NONBLOCK
        or die "Failed to set flags: $!\n";

    return $sock;
}

1;
