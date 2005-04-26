package HTML::WikiConverter::MediaWiki;
use warnings;
use strict;

use URI;
use File::Basename;

my @common_attrs = qw/ id class lang dir title style /;

sub rules {
  # HTML attributes common to all preserved tags
  my %rules = (
    hr => { replace => "\n----\n" },
    br => { replace => '<br />' },

    p      => { block => 1, trim => 1, line_format => 'multi' },
    i      => { start => "''", end => "''", line_format => 'single' },
    em     => { alias => 'i' },
    b      => { start => "'''", end => "'''", line_format => 'single' },
    strong => { alias => 'b' },
    pre    => { line_prefix => ' ', block => 1 },

    font => {
      preserve => 1,
      attributes => [ @common_attrs, qw/ size color face / ]
    },

    table   => { start => \&_table_start, end => "|}", block => 1, line_format => 'blocks' },
    tr      => { start => \&_tr_start },
    td      => { start => \&_td_start, end => "\n", trim => 1, line_format => 'blocks' },
    th      => { start => \&_td_start, end => "\n", trim => 1, line_format => 'single' },
    caption => { start => "|+ ", end => "\n", line_format => 'single' },

    img => { replace => \&_image },
    a   => { replace => \&_link },

    ul => { line_format => 'multi', block => 1 },
    ol => { alias => 'ul' },
    dl => { alias => 'ul' },

    # Note that we're not using line_format=>'single' for list items;
    # doing so would incorrectly collapse nested list items into a
    # single line

    li => { start => \&_li_start, trim_leading => 1 },
    dt => { alias => 'li' },
    dd => { alias => 'li' },
  );

  # Disallowed HTML tags
  my @stripped_tags = qw/ head title script style meta link object /;

  # HTML tags allowed in wiki markup
  my @preserved_tags= qw/ div center span blockquote cite var code tt
                          sup sub strike s u del ins ruby rt rb rp big small /;

  $rules{$_} = { replace => '' } foreach @stripped_tags;
  $rules{$_} = { preserve=>1, attributes=>\@common_attrs } foreach @preserved_tags;

  # Headings (h1-h6)
  my @headings = ( 1..6 );
  foreach my $level ( @headings ) {
    my $tag = "h$level";
    my $affix = ( '=' ) x $level;
    $rules{$tag} = {
      start => $affix.' ',
      end => ' '.$affix,
      block => 1,
      trim => 1,
      line_format => 'single'
    };
  }

  return \%rules;
}

# Calculates the prefix that will be placed before each list item.
# List item include ordered, unordered, and definition list items.
sub _li_start {
  my( $wc, $node, $rules ) = @_;
  my @parent_lists = $node->look_up( _tag => qr/ul|ol|dl/ );

  my $prefix = '';
  foreach my $parent ( @parent_lists ) {
    my $bullet = '';
    $bullet = '*' if $parent->tag eq 'ul';
    $bullet = '#' if $parent->tag eq 'ol';
    $bullet = ':' if $parent->tag eq 'dl';
    $bullet = ';' if $parent->tag eq 'dl' and $node->tag eq 'dt';
    $prefix = $bullet.$prefix;
  }

  return "\n$prefix ";
}

sub _link {
  my( $wc, $node, $rules ) = @_;
  my $url = $node->attr('href') || '';
  my $text = $wc->get_elem_contents($node) || '';

  # Handle internal links
  if( my $title = $wc->get_wiki_page( $url ) ) {
    $title =~ s/_/ /g;
    return "[[$title]]" if $text eq $title;        # no difference between link text and page title
    return "[[$text]]" if $text eq lcfirst $title; # differ by 1st char. capitalization
    return "[[$title|$text]]";                     # completely different
  }

  # Treat them as external links
  return $url if $url eq $text;
  return "[$url $text]";
}

sub _image {
  my( $wc, $node, $rules ) = @_;
  return '' unless $node->attr('src');
  return '[[Image:'.basename( URI->new($node->attr('src'))->path ).']]';
}

sub _table_start {
  my( $wc, $node, $rules ) = @_;
  my $prefix = '{|';

  my @table_attrs = ( @common_attrs, qw/ border cellpadding cellspacing align bgcolor / );
  my $attrs = $wc->get_attr_str( $node, @table_attrs );
  $prefix .= ' '.$attrs if $attrs;

  return $prefix."\n";
}

sub _tr_start {
  my( $wc, $node, $rules ) = @_;
  my $prefix = '|-';
  
  my @tr_attrs = ( @common_attrs, qw/ bgcolor / );
  my $attrs = $wc->get_attr_str( $node, @tr_attrs );
  $prefix .= ' '.$attrs if $attrs;

  return '' unless $node->left or $attrs;
  return $prefix."\n";
}

# List of tags (and pseudo-tags, in the case of '~text') that are
# considered phrasal elements. Any table cells that contain only these
# elements will be placed on a single line.
my @td_phrasals = qw/ i em b strong u tt code span font sup sub br hr ~text s strike del ins /;
my %td_phrasals = map { $_ => 1 } @td_phrasals;

sub _td_start {
  my( $wc, $node, $rules ) = @_;
  my $prefix = $node->tag eq 'th' ? '!' : '|';

  my @td_attrs = ( @common_attrs, qw/ bgcolor align valign colspan rowspan / );
  my $attrs = $wc->get_attr_str( $node, @td_attrs );
  $prefix .= ' '.$attrs.' |' if $attrs;

  # If there are any non-text elements inside the cell, then the
  # cell's content should start on its own line
  my @non_text = grep !$td_phrasals{$_->tag}, $node->content_list;
  my $space = @non_text ? "\n" : ' ';

  return $prefix.$space;
}

sub preprocess_node {
  my( $pkg, $wc, $node ) = @_;
  my $tag = $node->tag || '';
  $pkg->_strip_extra($wc, $node);
  $pkg->_strip_aname($wc, $node) if $tag eq 'a';
  $pkg->_fix_extlinks_in_text($wc, $node) if $tag eq '~text';
}

my $URL_PROTOCOLS = 'http|https|ftp|irc|gopher|news|mailto';
my $EXT_LINK_URL_CLASS = '[^]<>"\\x00-\\x20\\x7F]';
my $EXT_LINK_TEXT_CLASS = '[^\]\\x00-\\x1F\\x7F]';

sub _fix_extlinks_in_text {
  my( $pkg, $wc, $node ) = @_;
  my $text = $node->attr('text') || '';
  $text =~ s~(\[\b(?:$URL_PROTOCOLS):$EXT_LINK_URL_CLASS+ *$EXT_LINK_TEXT_CLASS*?\])~<nowiki>$1</nowiki>~go;
  $node->attr( text => $text );
}

sub _strip_aname {
  my( $pkg, $wc, $node ) = @_;
  return unless $node->attr('name') and $node->parent;
  return if $node->attr('href');
  $node->replace_with_content->delete();
}

my %extra = (
 id => qr/catlinks/,
 class => qr/urlexpansion|printfooter|editsection/
);

# Delete <span class="urlexpansion">...</span> et al
sub _strip_extra {
  my( $pkg, $wc, $node ) = @_;
  my $tag = $node->tag || '';
  return unless $tag =~ /div|span/;

  foreach my $att_name ( keys %extra ) {
    my $att_value = $node->attr($att_name) || '';
    if( $att_value =~ $extra{$att_name} ) {
      $node->detach();
      $node->delete();
      return;
    }
  }
}

1;
