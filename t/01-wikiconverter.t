#!perl -T

package HTML::WikiConverter::MyPerfectWiki;
use HTML::WikiConverter -dialect;

rule b => { start => '**', end => '**' };
rule i => { start => '//', end => '//' };
rule a => { replace => \&_a };
rule blockquote => { trim => 'both', block => 1, line_format => 'multi', line_prefix => '>' };
rule strong => { alias => 'b' };
rule em => { alias => 'i' };
rule img => { replace => \&_img };

attribute allow_html => { default => 0 };

# API tests for backwards-compatibility with 0.51; will be removed in 0.60
sub rules { { funny => { start => '~~', end => '~~' } } }
sub attributes { be_cool => 1 }

sub _a {
  my( $self, $node, $rules ) = @_;
  my $url = $node->attr('href') || '';
  my $title = $self->get_wiki_page($url) || '';
  my $text = $self->get_elem_contents($node) || '';
  return "[[$text]]" if $title eq $text;
  return "[[$text]]" if lcfirst $title eq $text;
  return "[[$title|$text]]" if $title;
  return $url if $url eq $text;
  return sprintf '[[%s|%s]]', $url, $text;
}

sub _img {
  my( $self, $node, $rules ) = @_;
  my $url = $node->attr('src') || '';
  my $title = $self->get_wiki_page($url) || '';
  return '' unless $url and $title;
  return '' unless $title =~ /^image/i;
  return sprintf '{{%s}}', $title;
}

package MySlimWiki;
use HTML::WikiConverter -dialect;

rule b => { start => '**', end => '**' };
rule i => { start => '//', end => '//' };

attribute strip_tags => { default => [ qw/ strong em / ] };
attribute slim_attr => { default => 1 };

package main;

use Test::More tests => 20;
use HTML::WikiConverter;
use URI::QueryParam;

my $have_query_param = 0;
BEGIN { $have_query_param = eval "use URI::QueryParam; 1" }

my $wc = new HTML::WikiConverter(
  dialect => 'MyPerfectWiki',
  base_uri => 'http://www.example.com',
  wiki_uri => [ 'http://www.example.com/wiki/', 'http://www.example.com/images/', \&extract_wiki_page ],
  preprocess => \&preprocess_test,
);

sub extract_wiki_page {
  my( $wc, $url ) = @_;
  return $have_query_param ? $url->query_param('title') : $url =~ /title\=([^&]+)/ && $1;
}

my $preprocess_tested = 0;
sub preprocess_test {
  is( 1, 1, 'preprocess' ) unless $preprocess_tested++;
}

is( $wc->html2wiki('<b>text</b>'), '**text**', 'bold' );
is( $wc->html2wiki('<i>text</i>'), '//text//', 'ital' );
is( $wc->html2wiki('<a href="http://example.com">Example</a>'), '[[http://example.com|Example]]', 'link' );
is( $wc->html2wiki('<blockquote>text1</blockquote>'), '>text1', 'blockquote' );
is( $wc->html2wiki('<blockquote>text1<blockquote>text2</blockquote></blockquote>'), ">text1\n>>text2", 'blockquote nested' );
is( $wc->html2wiki('<a href="/">Example</a>'), '[[http://www.example.com/|Example]]', 'relative URL in link' );
is( $wc->html2wiki('<strong>text</strong>'), '**text**', 'strong' );
is( $wc->html2wiki('<em>text</em>'), '//text//', 'em' );
is( $wc->html2wiki('<a href="/wiki/Example">Example</a>'), '[[Example]]', 'wiki link' );
is( $wc->html2wiki('<img src="/images/Image:Thingy.png" />'), '{{Image:Thingy.png}}', 'image' );
is( $wc->html2wiki('<a href="/w/index.php?title=Thingy&amp;action=view">Text</a>'), '[[Thingy|Text]]', 'long wiki url' );
is( $wc->allow_html, 0, 'bool-false attr check' );

# API tests for backwards-compatibility with 0.51; will be removed in 0.60
is( $wc->html2wiki('<funny>text</funny>'), '~~text~~', '0.51-style rules' );
is( $wc->be_cool, 1, '0.51-style attributes' );

eval { my $wcx = new HTML::WikiConverter( dialect => 'MyPerfectWiki' ) };
ok( !$@, 'dialect class outside H::WC namespace' );

# API checks
eval { my $wcx = new HTML::WikiConverter( dialect => 'MyPerfectWiki', nonexistent_attrib => 1 ) };
ok( $@, 'non-existent attribute' );

# Test that attributes containing references don't clobber each other
my $wc3 = new HTML::WikiConverter( dialect => 'MySlimWiki' );
is_deeply( $wc3->strip_tags, ['strong','em'], 'attr w/ ref (pt 1)' );
is_deeply( $wc->strip_tags, ['~comment','head','script','style'], 'attr w/ ref (pt 2)' );

eval { $wc->slim_attr };
ok( $@, 'non-overlapping attribute' );
