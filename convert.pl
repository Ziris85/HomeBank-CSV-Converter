#!/usr/bin/env perl

#
#
#        HomeBank CSV Converter
#
#         Author: Ziris85
#       Homepage: https://github.com/Ziris85/HomeBank-CSV-Converter
#        License: GPLv3.0
#        Version: 0.1
#
###########################################

use strict;
use warnings;
use Getopt::Long;
use Text::CSV;

my ($incsv,$outcsv,$csv);
my @arrcsv;

## If no file is provided, print usage
if ( ! $ARGV[0] || ! -f $ARGV[0]) {
    &usage();
} else {
    $incsv = shift @ARGV;
}

## Define our hash array for arguments, with some defaults defined
my %col = (sep => ",",header => "n",date => "",payment => "",info => "",payee => "",memo => "",amount => "",category => "",tags => "");

## Default to interactive mode, unless additional arguments detected
if (@ARGV) {
    GetOptions( \%col,
        'sep=s',
        'header=s',
        'autopay=s',
        'output=s',
        'date=i',
        'payment=i',
        'info=i',
        'payee=i',
        'memo=i',
        'amount=i',
        'category=i',
        'tags=i',
    );
    &convert();
} else {
    &interactive();
}

sub usage() {
    ## Print usage of script
	print "NAME\n    $0 - Homebank CSV Converter\n\nSYNOPSIS\n    $0 file.csv [COLUMNS] [OPTIONS]\n\nDESCRIPTION\n    User-friendly means of converting CSV files from your\n    banking institution to a Homebank-compatible format\n\n    If [COLUMNS] are provided, the script will immediately convert based on\n    those options (good for automation). Otherwise, the script will enter\n    into a guided, interactive mode.\n\n    Each of the [COLUMNS] must be a numerical value (starting from 0, not 1)\n    corresponding to the column number of your CSV that provides that information.\n    Not all [COLUMNS] must be provided - those that are not are simply\n    inserted as empty columns.\n\n   The [OPTIONS] simply tweak defaults of the automated run, if necessary.\n\n";
    print "COLUMNS\n    --date	Date of transation\n\n    --payment	Payment type code\n\n    --info      A string\n\n    --payee     A payee name\n\n    --memo      A string (usually a description of the transaction)\n\n    --amount    A number with a '.' or ',' as decimal separator, ex: -24.12 or 36,75\n\n    --category  A full category name (category, or category:subcategory)\n\n    --tags      Tags separated by space\n\n";
    print "OPTIONS\n    --output=s      Name of file to output results to\n                    (default: <input_file_name> + -homebank-exported.csv)\n\n    --sep=s         Separator to your CSV file (default: ,)\n\n    --header=[Y|n]  Specify whether your CSV file contains a header (defaut: n)\n\n    --autopay=[Y|#]     Enable automatic detection of payment codes. This can also be defined\n                    as a code, in which case ALL transactions in your CSV will be marked with said code.\n\n";
    exit(0);
}

sub convert() {
    ## Begin conversion process.
    ## homebank array will be populated with our converted data, and be pushed to the output file once finished
    my @homebank;

    ## Set the name of our output file, either automatically or to the users specified file
    if ($col{'output'}) {
        $outcsv = $col{'output'};
    } else {
        $outcsv = $incsv =~ s/.csv$/-homebank-exported.csv/ir;
    }
    
    if (-f $outcsv) {
        ## Output file already exists - ask if they wish to continue
        print "### WARNING ###\nDestination file '$outcsv' already exists! Continue? (This will overwrite the existing file) (Y/n) ";
        chomp(my $cont = lc(<STDIN>));
        if ($cont ne "y") {
            print "Exiting...";
            exit;
        }
    }

    ## Define our CSV reader object if not already defined
    $csv ||= Text::CSV->new({ sep_char => "$col{'sep'}"});
    if (! @arrcsv) {
        ## Read file into array (if not already done earlier)
        open (INCSV, "<", $incsv) or die "Could not open '$incsv': $!\n";
        @arrcsv = <INCSV>;
        close INCSV;
    }
    if ($col{'header'} eq "y") {
        ## Drop header
        shift @arrcsv;
    }
    foreach ( @arrcsv ){
        ## Loop through array of contents of CSV file
        if ($csv->parse($_)) {
            my @split = $csv->fields();
            my $line = "";
            if ($col{'autopay'} =~ /\d/) {
                ## User provided a payment code, so set ALL transactions to this code
                ## But first, is the code valid? If greater than 10 or less than 0, then no
                if ($col{'autopay'} < 0 || $col{'autopay'} > 10) {
                    print "Invalid payment code provided! Please see README for valid codes\n";
                    exit;
                }
            }
            foreach ('date','payment','info','payee','memo','amount','category','tags') {
                ## Loop through each of the Homebank columns for building our new line
                if ($_ eq "payment" && $col{'autopay'}) {
                    ## On payment column and autopay requested. Do this instead of read from array
                    if ($col{'autopay'} =~ /\d/) {
                        ## Autopay code given, so just push to line
                        $line = "$line\"$col{'autopay'}\";";
                    } elsif ($col{'autopay'} eq "y") {
                        ## Autopay enabled
                        if ($col{'memo'}) {
                            ## Required memo column provided, so pass to detectCode subroutine and push result to line
                            my $paycode = &detectCode($split[$col{'memo'}]);
                            $line = "$line\"$paycode\";";
                        } else {
                            print "Autopay requested, but no memo column specified (required for this).\nPlease provide memo column to use this feature. Exiting...\n";
                            exit;
                        }
                    }
                } elsif ($col{$_} =~ /\d/) {
                    ## Column number provided, so push contents of array to line
                    $line = "$line\"$split[$col{$_}]\";";
                } else {
                    ## Column number not provided, so just insert empty quotes
                    $line = "$line\"\";";
                }
            }
            ## Push completed line to homebank array
            push(@homebank,$line);
        } else {
            ## Line in array couldn't be read
            warn "Line could not be parsed: $_\n";
        }
    }
    ## Finished looping through contents of input file array. Now push converted array to output file
    open(OUTCSV,'>',$outcsv) or die "Could not open '$outcsv' for writing: $!\n";
    foreach (@homebank) {
        print OUTCSV "$_\n";
    }
    close OUTCSV;
    print "Conversion finished! Please review results for accuracy.\n";
}

