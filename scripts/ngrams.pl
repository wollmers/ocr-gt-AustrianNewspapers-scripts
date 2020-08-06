#!perl

use strict;
use warnings;
use utf8;

use 5.020;    # regex_sets need 5.18

no warnings "experimental::regex_sets";

use Time::HiRes qw( time );

#use Sys::Hostname;

use Getopt::Long '2.32';
use Pod::Usage;

use XML::Twig;

#use JSON::MaybeXS qw(JSON);

use Unicode::Normalize;
use charnames ':full';

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
    'verbose' => 0,    # TODO
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
};

our $stats = {
    'pages_total'     => 0,
    'pages_different' => {},    # ->{$pagename}++;
    'lines_total'     => 0,
    'lines_different' => 0,
};


### collect stats

my $page_count     = 0;
my $grapheme_count = 0;
my $line_count     = 0;
my $word_count     = 0;
my $char_count     = 0;
my $bigram_count   = 0;
my $trigram_count  = 0;

my $documents              = {};
my $grapheme_frequency     = {};
my $word_frequency         = {};
my $char_frequency         = {};
my $length_frequency       = {};
my $alphabet_frequency     = {};
my $char_bigram_frequency  = {};
my $char_trigram_frequency = {};

=pod
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
        $documents->{$document}++;
        $page_count++;
        my $subdir_name = $config->{'line_dir'} . $config->{$dir} . '/' . $subdir;
        opendir(my $subdir_dh, "$subdir_name") || die "Can't opendir $subdir_name: $!";
        my @files = grep { /^[^._]/ && /\.txt$/i && -f "$subdir_name/$_" } readdir($subdir_dh);
        closedir $subdir_dh;

        for my $file (@files) {
            $file_count++;
            last if ($file_limit && $file_count > $file_limit);

            $current_file = $subdir_name . '/' . $file;
            print STDERR 'current TXT-file: ', $current_file, "\n" if ($options->{'verbose'} >= 1);
            parse_line($current_file);
        }
    }
}
=cut

################

our $current_file = '';
our $current_dir  = '';

#our @files;
my $file_count = 0;
my $file_limit = 0;

our $last_word = '';

for my $dir (qw(page_train page_eval)) {
    $current_dir = $dir;
    my $dir_name = $config->{'page_dir'} . $config->{$dir};
    opendir(my $dir_dh, "$dir_name") || die "Can't opendir $dir_name: $!";
    my @files = grep { /^[^._]/ && /\.xml$/i && -f "$dir_name/$_" } readdir($dir_dh);
    closedir $dir_dh;

    for my $file (@files) {
        $file_count++;
        $page_count++;
        last if ($file_limit && $file_count > $file_limit);

        my $document = $file;
        $document =~ s/_\d+\.xml$//;    # remove page number
        $documents->{$document}++;

        $stats->{'pages_total'}++;

        $current_file = $dir_name . '/' . $file;
        print STDERR 'current XML-file: ', $current_file, "\n"
            if ($options->{'verbose'} >= 1);
        parse($current_file);
    } ## end for my $file (@files)
} ## end for my $dir (qw(page_train page_eval))

#print_stats();

############################


### collect stats

my $dict = $config->{'lang_dir'} . '/' . 'dict';

my $words_file = $dict . '.words.txt';
open(my $words_fh, ">:encoding(UTF-8)", $words_file) or die "Can't open  $words_file: $!";

my $stats_file = $dict . '.stats.txt';
open(my $stats_fh, ">:encoding(UTF-8)", $stats_file) or die "Can't open  $stats_file: $!";

my $chars_file = $dict . '.chars.txt';
open(my $chars_fh, ">:encoding(UTF-8)", $chars_file) or die "Can't open  $chars_file: $!";

my $bigrams_file = $dict . '.bigrams.txt';
open(my $bigrams_fh, ">:encoding(UTF-8)", $bigrams_file)
    or die "Can't open  $bigrams_file: $!";

my $trigrams_file = $dict . '.trigrams.txt';
open(my $trigrams_fh, ">:encoding(UTF-8)", $trigrams_file)
    or die "Can't open  $trigrams_file: $!";

