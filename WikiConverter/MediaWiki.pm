package HTML::WikiConverter::MediaWiki;
use warnings;
use strict;

use File::Basename;

sub rules {
  # HTML attributes common to all preserved tags
  my @common_attrs = qw/ id class lang dir title style /;

  my %rules = (
    p => { block => 1, trim => 1, line_format => 'multi' },
    i => { start => "''", end => "''", line_format => 'single' },
    b => { start => "'''", end => "'''", line_format => 'single' },

    pre => {
      line_prefix => ' ',
      block => 1,
    },

    font => {
      preserve => 1,
      attributes => [ @common_attrs, qw/ size color face / ]
    },

    table => { start => "\n{|\n", end => "|}", block => 1, line_format => 'multi' },
    tr => { start => "|-\n" },
    td => { start => \&_td_start, end => "\n", trim => 1, line_format => 'blocks' },
    th => { start => \&_td_start, end => "\n", trim => 1, line_format => 'single' },
    caption => { start => "|+ ", end => "\n", line_format => 'single' },

    img => { replace => \&_image },
    a => { replace => \&_link },

    ul => { line_format => 'multi', block => 1 },
    ol => { line_format => 'multi', block => 1 },
    dl => { line_format => 'multi', block => 1 },

    # Note that we're not using line_format=>'single' for list items;
    # doing so would incorrectly collapse nested list items into a
    # single line

    li => {
      start => \&_li_start,
      line_format => 'multi', # converts two or more newlines into a single newline
      trim_leading => 1
    },

    dt => {
      start => \&_li_start,
      line_format => 'multi',
      trim_leading => 1
    },
  
    dd => {
      start => \&_li_start,
      line_format => 'multi',
      trim_leading => 1
    },

    hr => { replace => "\n----\n" },
    br => { replace => '<br />' },

    # Aliases
    em => { alias => 'i' },
    strong => { alias => 'b' }
  );

  # HTML tags allowed in wiki markup
  my @preserve = qw(
    div center span
    blockquote cite var code tt
    sup sub strike s u del ins
    ruby rt rb rp big small
  );

  foreach my $tag ( @preserve ) {
    $rules{$tag} = {
      preserve => 1,
      attributes => \@common_attrs
    };
  }

  # Headings (h1-h6)
  my @headings = ( 1..6 );
  foreach my $level ( @headings ) {
    my $tag = "h$level";
    my $affix = ( '=' ) x $level;
    $rules{$tag} = {
      start => $affix,
      end => $affix,
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
  my $text = $wc->elem_contents($node) || '';
  return $url if $url eq $text;
  return "[$url $text]";
}

sub _image {
  my( $wc, $node, $rules ) = @_;
  return '' unless $node->attr('src');
  return '[[Image:'.basename($node->attr('src')).']]';
}

sub _td_start {
  my( $wc, $node, $rules ) = @_;
  return $node->look_down( sub { $_[0]->tag =~ /pre|table/ } ) ? "\n|\n" : "\n| ";
}

sub preprocess_node {
  my( $pkg, $wc, $node ) = @_;
  my $tag = $node->tag || '';
  $pkg->_strip_aname($wc, $node) if $tag eq 'a';
}

sub _strip_aname {
  my( $pkg, $wc, $node ) = @_;
  return unless $node->attr('name') and $node->parent;
  return if $node->attr('href');
  $node->replace_with_content->delete();
}

1;