sub interactive() {
    ## Welcome to interactive mode!
    my ($head,$opt) = ("","r");
    print "Welcome to the Homebank CSV converter script!\n\nThis will attempt to guide you through defining the columns in your CSV file\nto equivalent columns that Homebank recognizes.\n\n";
    ## Read file into array
	open (INCSV, "<", $incsv) or die "Could not open '$incsv': $!\n";
    @arrcsv = <INCSV>;
    close INCSV;
    ## Ask user if their CSV file has a header
    print "Firstly, does your CSV file have a header? (press enter for default: n ) ";
    chomp($col{'header'} = lc(<STDIN>));
    if ($col{'header'} eq "y") {
        ## Get rid of it from our array (but we still need it, so put it into a new variable)
        $head = shift (@arrcsv);
    } else {
        ## Don't get rid of data, so just read first line into our variable
        $head = $arrcsv[0];
    }
    ## Set this back to 'n' to not interfere with the conditional in the direct convert option
    $col{'header'} = "n";
    ## Ask user if their CSV uses a separator other than a ,
    print "Next, what is the separator for your file? (press enter for default: , ) ";
    chomp($col{'sep'} = <STDIN>);
    $col{'sep'} ||= ",";
    $csv = Text::CSV->new({ sep_char => "$col{'sep'}"});
    ## Can we read their data with the separator we want to use?
    if ($csv->parse($head)) {
        ## Reading confirmed, so split line to elements
        my @split = $csv->fields();
        ## Now ask user if we read it correctly by showing number and contents of columns
        print "\nI found " . scalar @split . " columns, with the following information:\n";
        foreach (@split) {
            print " - $_\n";
        }
        print "Does that look correct? (Y/n) ";
        chomp(my $cont = lc(<STDIN>));
        if ($cont eq "y") {
            ## User confirmed read properly
            print "\nGood! Now we need to assign each of these to Homebank-equivalent columns.\nNot every column needs to be defined,\nand not every column in your CSV may have an equivalent.\nFor each column, do your best to choose an equivalent,\nor 'None' to skip it and omit its data from the output file\n";
            ## Now, populate new hash array with header data to help user choose which match Homebank-equivalent columns
            my $i = 1;
            my %list = (0 => "None");
            foreach (@split) {
                $list{$i} = "$split[$i-1]";
                ++$i;
            }
            ## Looping through each Homebank column
            foreach ('date','payment','info','payee','memo','amount','category','tags') {
                ## Payment column, ask if user wishes to use autopay
                if ($_ eq "payment") {
                    print "Enable automatic detection of payment codes? Or set all transactions to a single code?\nSee README for limitations and caveats of this feature ";
                    chomp(my $resp = lc(<STDIN>));
                    if ($resp eq "y" || $resp =~ /\d/) {
                        $col{'autopay'} = $resp;
                        next;
                    }
                }
                ## Print all of the (remaining) options that haven't been defined yet
                foreach (sort keys %list) {
                    print "   $_ - $list{$_}\n";
                }
                ## Loop to require an integer that also hasn't already been selected
                while ($opt !~ /\d/ || ! $list{$opt}) {
                    print "Which of the following columns contains '$_' info? ";
                    chomp($opt = <STDIN>);
                }
                ## Unless None option selected (in which data in that column will be skipped in the output file)
                ## remove the selected option from the header array and set the column number
                unless ($opt == 0) {
                    $col{$_}=$opt-1;
                    delete $list{$opt};
                }
                ## Redefine opt var so input loop works on next iteration
                $opt="r";
            }
            ## All finished with user input and column definitions. Begin conversion
            print "All set! Conversion starting now...\n";
            &convert();
        }
    } else {
        ## Can't read data with that separator
        print "That separator doesn't appear to work. Please try again.\n";
        exit;
    }
}
sub detectCode() {
    ## Some regex fun trying to determine what paycode might best define contents of memo
    my $memo = $_[0];
    if ($memo =~ /(trans|x)fer/i) {
        return "4";
    } elsif ($memo =~ /bill\s?pay/i) {
        return "10";
    } elsif ($memo =~ /payment/i) {
        return "7";
    } elsif ($memo =~ /direct dep|deposit|((counter|teller) )?credit|interest/i) {
        return "8";
    } elsif ($memo =~ /withdrawal|debit card/i) {
        return "5";
    } elsif ($memo =~ /(che(que|ck)|chk)(\s?[0-9]+)?/i) {
        return "2";
    } elsif ($memo =~ /debit card/i) {
        return "5";
    } elsif ($memo =~ /cash/i) {
        return "3";
    } elsif ($memo =~ /fee/i) {
        return "9";
    } else {
        return "0";
    }
 }