#################
my $bigrams_unique   = scalar keys %{$char_bigram_frequency};
my $trigrams_unique  = scalar keys %{$char_trigram_frequency};
my $documents_unique = scalar keys %{$documents};
my $words_unique     = scalar keys %{$word_frequency};

##### print stats
print $stats_fh $0, ' Version ', $VERSION, "\n";
print $stats_fh "\n";
print $stats_fh 'Statistics of wordlist file:', "\n";

#for my $dict (keys %{$dicts}) {
print $stats_fh '  ', 'dict', ' ', $dict, "\n";

#}
print $stats_fh "\n";

print $stats_fh 'documents:       ', sprintf('%15s', $documents_unique), "\n";
print $stats_fh 'pages:           ', sprintf('%15s', $page_count),       "\n";
print $stats_fh 'lines:           ', sprintf('%15s', $line_count),       "\n";
print $stats_fh 'words:           ', sprintf('%15s', $word_count),       "\n";
print $stats_fh 'words unique:    ', sprintf('%15s', $words_unique),     "\n";
print $stats_fh 'chars:           ', sprintf('%15s', $char_count),       "\n";
print $stats_fh 'graphemes:       ', sprintf('%15s', $grapheme_count),   "\n";
print $stats_fh 'bigrams:         ', sprintf('%15s', $bigram_count),     "\n";
print $stats_fh 'bigrams unique:  ', sprintf('%15s', $bigrams_unique),   "\n";
print $stats_fh 'trigrams:        ', sprintf('%15s', $trigram_count),    "\n";
print $stats_fh 'trigrams unique: ', sprintf('%15s', $trigrams_unique),  "\n";

my $alphabet_size = scalar(keys %{$char_frequency});
print $stats_fh 'alphabet size :  ', sprintf('%15s', $alphabet_size), "\n";
print $stats_fh 'word size avg.:  ',
    sprintf('%15s', sprintf('%0.2f', ($char_count / $word_count))), "\n";

print $stats_fh "\n";
print $stats_fh '**********************', "\n";
print $stats_fh '*** char frequency ***', "\n";
print $stats_fh '**********************', "\n";

my $char_rank = 0;
my $cumulated = 0;
print $stats_fh sprintf('%4s', 'rank'), sprintf('%5s', 'char'), sprintf('%12s', 'count'),
    sprintf('%9s', '%'), sprintf('%9s', 'cum. %'), "\n";
print $stats_fh sprintf('%4s', '----'), sprintf('%5s', '----'), sprintf('%12s', '-----'),
    sprintf('%9s', '-------'), sprintf('%9s', '-------'), "\n";
for my $char (sort { $char_frequency->{$b} <=> $char_frequency->{$a} }
    keys %{$char_frequency})
{
    $char_rank++;
    my $percent = $char_frequency->{$char} / $char_count;
    $cumulated += $percent;

    my $charname = charnames::viacode(ord($char));
    my $char_code = sprintf('U+%04X', ord($char));    # %04X or %04x

    print $stats_fh sprintf('%4s', $char_rank), sprintf('%5s', "'" . $char . "'"),
        sprintf('%12s', $char_frequency->{$char}),
        sprintf('%9s',  sprintf('%0.5f', $percent)),
        sprintf('%9s',  sprintf('%0.5f', $cumulated)), sprintf('%9s', $char_code), ' ',
        $charname, "\n";

    print $chars_fh $char, "\t", $char_frequency->{$char}, "\n";
} ## end for my $char (sort { $char_frequency...})

print $stats_fh "\n";
print $stats_fh '**************************', "\n";
print $stats_fh '*** grapheme frequency ***', "\n";
print $stats_fh '**************************', "\n";

my $grapheme_rank = 0;
$cumulated = 0;
print $stats_fh sprintf('%4s', 'rank'), sprintf('%5s', 'grph'), sprintf('%12s', 'count'),
    sprintf('%9s', '%'), sprintf('%9s', 'cum. %'), "\n";
print $stats_fh sprintf('%4s', '----'), sprintf('%5s', '----'), sprintf('%12s', '-----'),
    sprintf('%9s', '-------'), sprintf('%9s', '-------'), "\n";
