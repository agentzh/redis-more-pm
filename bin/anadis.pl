#!/usr/bin/env perl

use strict;
use warnings;

#use Anadis::Util qw( safe_print safe_read );
use Redis::hiredis;

sub parse_msg ($);

while (<>) {
    if (m{^\d{4}/\d{2}/\d{2} (\d{2}:\d{2}:\d{2}) \[error\] \S+ \S+ (.*)}) {
        my ($time, $msg) = ($1, $2);
        #warn "Hit: $time $msg";
        my ($r, $sr, $u, $code, $err) = parse_msg($msg);
        if (!$r) {
            #warn "!!! ", $_;
            next;
        }

        next if $code eq 2;
        print "req $r, subreq $sr, up $u, code $code, err $err\n";

    } else {
        #warn "discard $_";
    }
}

sub parse_msg ($) {
    my $msg = shift;
    my ($r, $sr, $u, $code, $err) = ('', '', '', '', '');
    if ($msg =~ /, upstream: "(.*?)"/) {
        $u = $1;
    }

    if ($msg =~ /, subrequest: "(.*?)"/) {
        $sr = $1;
    }

    if ($msg =~ /, request: "\w+ ([^"?]+)/) {
        $r = $1;
    }

    if ($msg =~ /\((\d+): (.*?)\)/) {
        ($code, $err) = ($1, $2);
    }

    return ($r, $sr, $u, $code, $err);
}

