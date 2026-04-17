# CAPL filter for Doxygen
#
# ISC License:
# Copyright (c) 2016, Bretislav Rychta
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

use strict;
use warnings;

my $input = $ARGV[0];
my $includes = 0;
my $variables = 0;
my $line;

my $moduleName = $input;
$moduleName =~ s/.*[\/\\]//;            # remove path
$moduleName =~ s/\..*//;                # remove file extention
$moduleName =~ s/[^a-zA-Z0-9_]/_/g;     # replace any special characters by '_'
#$moduleName = uc($moduleName);          # module name capitalised

# event cause table (expand if needed)
# alsways add specific event before generic match
# note: the 'keys' need to be lower case!
my %eventMapping = (
    'timer'                   => ['evTimer',      'Timer Events'],
    'envvar'                  => ['evEnvVar',     'Environment Variable Events'],
    'sysvar_update'           => ['evSysVar',     'System  Variable Events'],
    'sysvar_change'           => ['evSysVar',     'System  Variable Events'],
    'sysvar'                  => ['evSysVar',     'System  Variable Events'],
    'key'                     => ['evKey',        'System  Variable Events'],

    #system
    'start'                   => ['evSystem',     'System Events '],
    'stop'                    => ['evSystem',     'System Events '],
    'prestart'                => ['evSystem',     'System Events '],
    'prestop'                 => ['evSystem',     'System Events '],

    #signals
    'signal_update'           => ['evSignal',     'Signal Events'],
    'signal_change'           => ['evSignal',     'Signal Events'],
    'signal'                  => ['evSignal',     'Signal Events'],
    'pdu'                     => ['evAUTOSAR',    'AUTOSAR Events'],
    'diagrequestsent'         => ['evDiag',       'Diagnostics / UDS Events'],
    'diagrequest'             => ['evDiag',       'Diagnostics / UDS Events'],
    'diagresponse'            => ['evDiag',       'Diagnostics / UDS Events'],

    # LIN events
    'linmessage'              => ['evLIN',        'LIN Events'],      # old event type
    'linframe'                => ['evLIN',        'LIN Events'],      # 
    'linreceiveerror'         => ['evLIN',        'LIN Events'],      #
    'lintransmerror'          => ['evLIN',        'LIN Events'],      #
    'linslavetimeout'         => ['evLIN',        'LIN Events'],      #
    'lincserror'              => ['evLIN',        'LIN Events'],      #
    'linsyncerror'            => ['evLIN',        'LIN Events'],      #
    'linschedulermodechange'  => ['evLIN',        'LIN Events'],      #
    'linsleepmodeevent'       => ['evLIN',        'LIN Events'],      #
    'linwakeupframe'          => ['evLIN',        'LIN Events'],      #

    # CAN events
    'message'                 => ['evCAN',        'CAN Events'],      #
    'errorframe'              => ['evCAN',        'CAN Events'],      #
    'busoff'                  => ['evCAN',        'CAN Events']       #
);

my $eventRegex = join('|', sort { length($b) <=> length($a) } keys %eventMapping);

main();
exit(0);

sub main
{
    open file_handler, "<$input" or die "Can't open $input for reading: $!";

    foreach my $line (<file_handler>)
    {
        #remove include and brackets
        if ($line =~ /^includes/)
        {
            $includes = 1;
            $line =~ s/includes//;
        }
        $line =~ s/#include.*//;
        if ($includes == 1)
        {
            if ($line =~ /\{/)
            {
                $line =~ s/\{//;
            }
            if ($line =~ /\}/)
            {
                $line =~ s/\}//;
                $includes = 0;
            }
        }

        #remove pragma
        $line =~ s/#pragma.*//;

        #remove variables and brackets
        if ($line =~ /^variables/)
        {
            $variables = 1;
            $line =~ s/variables//;
        }
        if ($variables > 0)
        {
            if ($line =~ /\{/)
            {
                if ($variables == 1)
                {
                    $line =~ s/\{//;
                }

                $variables = $variables + 1;
            }
            if ($line =~ /\}/)
            {
                $variables = $variables - 1;

                if ($variables == 1)
                {
                    $line =~ s/\}//;
                    $variables = 0;
                }
            }
        }

        #if ($line =~ /^[Oo]n\s+(timer|sysvar(?:_update|_change)?)\s+(\S+)(.*)/i)
        # \s* (\S*) makes second word optional
        if ($line =~ /^[Oo]n\s+($eventRegex)(?:\s+(\S+))?(.*)/i) 
        {
            my $type = lc($1);          # typ in lower case (z.B. sysvar_update)
            my $name = $2 || "";        # variable name, if none then keep empty
            my $remainder = $3;         # line remainder (comments, etc.)

            if (!exists $eventMapping{$type})
            {
                print STDERR "FEHLER: Typ '$type' nicht im Mapping definiert! (Zeile: $.)\n";
                # fallback 
                $eventMapping{$type} = ['evMisc', 'Miscellaneous Events'];
            }

            # cleanup "::" for non-empty namesysVar
            if ($name)
            {
                $name =~ s/::`/_/g;
                $name =~ s/::/_/g;
                #$name = "_$name";       # '_' as separator
            }

            # define group und titel
            my $MODULE = uc($moduleName);
            my $groupData  = $eventMapping{$type};
            my $groupIdSuffix = $groupData->[0];            # e.g. evTimer
            my $displayTitle  = $groupData->[1];            # e.g. Timer Events

            my $groupId     = "${moduleName}_$groupIdSuffix";
            my $groupTitle  = "$MODULE $displayTitle";

            # defining group with @addtogroup (Doxygen ignores doublicate definitions with @addtogroup)
            # Use @ingroup, to assigne the funtion to the correct group.
            # A void on_${type}_$name insures uniqueness of the fuction from the variable.
            # Compose the line in one step to avoid overwriting.
            print STDERR "[$MODULE] Group:$groupId Title:$groupTitle\n";
            print STDERR "    Name:$name Rem:$remainder\n";
            $line = "/** \@addtogroup $groupId $groupTitle \*/\n" .
                    "/** \@ingroup $groupId \*/\n" .
                    "void on_${type}_${name}()$remainder\n";

            #replace "on xyz" => "on_xyz()"
            #$line =~ s/^[Oo]n\s(\S+)/on_$1\(\)/;

            print STDERR "    L:$line\n";
        }

        print $line;
    }

    close file_handler;
}