for my $grapheme (sort { $grapheme_frequency->{$b} <=> $grapheme_frequency->{$a} }
    keys %{$grapheme_frequency})
{
    $grapheme_rank++;
    my $percent = $grapheme_frequency->{$grapheme} / $grapheme_count;
    $cumulated += $percent;

    my @chars = split(//, $grapheme);
    my @charnames = map { charnames::viacode(ord($_)) } @chars;
    my @char_codes = map { sprintf('U+%04X', ord($_)) } @chars;    # %04X or %04x

    print $stats_fh sprintf('%4s', $grapheme_rank),
        sprintf('%5s',  "'" . $grapheme . "'"),
        sprintf('%12s', $grapheme_frequency->{$grapheme}),
        sprintf('%9s',  sprintf('%0.5f', $percent)),
        sprintf('%9s',  sprintf('%0.5f', $cumulated)), '   ', join(' ', @char_codes), ' ',
        join("\n", @charnames), "\n";

} ## end for my $grapheme (sort ...)

for my $word (sort { $word_frequency->{$b} <=> $word_frequency->{$a} }
    keys %{$word_frequency})
{
    print $words_fh $word, "\t", $word_frequency->{$word}, "\n";
}

for my $bigram (sort { $char_bigram_frequency->{$b} <=> $char_bigram_frequency->{$a} }
    keys %{$char_bigram_frequency})
{
    print $bigrams_fh $bigram, "\t", $char_bigram_frequency->{$bigram}, "\n";
}

for my $trigram (sort { $char_trigram_frequency->{$b} <=> $char_trigram_frequency->{$a} }
    keys %{$char_trigram_frequency})
{
    print $trigrams_fh $trigram, "\t", $char_trigram_frequency->{$trigram}, "\n";
}

# $length: 13 172341 0.0994506987880057
$cumulated = 0;
print $stats_fh "\n";
print $stats_fh '*********************************', "\n";
print $stats_fh '*** length of words frequency ***', "\n";
print $stats_fh '*********************************', "\n";

print $stats_fh sprintf('%6s', 'length'), sprintf('%12s', 'count'), sprintf('%9s', '%'),
    sprintf('%9s', 'cum. %'), "\n";
print $stats_fh sprintf('%6s', '------'), sprintf('%12s', '-----------'),
    sprintf('%9s', '-------'), sprintf('%9s', '-------'), "\n";
for my $length (sort { $a <=> $b } keys %{$length_frequency}) {
    my $percent = $length_frequency->{$length} / $word_count;
    $cumulated += $percent;

    print $stats_fh sprintf('%6s', $length),
        sprintf('%12s', $length_frequency->{$length}),
        sprintf('%9s',  sprintf('%0.5f', $percent)),
        sprintf('%9s',  sprintf('%0.5f', $cumulated)), "\n";

} ## end for my $length (sort { ...})

$cumulated = 0;
print $stats_fh "\n";
print $stats_fh '****************************************', "\n";
print $stats_fh '*** alphabet size per word frequency ***', "\n";
print $stats_fh '****************************************', "\n";

print $stats_fh sprintf('%6s', 'size'), sprintf('%12s', 'count'), sprintf('%9s', '%'),
    sprintf('%9s', 'cum. %'), "\n";
print $stats_fh sprintf('%6s', '------'), sprintf('%12s', '-----------'),
    sprintf('%9s', '-------'), sprintf('%9s', '-------'), "\n";
for my $length (sort { $a <=> $b } keys %{$alphabet_frequency}) {
    my $percent = $alphabet_frequency->{$length} / $word_count;
    $cumulated += $percent;

    print $stats_fh sprintf('%6s', $length),
        sprintf('%12s', $alphabet_frequency->{$length}),
        sprintf('%9s',  sprintf('%0.5f', $percent)),
        sprintf('%9s',  sprintf('%0.5f', $cumulated)), "\n";

} ## end for my $length (sort { ...})

close $words_fh;
close $stats_fh;
close $chars_fh;
close $bigrams_fh;
close $trigrams_fh;


############################
sub parse {
    my ($XMLFILE) = @_;

    # /PcGts/Page/TextRegion
    my $twig = XML::Twig->new(

        #remove_cdata => 1,
        TwigHandlers => {'/PcGts/Page/TextRegion' => \&text_region,}
    );

    eval { $twig->parsefile($XMLFILE); };

    if ($@) {
        print STDERR "XML PARSE ERROR: " . $@;
        print STDERR 'file: ', $current_file, ' dir: ', $current_dir, "\n";

        #die "XML PARSE ERROR: " . $@;
    }
    return;
} ## end sub parse

# <TextRegion type="paragraph" id="r_1_3" custom="readingOrder {index:2;}">
sub text_region {
    my ($twig, $TextRegion) = @_;

    # /PcGts
    # <Page imageFilename="ONB_ibn_18640702_006.tif"

    my $Page_imageFilename = $TextRegion->parent()->att('imageFilename');
    print STDERR '$Page_imageFilename: ', $Page_imageFilename, "\n"
        if ($options->{'verbose'} >= 2);

    # <TextEquiv>
    #   <Unicode>Provinz (inklusive Porto) 5 kr.
    #     Abendblatt 5 kr.</Unicode>
    my $TextEquiv = $TextRegion->first_child('TextEquiv');
    if (!defined $TextEquiv) {
        print STDERR 'ERROR $TextEquiv not defined: ', $Page_imageFilename,
            ' TextRegion_id=', $TextRegion->att('id'), "\n";
        return 0;
    }
    my $TE_unicode = $TextEquiv->first_child('Unicode');
    if (!defined $TE_unicode) {
        print STDERR 'ERROR $TE_unicode not defined: ', $Page_imageFilename,
            ' TextRegion_id=', $TextRegion->att('id'), "\n";
        return 0;
    }

    my $TE_text = $TE_unicode->text();
    my @TE_text = split("\n", $TE_text);    # assumes Unix(LF) line endings

    print STDERR '@TE_text: ', "\n  ", join("\n  ", @TE_text), "\n"
        if ($options->{'verbose'} >= 2);


    # <TextLine id="tl_3" primaryLanguage="German" custom="readingOrder {index:0;}">
    #   <TextEquiv>
    #     <Unicode>Provinz (inklusive Porto) 5 kr.</Unicode>
    my @TextLines = $TextRegion->children('TextLine');
    print STDERR '@TextLines: ', Dumper(\@TextLines), "\n"
        if ($options->{'verbose'} >= 3);

    if (scalar(@TE_text) != scalar(@TextLines)) {
        print STDERR 'WARN: line count differs TextEquiv <=> TextLine(s)', ' in file: ',
            $current_file, ' TextRegion id=', $TextRegion->att('id'), "\n"
            if ($options->{'verbose'} >= 1);
    }

    # TODO: connect split words; needs sort by $readingOrder

    my $ordered_lines = {};
    for my $TextLine (@TextLines) {

        my $TL_id   = $TextLine->att('id');
        my $custom  = $TextLine->att('custom');
        my $TL_text = $TextLine->first_child('TextEquiv')->first_child('Unicode')->text();
        print STDERR '$TL_id: ', $TL_id, ' $custom: ', $custom, "\n", ' $TL_text: ',
            $TL_text, "\n"
            if ($options->{'verbose'} >= 2);

        $stats->{'lines_total'}++;

        my $readingOrder;
        if ($custom =~ m/readingOrder\s*\{\s*index\s*:\s*(\d+)\s*;\s*\}/) {
            $readingOrder = $1;
            print STDERR '$readingOrder: ', $readingOrder, "\n"
                if ($options->{'verbose'} >= 2);

            $ordered_lines->{$readingOrder}->{'TL_id'}   = $TL_id;
            $ordered_lines->{$readingOrder}->{'TL_text'} = $TL_text;
        }
    } ## end for my $TextLine (@TextLines)

    $last_word = '';
    for my $readingOrder (sort { $a <=> $b } keys %$ordered_lines) {

        my $TL_id   = $ordered_lines->{$readingOrder}->{'TL_id'};
        my $TL_text = $ordered_lines->{$readingOrder}->{'TL_text'};

        my $line_file = page2line_name($Page_imageFilename, $TL_id);

        if (-f $line_file) {
            print STDERR '$line_file: ', $line_file, "\n" if ($options->{'verbose'} >= 2);

            parse_line($line_file);
        }

    } ## end for my $readingOrder (sort...)

#$element->set_text( $text);
#$element->set_att( currency => 'EUR');
    return 1;
} ## end sub text_region
############################

sub parse_line {
    my ($file) = @_;

    open(my $in, "<:encoding(UTF-8)", $file) or die "cannot open $file: $!";

    while (my $line = <$in>) {
        chomp $line;
        $line_count++;

        #my $NFC_line = NFC($line);
        $line = NFC($line);

        for my $char (split(//, $line)) {
            $char_frequency->{$char}++;
            $char_count++;
        }

        my @words = $line =~ m/(
          		 (?[ \p{Word} - \p{Digit} + ['`´’] ])
                 (?[ \p{Word} - \p{Digit} + ['`´’=⸗‒—-] + [\.] ])+
             )/xg;

        if (   @words
            && $last_word
            && ($last_word =~ m/[=⸗‒—-]$/)
            && $words[0]
            && $words[0] !~ m/^(und|oder)/)
        {

            my $temp = shift @words;
            if ($temp =~ m/^[\p{Changes_When_Uppercased}]/) {
                $last_word =~ s/[=⸗‒—-]$//;
                my $new_word = $last_word . $temp;
                unshift @words, $new_word;
            }
            else {
                unshift @words, ($last_word . $temp);
            }
        } ## end if (@words && $last_word...)
        elsif ($last_word) { unshift @words, $last_word; }
        $last_word = '';
        if (   @words
            && $words[$#words] =~ m/[=⸗‒—-]$/
            && $words[$#words] =~ m/(?[ \p{Word} - \p{Digit} ])/xg)
        {
            $last_word = pop @words;
        }

        for my $word (@words) {

            # for my $word ( split(/[^\w’'⸗-]+/,$line) ) {
            # for my $word ( split(/\s+/,$line) ) {
            $word_count++;
            $word_frequency->{$word}++;
            $length_frequency->{word_length($word)}++;
            $alphabet_frequency->{alphabet_size($word)}++;
            for my $bigram (bigrams($word)) {
                $char_bigram_frequency->{$bigram}++;
                $bigram_count++;
            }
            for my $trigram (trigrams($word)) {
                $char_trigram_frequency->{$trigram}++;
                $trigram_count++;
            }
        } ## end for my $word (@words)
    } ## end while (my $line = <$in>)
    close $in;
} ## end sub parse_line

sub page2line_name {
    my ($Page_imageFilename, $TL_id) = @_;

    my $page_name = $Page_imageFilename;
    $page_name =~ s/\.(xml|pdf|txt|tif|tiff|jpg|jpeg|png)$//i;

    my $sub_dir = $current_dir;
    $sub_dir =~ s/page/line/;    # page_(eval|train)
    my $dir       = $config->{'line_dir'} . $config->{$sub_dir} . '/' . $page_name . '/';
    my $line_file = $dir . $Page_imageFilename . '_' . $TL_id . '.gt.txt';

    return $line_file;
} ## end sub page2line_name


sub alphabet_size {
    my ($word) = @_;

    my $alphabet = {};

    my @chars = split(//, $word);

    for my $char (@chars) {
        $alphabet->{$char}++;
    }

    return scalar(keys %{$alphabet});

} ## end sub alphabet_size

sub word_length {
    my $word = shift;

    my @chars = split(//, $word);

    return scalar(@chars);

}

sub bigrams {
    my ($word) = @_;

    return ngrams($word, 2);
}

sub trigrams {
    my ($word) = @_;

    return ngrams($word, 3);
}

sub ngrams {
    my ($word, $width) = @_;

    $word = '_' . $word . '_';

    return () unless ($width <= length($word));

    return map { substr $word, $_, $width; } (0 .. length($word) - $width);
}


sub print_stats {

    #my ($stats) = @_;

    print 'Pages total: ', $stats->{'pages_total'}, "\n";
    print 'Pages different: ', scalar(keys %{$stats->{'pages_different'}}), "\n";
    print 'Lines total: ',     $stats->{'lines_total'},     "\n";
    print 'Lines different: ', $stats->{'lines_different'}, "\n";

} ## end sub print_stats

=cut

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

