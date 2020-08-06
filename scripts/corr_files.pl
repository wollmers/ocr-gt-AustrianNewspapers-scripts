#!perl

use strict;
use warnings;
use utf8;

use 5.010;

use Time::HiRes qw( time );

#use Sys::Hostname;

use Getopt::Long '2.32';
use Pod::Usage;

#use XML::Twig;
#use JSON::MaybeXS qw(JSON);

use Unicode::Normalize;
use charnames ':full';

use String::Similarity;
use Text::Levenshtein::BV;

use Data::Dumper;

our $VERSION = '0.01';

binmode(STDIN,  ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

#######################

our $options = {
    'update'  => 0,
    'help'    => 0,
    'man'     => 0,
    'quiet'   => 0,
    'verbose' => 1,    # TODO
};

GetOptions($options, 'update|u', 'help|h', 'man', 'quiet|q', 'verbose|v',)
    or pod2usage(2);
pod2usage(1) if $options->{'help'};
pod2usage(-exitval => 0, -verbose => 2) if $options->{'man'};

# or die("Error in command line arguments\n");

#######################

#my $infile = '';
#if (@ARGV >= 1) {
#  $infile = $ARGV[0];
#}
#pod2usage(1) unless ($infile);


our $config = {

    #'gtdir'      => '/Users/helmut/github/ocr-gt/AustrianNewspapers/',
    #'page_dir'   => '/Users/helmut/github/ocr-gt/ONB_newseye/',
    'page_dir' => '/Users/helmut/github/ocr-gt/AustrianNewspapers/',
    'line_dir' => '/Users/helmut/github/ocr-gt/AustrianNewspapers/',

   #'gtdir'      => '/Users/helmut/github/ocr-hw/ocr-gt-AustrianNewspapers-scripts/data/',
    'page_train' => 'TrainingSet_ONB_Newseye_GT_M1+',
    'page_eval'  => 'ValidationSet_ONB_Newseye_GT_M1+',
    'line_train' => 'gt/train',
    'line_eval'  => 'gt/eval',
    'lang_dir'   => '/Users/helmut/github/ocr-hw/ocr-gt-AustrianNewspapers-scripts/lang/',
    'corr_dir'   => '/Users/helmut/github/ocr-hw/ocr-gt-AustrianNewspapers-scripts/corr/',

    'pdftoppm'  => '/usr/local/bin/pdftoppm',     # pdftoppm version 0.71.0
    'tesseract' => '/usr/local/bin/tesseract',    # tesseract 5.0.0-alpha
    'pdftotext' => '/usr/local/bin/pdftotext',
    'tessdata'  => '/usr/local/share/tessdata',
    'convert'   => '/usr/local/bin/convert',
};

my $corr_file = $config->{'corr_dir'} . 'corr.txt';

open(my $in, "<:encoding(UTF-8)", $corr_file) or die "cannot open $corr_file: $!";

while (my $line = <$in>) {
    chomp $line;

    # ONB_nfp_19110701_006.tif_tl_14.gt.txt:
    if ($line =~ m/^([^:]+):(.*)$/) {
        my $outfile = $1;
        my $text    = $2;

        $outfile = $config->{'corr_dir'} . $outfile;

        print STDERR 'write ', $outfile,, "\n" if ($options->{'verbose'} >= 2);

        open(my $out, ">:encoding(UTF-8)", $outfile) or die "cannot open $outfile: $!";
        print $out $text, "\n";
        close $out;

    } ## end if ($line =~ m/^([^:]+):(.*)$/)
} ## end while (my $line = <$in>)

close $in;


=pod

__END__

=head1 NAME

check_xml.pl - compare and patch line text versus Page-XML

=head1 SYNOPSIS

check_xml.pl [options] infile

 Options:
   -help, -h        brief help message
   -man             full documentation

 Example:
 check_xml.pl -h


=head1 DESCRIPTION

B<This program> will compare and patch line text versus Page-XML.

=head1 OPTIONS

=over 8

=item B<-help, -h>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

'patch|p'

=item B<-patch, -p>

Patch differences between Ground Truth lines and Page-XML into Page-XML.

=item B<-verbose, -v>

Print detailed information.

=back

=cut

