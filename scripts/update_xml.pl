#!perl

use strict;
use warnings;
use utf8;
#use utf8::all;

use 5.010;

use Time::HiRes qw( time );
use Sys::Hostname;

use Getopt::Long  '2.32';
use Pod::Usage;

use XML::Twig;
#use JSON::MaybeXS qw(JSON);

use Data::Dumper;

our $VERSION = '0.01';

binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT,":encoding(UTF-8)");
binmode(STDERR,":encoding(UTF-8)");

#######################

our $options = {
  'update'      => 0,
  'help'        => 0,
  'man'         => 0,
  'quiet'       => 0,
  'verbose'     => 0, # TODO
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
    #'page_dir'   => '/Users/helmut/github/ocr-gt/ONB_newseye/',

    ### dir of github/[wollmers|UB-Mannheim]/AustrianNewspapers
    #'gtdir'      => '/Users/helmut/github/ocr-gt/AustrianNewspapers/',
    'page_dir'   => '/Users/helmut/github/ocr-gt/AustrianNewspapers/',
    'line_dir'   => '/Users/helmut/github/ocr-gt/AustrianNewspapers/',

    ### dir for tests
    #'gtdir'      => '/Users/helmut/github/ocr-hw/ocr-gt-AustrianNewspapers-scripts/data/',
    #'page_dir'   => '/Users/helmut/github/ocr-hw/ocr-gt-AustrianNewspapers-scripts/data/',
    #'line_dir'   => '/Users/helmut/github/ocr-hw/ocr-gt-AustrianNewspapers-scripts/data/',

    ### subdirs
    'page_train' => 'TrainingSet_ONB_Newseye_GT_M1+',
    'page_eval'  => 'ValidationSet_ONB_Newseye_GT_M1+',
    'line_train' => 'gt/train',
    'line_eval'  => 'gt/eval',
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
my $file_limit = 0;

for my $dir (qw(page_train page_eval)) {
  $current_dir = $dir;
  my $dir_name = $config->{'page_dir'} . $config->{$dir};
  opendir(my $dir_dh, "$dir_name") || die "Can't opendir $dir_name: $!";
  my @files = grep { /^[^._]/ && /\.xml$/i && -f "$dir_name/$_" } readdir($dir_dh);
  closedir $dir_dh;

  for my $file (@files) {
    $file_count++;
    last if ($file_limit && $file_count > $file_limit);

    $stats->{'pages_total'}++;

    $current_file = $dir_name . '/' . $file;
    print STDERR 'current XML-file: ', $current_file, "\n"
    		if ($options->{'verbose'} >= 1);
    parse($current_file);
  }
}

print_stats();

############################

sub print_stats {
  #my ($stats) = @_;

  print STDERR 'Pages total:     ', $stats->{'pages_total'}, "\n";
  print STDERR 'Pages different: ', scalar(keys %{$stats->{'pages_different'}}), "\n";
  print STDERR 'Lines total:     ', $stats->{'lines_total'}, "\n";
  print STDERR 'Lines different: ', $stats->{'lines_different'}, "\n";

}

sub parse {
  my ($XMLFILE) = @_;

=pod

my $twig= XML::Twig->new(
    pretty_print => 'indented',
    twig_roots => {
        jdk => sub{
            my ($t, $jdk) = @_;
            $jdk->set_text( 'JDK 1.8.0_40' );
            $jdk->print;
            $jdk->purge;
            return;
        },
    },
    twig_print_outside_roots => 1,
);

$twig->parsefile_inplace( 'nightly.xml', '.bak' );
$twig->flush;

  if ($oldtext ne $text) {
      my $bakfile = $oldfile . '.bak';
      move $oldfile,$bakfile;

      open(my $out,">:encoding(UTF-8)",$oldfile)
          or $self->app->log->debug("cannot open $oldfile: $!");

      print $out $text;
      close($out);
  }

 $twig->parsefile( $file);
 my($outfile) = $file;
 $outfile =~ s/([.]dita)/.out$1/i;

# current best practices recommend the  use the 3 args form of
# open and lexical filehandles
open( my $out,'>', $outfile);
$twig->flush( $out);
close( $out);

=cut

  # /PcGts/Page/TextRegion
  my $twig = XML::Twig->new(
    pretty_print => 'indented',
    #pretty_print => 'wrapped',
    #pretty_print => 'indented_a',
    keep_atts_order => 1,
    #keep_encoding => 1,
    output_encoding => 'UTF-8',
    #remove_cdata => 1,
    TwigHandlers => {
    #twig_roots => {
  	  #'/PcGts/Page/TextRegion' => \&text_region,
  	  '/PcGts/Page' => \&page,
    },
    #twig_print_outside_roots => 1,
  );


  #eval { $twig->parsefile($XMLFILE); };
  eval { $twig->parsefile_inplace( $XMLFILE, '.bak' ); };

  if ($@) {
    print STDERR "XML PARSE ERROR: " . $@;
    print STDERR 'file: ',$current_file, ' dir: ',$current_dir ,"\n";
    #die "XML PARSE ERROR: " . $@;
  }

  open(my $xml_out,">:encoding(UTF-8)",$XMLFILE)
            or die "cannot open $XMLFILE: $!";
  $twig->flush( $xml_out);
  close( $xml_out );

  return;
}

# <TextRegion type="paragraph" id="r_1_3" custom="readingOrder {index:2;}">
#sub text_region {
sub page {
  my ($twig, $Page) = @_;

  # /PcGts
  # <Page imageFilename="ONB_ibn_18640702_006.tif"

  #my $Page_imageFilename = $TextRegion->parent()->att('imageFilename');
  my $Page_imageFilename = $Page->att('imageFilename');
  print STDERR '$Page_imageFilename: ',
  	$Page_imageFilename,"\n" if ($options->{'verbose'} >= 2);

  my @TextRegions = $Page->children( 'TextRegion');

TR: for my $TextRegion (@TextRegions) {

  # <TextEquiv>
  #   <Unicode>Provinz (inklusive Porto) 5 kr.
  #     Abendblatt 5 kr.</Unicode>
  my $TextEquiv = $TextRegion->first_child( 'TextEquiv');

  # ERROR $TextEquiv not defined: ONB_ibn_19110701_008.tif TextRegion_id=region_1547026084602_43
  # <TextRegion id="region_1547026084602_43" custom="readingOrder {index:115;}">
  #       <Coords points="3008,4591 3047,4591 3047,4649 3008,4649"/>
  #    </TextRegion>
  if (!defined $TextEquiv) {
    print STDERR 'WARN $TextEquiv not defined, skipped: ', $Page_imageFilename,
      ' TextRegion_id=',$TextRegion->att('id'),"\n";
      #return 0;
      next TR;
  }
  my $TextEquiv_unicode = $TextEquiv->first_child('Unicode');
  if (!defined $TextEquiv_unicode) {
    print STDERR 'WARN $TextEquiv_unicode not defined, skipped: ', $Page_imageFilename,
      ' TextRegion_id=',$TextRegion->att('id'),"\n";
      #return 0;
      next TR;
  }
  my $TextEquiv_text    = $TextEquiv_unicode->text();
  my @TextEquiv_text    = split("\n",$TextEquiv_text); # assumes Unix(LF) line endings

  print STDERR '@TE_text: ', "\n  ",join("\n  ",@TextEquiv_text),"\n"
  	if ($options->{'verbose'} >= 2);


  # <TextLine id="tl_3" primaryLanguage="German" custom="readingOrder {index:0;}">
  #   <TextEquiv>
  #     <Unicode>Provinz (inklusive Porto) 5 kr.</Unicode>
  my @TextLines = $TextRegion->children( 'TextLine');
  print STDERR '@TextLines: ', Dumper(\@TextLines), "\n"
  	if ($options->{'verbose'} >= 3);

  if (scalar(@TextEquiv_text) != scalar(@TextLines)) {
    print STDERR 'WARN: line count differs TextEquiv <=> TextLine(s)',
      ' in file: ', $current_file, ' TextRegion id=', $TextRegion->att( 'id'),"\n"
        if ($options->{'verbose'} >= 1);
  }

  my $textlines = {}; # collect textlines from line_files

  for my $TextLine (@TextLines) {

	my $TL_id      = $TextLine->att( 'id');
  	my $custom     = $TextLine->att( 'custom');
  	my $TL_unicode = $TextLine->first_child( 'TextEquiv')->first_child('Unicode');
    	my $TL_text    = $TL_unicode->text();

    	print STDERR '$TL_id: ', $TL_id, ' $custom: ', $custom,
    		"\n", ' $TL_text: ', $TL_text, "\n"
     	if ($options->{'verbose'} >= 2);

	$stats->{'lines_total'}++;

	my $readingOrder;
	if ($custom =~ m/readingOrder\s*\{\s*index\s*:\s*(\d+)\s*;\s*\}/) {
   		$readingOrder = $1;
    		print STDERR '$readingOrder: ', $readingOrder, "\n"
    			if ($options->{'verbose'} >= 2);
   	}

    if (defined($readingOrder) && defined($TextEquiv_text[$readingOrder])
            && $TL_text ne $TextEquiv_text[$readingOrder]) {
          print STDERR 'DIFF line text different: ',
              "\n", ' $TL_text: ', $TL_text,
              "\n", ' $TextEquiv_text: ', $TextEquiv_text[$readingOrder], "\n"
                if ($options->{'verbose'} >= 1);
    }
	my $line_file = page2line_name($Page_imageFilename, $TL_id);

	if (-f $line_file) {
   		print STDERR '$line_file: ', $line_file, "\n" if ($options->{'verbose'} >= 2);

      	open(my $line_fh,"<:encoding(UTF-8)",$line_file)
            or die "cannot open $line_file: $!";

     	LINE: while (my $line = <$line_fh>) {
        		chomp $line;
        		$textlines->{$readingOrder} = $line;

            if ($line ne $TL_text) {

              $TL_unicode->set_text( $line );

              print STDERR 'DIFF line text different: ',
                $Page_imageFilename,' TL_id=', $TL_id,
                "\n", ' TL_text:   ', $TL_text,
                "\n", ' line file: ', $line, "\n"
                    if ($options->{'verbose'} >= 1);

                $stats->{'pages_different'}->{$Page_imageFilename}++;
                $stats->{'lines_different'}++;
              last LINE;
            }
     	}
    		close $line_fh;
    }
    my @new_lines = ();
    for my $textline (sort { $a <=> $b }keys %$textlines) {
      push @new_lines, $textlines->{$textline};
    }
    my $new_lines_text = join("\n",@new_lines);
    $new_lines_text //= '';
    $TextEquiv_unicode->set_text( $new_lines_text );
  }
}
  #$Page->print;
  #$Page->purge;
  return 1;
}

# ONB_aze_18950706_1.xml
# $page_name =~ s/\.(xml|pdf|txt|tif|tiff|jpg|jpeg|png)$//i;

# ONB_aze_18950706_4.jpg_tl_1.gt.txt
# $line_name =~ s/\.gt\.(xml|pdf|txt|tif|tiff|jpg|jpeg|png)$//i;

#/Users/helmut/github/ocr-gt/AustrianNewspapers/TrainingSet_ONB_Newseye_GT_M1+
#/Users/helmut/github/ocr-gt/AustrianNewspapers/ValidationSet_ONB_Newseye_GT_M1+


#/Users/helmut/github/ocr-gt/AustrianNewspapers/gt/eval/ONB_aze_18950706_4
#/Users/helmut/github/ocr-gt/AustrianNewspapers/gt/eval/ONB_aze_18950706_4/ONB_aze_18950706_4.jpg_tl_1.gt.txt
#/Users/helmut/github/ocr-gt/AustrianNewspapers/gt/train

sub page2line_name {
  my ($Page_imageFilename, $TL_id) = @_;

  my $page_name = $Page_imageFilename;
  $page_name =~ s/\.(xml|pdf|txt|tif|tiff|jpg|jpeg|png)$//i;

  my $sub_dir   = $current_dir;
  $sub_dir      =~ s/page/line/; # page_(eval|train)
  my $dir       = $config->{'line_dir'} . $config->{$sub_dir} . '/' . $page_name . '/';
  my $line_file = $dir . $Page_imageFilename . '_' . $TL_id . '.gt.txt';

  return $line_file;
}

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

