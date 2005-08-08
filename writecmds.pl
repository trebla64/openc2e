#!/usr/bin/perl

use strict;
use warnings;

use YAML;

# zero-tolerance policy
$SIG{__WARN__} = sub { die $_[0] };

my $data = YAML::LoadFile($ARGV[0]);

print <<ENDHEAD;
// THIS FILE IS AUTOMATICALLY GENERATED
// DO NOT EDIT
#include "cmddata.h"
#include "dialect.h"
#include <string>
#include <map>
#include <iostream>

using namespace std;

const cmdinfo cmds[] = {
ENDHEAD

my $idx = 0;

$data = $data->{ops};

foreach my $key (sort keys %$data) {
    my $cedocs = cescape($data->{$key}{description} || "UNDOCUMENTED");
    my $argc = scalar @{$data->{$key}{arguments}};
    my $name = lc $data->{$key}{match};
    my $fullname = $data->{$key}{name};
    my $retc = $data->{$key}{type} eq 'command' ? 0 : 1;
    if (defined $data->{$key}{pragma}{retc}) {
        $retc = $data->{$key}{pragma}{retc};
    }
    my $delegate;
    if ($data->{$key}{pragma}{noparse}) {
        $delegate = undef;
    } elsif ($data->{$key}{pragma}{parser}) {
        $delegate = $data->{$key}{pragma}{parser};
    } else {
        my $class = 'DefaultParser';
        if ($data->{$key}{pragma}{parserclass}) {
            $class = $data->{$key}{pragma}{parserclass};
        }
        $delegate = qq{new $class(&$data->{$key}{implementation}, $idx)};
    }
        
    $data->{$key}{delegate} = $delegate;
    print <<ENDDATA;
    { // $idx
        "$name",
        "$fullname",
        "$cedocs",
        $argc,
        $retc
    },
ENDDATA
    $idx++;
}

print <<ENDTAIL;
    { NULL, NULL, NULL, 0, 0 }
};

void registerAutoDelegates() {
    std::map<std::string, NamespaceDelegate *> nsswitch_cmd, nsswitch_exp;
#define NS_REG(m, ns, name, d) do { \\
    if (m.find(ns) == m.end()) \\
        m[ns] = new NamespaceDelegate(); \\
    m[ns]->dialect.delegates[name] = d; \\
} while (0)
ENDTAIL

foreach my $key (keys %$data) {
    if (defined($data->{$key}{delegate})) {
        my $type = $data->{$key}{type} eq 'command' ? 'cmd' : 'exp';
        if ($data->{$key}{namespace}) {
            my $c = $data->{$key}{type} eq 'command';
            print "NS_REG(nsswitch_$type, \"";
            print $data->{$key}{namespace};
            print "\", \"", lc($data->{$key}{match}), "\", ";
            print $data->{$key}{delegate}, ");\n";
        } else {
            print $type;
            print "_dialect->delegates[\"", lc($data->{$key}{match}), "\"] = ";
            print $data->{$key}{delegate}, ";\n";
        }
    }
}

for my $T (qw(cmd exp)) {
print <<END;
    {
        std::map<std::string, NamespaceDelegate *>::iterator i = nsswitch_$T.begin();
        while (i != nsswitch_$T.end()) {
            std::string name = (*i).first;
            NamespaceDelegate *d = (*i).second;
            ${T}_dialect->delegates[name] = d;
            i++;
        }
    }
END
}
print "}\n";

exit 0;

our %cescapes;
BEGIN { %cescapes = (
    "\n" => "\\n",
    "\r" => "\\r",
    "\t" => "\\t",
    "\\" => "\\\\",
    "\"" => "\\\"",
); }

sub cescape {
    my $str = shift;
    my $ces = join "", keys %cescapes;
    $str =~ s/([\Q$ces\E])/$cescapes{$1}/ge;
    return $str;
}
