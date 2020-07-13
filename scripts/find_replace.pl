#!perl

use strict;
use warnings;
use utf8;

use 5.010;

use Time::HiRes qw( time );
#use Sys::Hostname;

use Getopt::Long  '2.32';
use Pod::Usage;

use File::Copy qw(move);

#use Data::Dumper;

our $VERSION = '0.01';

binmode(STDIN,":encoding(UTF-8)");
binmode(STDOUT,":encoding(UTF-8)");
binmode(STDERR,":encoding(UTF-8)");

#######################

our $options = {
  'update'      => 0,
  'help'        => 0,
  'man'         => 0,
  'quiet'       => 0,
  'verbose'     => 1, # TODO
};

GetOptions(
  $options,
  'update|u',
  'help|h',
  'man',
  'quiet|q',
  'verbose|v',
)
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
    'page_dir'   => '/Users/helmut/github/ocr-gt/AustrianNewspapers/',
    'line_dir'   => '/Users/helmut/github/ocr-gt/AustrianNewspapers/',
    #'gtdir'      => '/Users/helmut/github/ocr-hw/ocr-gt-AustrianNewspapers-scripts/data/',
    'page_train' => 'TrainingSet_ONB_Newseye_GT_M1+',
    'page_eval'  => 'ValidationSet_ONB_Newseye_GT_M1+',
    'line_train' => 'gt/train',
    'line_eval'  => 'gt/eval',
    'lang_dir'   => '/Users/helmut/github/ocr-hw/ocr-gt-AustrianNewspapers-scripts/lang/',
    'corr_dir'   => '/Users/helmut/github/ocr-hw/ocr-gt-AustrianNewspapers-scripts/corr/',

    'pdftoppm'  => '/usr/local/bin/pdftoppm',  # pdftoppm version 0.71.0
    'tesseract' => '/usr/local/bin/tesseract', # tesseract 5.0.0-alpha
    'pdftotext' => '/usr/local/bin/pdftotext',
    'tessdata'  => '/usr/local/share/tessdata',
    'convert'   => '/usr/local/bin/convert',
};

our $stats = {
  'pages_total'     => 0,
  'pages_different' => {}, # ->{$pagename}++;
  'lines_total'     => 0,
  'lines_different' => 0,
};

our $target_page  = 'ONB_nfp_19110701_028';
our $current_file = '';
our $current_dir  = '';
#our @files;
my $file_count = 0;
my $file_skip  = 0;
my $file_limit = 0;

our $matched_count = 0;

### collect stats


#/Users/helmut/github/ocr-gt/AustrianNewspapers/gt/eval/  ONB_aze_18950706_4/ONB_aze_18950706_4.jpg_tl_1.gt.txt
for my $dir (qw(line_train line_eval)) {
    $current_dir = $dir;
    my $dir_name = $config->{'line_dir'} . $config->{$dir};
    opendir(my $dir_dh, "$dir_name") || die "Can't opendir $dir_name: $!";
    my @subdirs = grep { /^[^._]/ && -d "$dir_name/$_" } readdir($dir_dh);
    closedir $dir_dh;

    # ONB_aze_18950706_4
    SUBDIR: for my $subdir (@subdirs) {
        next SUBDIR unless ($target_page eq $subdir);
        my $document = $subdir;
        $document =~ s/_\d+$//; # remove page number
        my $subdir_name = $config->{'line_dir'} . $config->{$dir} . '/' . $subdir;
        opendir(my $subdir_dh, "$subdir_name") || die "Can't opendir $subdir_name: $!";
        my @files = grep { /^[^._]/ && /\.txt$/i && -f "$subdir_name/$_" } readdir($subdir_dh);
        closedir $subdir_dh;

        FILE: for my $file (@files) {
            $file_count++;
            last if ($file_limit && $file_count > $file_limit);
            next FILE if ($file_skip >= $file_count);

            $current_file = $subdir_name . '/' . $file;
            print STDERR 'current TXT-file: ', $current_file, "\n" if ($options->{'verbose'} >= 3);
            parse_line($current_file);
        }
    }
}

print STDERR '$matched_count: ', $matched_count, "\n" if ($options->{'verbose'} >= 3);


############################

sub parse_line {
  my ($file) = @_;

  #my $pattern = qr/^s/;
  #my $pattern = qr/ s/;
  #my $pattern = qr/st/;
  #my $pattern = qr/s[pks]/;
  #my $pattern = qr/rc\./;
  #my $pattern = qr/m2/;
  #my $pattern = qr/[=-]/;

  open(my $in,"<:encoding(UTF-8)",$file) or die "cannot open $file: $!";

  my $line = <$in>;
  chomp $line;

  close($in);

  if ($line =~ m/^([1]?[0-9])([0-5][0-9])$/) {
      $matched_count++;

      my $hour    = $1;
      my $minutes = $2;
      $minutes    =~ tr/0123456789/⁰¹²³⁴⁵⁶⁷⁸⁹/;

      my $newline = $hour . $minutes;

      print STDERR 'matches: ', $file,
              "\n", '$matched_count: [',$matched_count,'/',$file_count, '] $line: ',
              	$line,' => ', $newline,"\n" if ($options->{'verbose'} >= 1);

      if (1) {
      		my $bakfile = $file . '.bak';
      		move $file,$bakfile;

      		open(my $out,">:encoding(UTF-8)",$file) or die "cannot open $file: $!";

      		print $out $newline;
      		close($out);
      }
  }
}

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

