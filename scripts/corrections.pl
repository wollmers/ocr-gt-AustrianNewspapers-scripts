#!perl

use strict;
use warnings;
use utf8;

use 5.010;

use Time::HiRes qw( time );
#use Sys::Hostname;

use Getopt::Long  '2.32';
use Pod::Usage;

#use XML::Twig;
#use JSON::MaybeXS qw(JSON);

use Unicode::Normalize;
use charnames ':full';

use String::Similarity;
use Text::Levenshtein::BV;

use Data::Dumper;

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

our $current_file = '';
our $current_dir  = '';
#our @files;
my $file_count = 0;
my $file_skip  = 50000;
my $file_limit = 60000;

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
    for my $subdir (@subdirs) {
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
  my $pattern = qr/[=-]/;

  open(my $in,"<:encoding(UTF-8)",$file) or die "cannot open $file: $!";

  while (my $line = <$in>) {
      chomp $line;

      if ($line =~ m/$pattern/) {
          $matched_count++;

          print STDERR 'matches /st/: ', $file,
              "\n", '$matched_count: [',$matched_count,'/',$file_count, '] $line: ',
              	$line,"\n" if ($options->{'verbose'} >= 2);
          check_line($file, $line, $pattern);
      }
   }

   close $in;
}

sub check_line {
    my ($file, $line, $pattern) = @_;

    my $imagefile = $file;

    print STDERR '$file: ', $imagefile, "\n" if ($options->{'verbose'} >= 2);

    $imagefile =~ s/gt\.txt$/png/;

    my $target_dir;
    my $target_file;
    my $ocr_txt_file;

    if ($imagefile =~ m!^(.+/)([^/]+)!) {
        $target_dir   = $1;
        $target_file  = $2;
        $ocr_txt_file = $2;
        $target_dir   =~ s/$config->{'line_dir'}/$config->{'corr_dir'}/;
        $target_file  =~ s/\.png$/.corr.txt/;
        $ocr_txt_file =~ s/\.png$/.ocr.txt/;
    }
    print STDERR '$target_dir: ',$target_dir,"\n",
    		' $target_file: ',$target_file,"\n",
    		' $ocr_txt_file: ',$ocr_txt_file,"\n" if ($options->{'verbose'} >= 2);

    unless(-e $target_dir.$ocr_txt_file && -f $target_dir.$ocr_txt_file) {
    		ocr_line($imagefile,$target_dir,$ocr_txt_file);
    		#print STDERR '$ocr_txt_file: ',$ocr_txt_file,"\n" if ($options->{'verbose'} >= 1);
    		#print STDERR '$line:     ',$line,"\n" if ($options->{'verbose'} >= 1);
    		#print STDERR '$ocr_line: ',$ocr_line,"\n" if ($options->{'verbose'} >= 1);
    }

	my $ocr_result = read_ocr($target_dir, $ocr_txt_file);

    my @ocr_lines = split(/\n/, $ocr_result);

    my $best_similarity =  0;
    my $line_index      = -1;

    for my $ocr_line (@ocr_lines) {
      chomp $ocr_line;
      $line_index++;

      if (similarity($ocr_line,$line) > $best_similarity && $ocr_line =~ m/ſ/) {
      #if ($ocr_line eq $line && $ocr_line =~ m/ ſ/) {
        print STDERR 'matches / s/: ', $file,
              "\n", '$matched_count: [',$matched_count,'/',$file_count, '] $line: ',
              	$line,"\n" if ($options->{'verbose'} >= 1);
        print STDERR '$ocr_line matches / s/',"\n" if ($options->{'verbose'} >= 2);
        print STDERR '$line:     ',$line,"\n" if ($options->{'verbose'} >= 1);
        print STDERR '$ocr_line: ',$ocr_line,"\n" if ($options->{'verbose'} >= 1);
      }
    }
    if ($line_index >= 0 && $best_similarity > 0) {
        my $ocr_line = $ocr_lines[$line_index];
        print STDERR 'matches /',$pattern ,'/: ', $file,
              "\n", '$matched_count: [',$matched_count,'/',$file_count, '] $line: ',
              	$line,"\n" if ($options->{'verbose'} >= 1);
        print STDERR '$ocr_line matches / s/',"\n" if ($options->{'verbose'} >= 2);
        print STDERR '$line:     ',$line,"\n" if ($options->{'verbose'} >= 1);
        print STDERR '$ocr_line: ',$ocr_line,"\n" if ($options->{'verbose'} >= 1);
    }
}

#/Users/helmut/github/ocr-gt/AustrianNewspapers                      /gt/eval/
#							ONB_aze_18950706_4/ONB_aze_18950706_4.jpg_tl_1.gt.txt
#/Users/helmut/github/ocr-hw/ocr-gt-AustrianNewspapers-scripts/corr/ gt/eval/
sub ocr_line {
    my ($imagefile,$target_dir,$ocr_txt_file) = @_;

    $ENV{'TESSDATA_PREFIX'} = $config->{'tessdata'} if $config->{'tessdata'};

    my $basename = $ocr_txt_file;
    $basename =~ s/\.txt$//i;

    my $command  = $config->{'tesseract'};
    my $language = '-l deu+frk';
    #my $tess_options  = '-c tessedit_write_images=true'; # writes tessinput.tif
    #my $files    = 'makebox hocr txt pdf';       # writes $base.box $base.hocr $base.txt
    my $files    = 'txt';          # writes $base.txt
    #$files = $options->{'file_format'};
    my $tessdata = '';
    $tessdata = '--tessdata-dir ' . $config->{'tessdata'} if $config->{'tessdata'};
    #my $psm = '--psm 4';
    my $psm = '';
    #if ($options->{'psm'} =~ m/^\d{1,2}$/) {
    #   $psm = '--psm ' . $options->{'psm'};
    #}

    #$basename =~ s/\.(png|jpg|tif|gif)$//i;

    #my @command = ($command, $imagefile, $basename, $language, $tess_options, $tessdata, $files);
    my @command = ($command, $imagefile, $basename, $language, $psm, $tessdata, $files);

    my $command_string = join(' ', @command);
    print STDERR $command_string, "\n" if ($options->{'verbose'} >= 2);
    system($command_string);

    if ($? == -1) {
      die "$command $imagefile failed: $!";
    }

    #my $new_name = $basename . '.tessinput.tif';
    #if (-e 'tessinput.tif' && -f 'tessinput.tif') {
    #  rename('tessinput.tif',"$new_name");
    #}

}

sub read_ocr {
	my ($target_dir,$ocr_txt_file) = @_;

    my $ocr_txt_result = '';
    if (-e $ocr_txt_file && -f $ocr_txt_file) {
        #$target_dir,$ocr_txt_file

     	open(my $in,"<:encoding(UTF-8)",$ocr_txt_file) or die "cannot open $ocr_txt_file: $!";

  		while (my $line = <$in>) {
     		$ocr_txt_result .= $line;
   		}
   		close $in;

        my $command_string = "mv $ocr_txt_file $target_dir$ocr_txt_file";
        print STDERR $command_string, "\n" if ($options->{'verbose'} >= 2);
        system($command_string);

    		if ($? == -1) {
        		die "$command_string failed: $!";
    		}
    	}
	return $ocr_txt_result;
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

