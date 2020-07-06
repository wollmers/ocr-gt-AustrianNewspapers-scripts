package PageXML::Parse;

use strict;
use warnings;

use utf8;

use XML::Twig;
use JSON::MaybeXS qw(JSON);

use Data::Dumper;

binmode(STDOUT,":encoding(UTF-8)");
binmode(STDERR,":encoding(UTF-8)");

#my $XMLFILE = './isis_152.deu+deu-frak.hocr.html';

my $xml  = {};
my $index = {};

###############


sub new {
  my $class = shift;
  # uncoverable condition false
  bless @_ ? @_ > 1 ? {@_} : {%{$_[0]}} : {}, ref $class || $class;
}
###############

sub parse {
  my ($self,$XMLFILE) = @_;

  $xml = {};
  $index = {};

  my $twig = XML::Twig->new(
    #remove_cdata => 1,
    TwigHandlers => {
  	  '/Page'            => \&page,
  	  'RegionRefIndexed' => \&region_ref,
  	  'TextRegion'       => \&text_region,
    }
  );

  eval { $twig->parsefile($XMLFILE); };

  if ($@) {
    #print STDERR "XML PARSE ERROR: " . $@;
    die "XML PARSE ERROR: " . $@;
  }
  return ($xml,$index);
}

sub dump_json {
  my ($self,$tree) = @_;
  #my $json = JSON::MaybeXS->new(utf8 => 1, pretty => 1);
  #print JSON->new->utf8(1)->pretty(1)->encode($body);
  return JSON->new->pretty(1)->encode($tree);

  #print JSON->new->pretty(1)->encode($test_body);
}

#### functions ######
sub page {
  my ($twig, $element) = @_;

  $xml->{'Page'} = {
    'imageFilename' => $element->{'att'}->{'imageFilename'},
    'ReadingOrder'  => [],
    'TextRegions'   => [],
  };

  return 1;
}

sub region_ref {
  my ($twig,$element) = @_;

  my $entry =   	{
  		'index'     => $element->{'att'}->{'index'},
  		'regionRef' => $element->{'att'}->{'regionRef'},
  };

  #print STDERR '$xml: ',Dumper($xml);
  push @{$xml->{'Page'}->{'ReadingOrder'}}, $entry;

  return 1;
}

sub text_region {
  my ($twig,$element) = @_;

  my $region_entry =   	{
  		'id'        => $element->{'att'}->{'id'},
  		'TextLines' => [],
  		'TextEquiv' => '',
  };
  $index->{$region_entry->{'id'}} = $region_entry;

  my @children = $element->children();
  for my $child (@children) {
    if ($child->tag eq 'TextLine') {
      my $text = $child->first_child('TextEquiv')
      				->first_child('Unicode')->text;
      my $line_entry = {
         'id'     => $child->{'att'}->{'id'},
         'text'   => $text,
      };
      $index->{$line_entry->{'id'}} = $line_entry;
      push @{$region_entry->{'TextLines'}},$line_entry;
    }

    elsif ($child->tag eq 'TextEquiv') {
      my $text = $child->first_child('Unicode')->text;
      $region_entry->{'TextEquiv'} = $text;
    }
  }

  push @{$xml->{'Page'}->{'TextRegions'}},$region_entry;

  return 1;
}





