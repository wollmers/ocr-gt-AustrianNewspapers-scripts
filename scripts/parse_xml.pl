#!perl

use strict;
use warnings;

use utf8;

binmode(STDOUT,":encoding(UTF-8)");
binmode(STDERR,":encoding(UTF-8)");

use lib qw(../lib);

use PageXML::Parse;



our $config = {
    #'gtdir'      => '/Users/helmut/github/ocr-gt/AustrianNewspapers/',

    #'page_dir'   => '/Users/helmut/github/ocr-gt/ONB_newseye/',
    'page_dir'   => '/Users/helmut/github/ocr-gt/AustrianNewspapers/',
    'line_dir'   => '/Users/helmut/github/ocr-gt/AustrianNewspapers/',
    #'page_dir'   => '/Users/helmut/github/ocr-hw/ocr-gt-AustrianNewspapers-scripts/data/',
    #'line_dir'   => '/Users/helmut/github/ocr-hw/ocr-gt-AustrianNewspapers-scripts/data/',

    #'gtdir'      => '/Users/helmut/github/ocr-hw/ocr-gt-AustrianNewspapers-scripts/data/',

    'page_train' => 'TrainingSet_ONB_Newseye_GT_M1+',
    'page_eval'  => 'ValidationSet_ONB_Newseye_GT_M1+',
    'line_train' => 'gt/train',
    'line_eval'  => 'gt/eval',
};

for my $dir (qw(page_train page_eval)) {
  #$current_dir = $dir;
  my $dir_name = $config->{'page_dir'} . $config->{$dir};
  opendir(my $dir_dh, "$dir_name") || die "Can't opendir $dir_name: $!";
  my @files = sort grep { /^[^._]/ && /\.xml$/i && -f "$dir_name/$_" } readdir($dir_dh);
  closedir $dir_dh;

  for my $file (@files) {

    my $current_file = $dir_name . '/' . $file;

    print STDERR 'xml_file: ',$current_file, "\n";

    my $parser = PageXML::Parse->new();

    my ($tree,$index) = $parser->parse($current_file);

    my $json = $parser->dump_json($tree);

    my $json_file = $current_file;
    $json_file =~ s/\.xml$/.json/;

    open(my $out,">:encoding(UTF-8)",$json_file)
          or die "cannot open $json_file: $!";

    print $out $json;

  }
}



my $XMLFILE = '../data/ValidationSet_ONB_Newseye_GT_M1+/ONB_aze_18950706_4.xml';

my $parser = PageXML::Parse->new();

my ($tree,$index) = $parser->parse($XMLFILE);

$parser->dump_json($tree);

#my $word = $index->{"word_1_766"};

#$parser->dump_json($word);
