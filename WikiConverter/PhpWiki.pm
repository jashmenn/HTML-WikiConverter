package HTML::WikiConverter::PhpWiki;
use warnings;
use strict;

sub rules {
  my %rules = (
    p => { block => 1, trim => 1, line_format => 'multi' },
    i => { start => "_", end => "_" },
    b => { start => "*", end => "*" },

    blockquote => {
      block => 1,
      line_format => 'multi',
      start => \&_blockquote_start
    },

    img => { replace => \&_image },
    a => { replace => \&_link },

    ul => { line_format => 'multi', block => 1 },
    ol => { line_format => 'multi', block => 1 },

    td => {
      start => \&_td_start,
      end => \&_td_end,
      trim => 1
    },

    th => { alias => 'td' },

    # Note that we're not using 'remove_newlines' for list items;
    # doing so would incorrectly collapse nested list items into a
    # single line

    li => {
      start => \&_li_start,
      line_format => 'multi', # converts two or more newlines into a single newline
      trim_leading => 1,
    },

    hr => { replace => "\n----\n" },
    br => { replace => '%%%' },

    h1 => { start => '!!! ', block => 1, trim => 1, line_format => 'single' },
    h2 => { start => '!!! ', block => 1, trim => 1, line_format => 'single' },
    h3 => { start => '!! ',  block => 1, trim => 1, line_format => 'single' },
    h4 => { start => '! ',   block => 1, trim => 1, line_format => 'single' },
    h5 => { start => '! ',   block => 1, trim => 1, line_format => 'single' },
    h6 => { start => '! ',   block => 1, trim => 1, line_format => 'single' },

    dt => { trim => 1, line_format => 'multi', end => ":\n" },
    dd => { line_prefix => '  ' },

    # Aliases
    em => { alias => 'i' },
    strong => { alias => 'b' }
  );

  # HTML tags allowed in wiki markup
  foreach my $tag ( qw/ big small tt abbr acronym cite code dfn kbd samp var sup sub pre / ) {
    $rules{$tag} = { preserve => 1 }
  }

  return \%rules;
}

# Calculates the prefix that will be placed before each list item.
# List item include ordered and unordered list items.
sub _li_start {
  my( $wc, $node, $rules ) = @_;
  my @parent_lists = $node->look_up( _tag => qr/ul|ol/ );
  my $depth = @parent_lists;

  my $bullet = '';
  $bullet = '*' if $node->parent->tag eq 'ul';
  $bullet = '#' if $node->parent->tag eq 'ol';

  my $prefix = ( $bullet ) x $depth;
  return "\n$prefix ";
}

sub _image {
  my( $wc, $node, $rules ) = @_;
  return $node->attr('src') || '';
}

sub _link {
  my( $wc, $node, $rules ) = @_;
  my $url = $node->attr('href') || '';
  my $text = $wc->elem_contents($node) || '';
  return "[$text|$url]";
}

# Not quite right yet (e.g. doesn't handle rowspan)
sub _td_start {
  my( $wc, $node, $rules ) = @_;
  my @left = $node->left;
  return '' unless @left;
  return ( ( '  ' ) x scalar(@left) );
}

sub _td_end {
  my( $wc, $node, $rules ) = @_;
  my $right_tag = $node->right && $node->right->tag ? $node->right->tag : '';
  return $right_tag =~ /td|th/ ? " |\n" : "\n";
}

sub _blockquote_start {
  my( $wc, $node, $rules ) = @_;
  my @bq_lineage = $node->look_up( _tag => 'blockquote' );
  my $depth = @bq_lineage;
  return "\n" . ( ( '  ' ) x $depth );
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
