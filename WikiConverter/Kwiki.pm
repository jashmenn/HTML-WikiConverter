package HTML::WikiConverter::Kwiki;
use warnings;
use strict;

sub rules {
  my %rules = (
    hr => { replace => "\n----\n" },
    br => { replace => "\n" },

    h1 => { start => '= ',      block => 1, trim => 1, line_format => 'single' },
    h2 => { start => '== ',     block => 1, trim => 1, line_format => 'single' },
    h3 => { start => '=== ',    block => 1, trim => 1, line_format => 'single' },
    h4 => { start => '==== ',   block => 1, trim => 1, line_format => 'single' },
    h5 => { start => '===== ',  block => 1, trim => 1, line_format => 'single' },
    h6 => { start => '====== ', block => 1, trim => 1, line_format => 'single' },

    p      => { block => 1, trim => 1, line_format => 'multi' },
    b      => { start => '*', end => '*', line_format => 'single' },
    strong => { alias => 'b' },
    i      => { start => '/', end => '/', line_format => 'single' },
    em     => { alias => 'i' },
    u      => { start => '_', end => '_', line_format => 'single' },
    strike => { start => '-', end => '-', line_format => 'single' },
    s      => { alias => 'strike' },

    tt   => { start => '[=', end => ']', trim => 1, line_format => 'single' },
    code => { alias => 'tt' },
    pre  => { line_prefix => ' ', block => 1 },

    a   => { replace => \&_link },
    img => { replace => \&_image },

    table => { block => 1 },
    tr    => { end => " |\n", line_format => 'single' },
    td    => { start => '| ', end => ' ' },
    th    => { alias => 'td' },

    ul => { line_format => 'multi', block => 1 },
    ol => { alias => 'ul' },
    li => { start => \&_li_start, trim_leading => 1 },
  );

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
  $bullet = '0' if $node->parent->tag eq 'ol';

  my $prefix = ( $bullet ) x $depth;
  return "\n$prefix ";
}

sub _link {
  my( $wc, $node, $rules ) = @_;
  my $url = $node->attr('href') || '';
  my $text = $wc->get_elem_contents($node) || '';

  # Handle the internal links
  if( my $title = $wc->get_wiki_page($url) ) {
    return $title if $wc->is_camel_case( $title ) and $text eq $title;
    return "[$title]" if $text eq $title;
    return "[$text http:?$title]" if $text ne $title;
  }

  # Handle the external ones
  return $url if $text eq $url;
  return "[$text $url]";
}

sub _image {
  my( $wc, $node, $rules ) = @_;
  return $node->attr('src') || '';
}

sub preprocess_node {
  my( $pkg, $wc, $node ) = @_;
  my $tag = $node->tag || '';
  $pkg->_strip_aname($wc, $node) if $tag eq 'a';
  $pkg->_caption2para($wc, $node) if $tag eq 'caption';
}

sub _strip_aname {
  my( $pkg, $wc, $node ) = @_;
  return unless $node->attr('name') and $node->parent;
  return if $node->attr('href');
  $node->replace_with_content->delete();
}

sub _caption2para {
  my( $pkg, $wc, $caption ) = @_;
  my $table = $caption->parent;
  $caption->detach();
  $table->preinsert($caption);
  $caption->tag('p');
}

1;
