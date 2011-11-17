#!/usr/bin/perl -w
# perl version of the old mkcmds.sh script. Runs faster by simply not running
# a bazillion child processes. Also uses SelfLoader to avoid compiling functions
# that are never used, since it's usually invoked with at most 1 argument.
#

use SelfLoader;
use File::Compare;
use File::Copy;
use strict; # Please ma'am may I have another?

# SelfLoaded functions
use subs qw/make_switches make_cmds make_funs/;
# Always present functions
use subs qw/maybemove temp_header temp_source scan_files_for_pattern/;

# Main loop, dispatch for each command line argument.
foreach my $command (@ARGV) {
    if ($command eq "switches") {
        make_switches;
    } elsif ($command eq "commands") {
        make_cmds;
    } elsif ($command eq "functions") {
        make_funs;
    } elsif ($command eq "all") {
        make_switches;
        make_cmds;
        make_funs;
    } else {
        warn "Unknown option '${command}'\n";
    }
}

# Return name of a temp file in hdrs/
sub temp_header {
    return "hdrs/temp.$$.h";
}

# Return name of a temp file in src/
sub temp_source {
    return "src/temp.$$.c";
}

# maybemove(file1, file2) copies file1 to file 2 if they are different,
# otherwise just deletes file1 and leaves file2 unchanged.
sub maybemove {
    my ($from, $to) = @_;

    if (compare $from, $to) {
        if (move $from, $to) {
            print "File ${to} updated.\n";
        } else {
            warn "Couldn't rename ${from} to ${to}: $!\n";
        }
    } else {
        print "File ${to} unchanged.\n";
        unlink $from;
    }
}

# scan_files_for_pattern(glob-pattern, re) searches all files matching
# glob-pattern for lines matching re, and returns a sorted list of
# $1's for each matching line.
sub scan_files_for_pattern {
    my ($filepattern, $re) = @_;
    my @idents;

    foreach my $file (glob $filepattern) {
        open FILE, "<", $file
            or die "Cannot open ${file} for reading: $!\n";
        while (<FILE>) {
            chomp;
            push @idents, $1 if m/$re/;
        }
        close FILE;
    }
    return sort @idents;
}


END {
    # Make sure temp files get deleted.
    my @files = (temp_header(), temp_source());
    foreach my $file (@files) {
        unlink $file if -f $file;
    }
}

__DATA__

sub make_switches {
    print "Rebuilding command switch file and header.\n";

    my $temphdr = temp_header;
    my $tempsrc = temp_source;

    my @switches = scan_files_for_pattern "src/SWITCHES", qr/^(.+)/;

    open HDR, ">", $temphdr or
        die "Unable to open $temphdr for writing: $!\n";
    open SRC, ">", $tempsrc or
        die "Unable to open $tempsrc for writing: $!\n";

    print HDR <<EOH;
/* AUTOGENERATED FILE. DO NOT EDIT! */
#ifndef SWITCHES_H
#define SWITCHES_H
EOH

    my $nswitches = @switches;
    $nswitches += 1;

    print SRC <<EOS;
/* AUTOGENERATED FILE. DO NOT EDIT! */
SWITCH_VALUE switch_list[${nswitches}] = {
EOS

    my $n = 1;
    foreach my $switch (@switches) {
        print HDR "#define SWITCH_${switch} ${n}\n";
        print SRC "  {\"${switch}\", SWITCH_${switch}, 0},\n";
        $n++;
    }

    print SRC <<EOS;
  {NULL, 0, 0}
};
EOS
    close SRC;

    print HDR "#endif                          /* SWITCHES_H */\n";
    close HDR;

    maybemove $temphdr, "hdrs/switches.h";
    maybemove $tempsrc, "src/switchinc.c";
}

# I really should combine this and make_funs into one function that does
# the work with specific files/regexps/defines passed as arguments

sub make_cmds {
    print "Rebuilding command prototype header.\n";

    my $tempfile = temp_header;

    my @commands =
        scan_files_for_pattern "src/*.c", qr/^\s*COMMAND\(([^\)]+)\)/;

    open HDR, ">", $tempfile
        or die "Can't open ${tempfile} for writing: $!\n";


    print HDR <<EOH;
/* AUTOGENERATED FILE. DO NOT EDIT! */
#ifndef CMDS_H
#define CMDS_H
EOH

    foreach my $command (@commands) {
        print HDR "COMMAND_PROTO(${command});\n";
    }

    print HDR "#endif /* CMDS_H */\n";
    close HDR;

    maybemove $tempfile, "hdrs/cmds.h";

}

sub make_funs {
    print "Rebuilding function prototype header.\n";

    my $tempfile = temp_header;
    my @functions =
        scan_files_for_pattern "src/*.c", qr/^\s*FUNCTION\(([^\)]+)\)/;

    open HDR, ">", $tempfile
        or die "Can't open ${tempfile} for writing: $!\n";

    print HDR <<EOH;
/* AUTOGENERATED FILE. DO NOT EDIT! */
#ifndef FUNS_H
#define FUNS_H
EOH

    foreach my $function (@functions) {
        print HDR "FUNCTION_PROTO(${function});\n";
    }

    print HDR "#endif /* FUNS_H */\n";
    close HDR;

    maybemove $tempfile, "hdrs/funs.h";
}

