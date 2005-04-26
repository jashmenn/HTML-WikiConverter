package HTML::WikiConverter::UseMod;
use warnings;
use strict;

sub rules {
  my %rules = (
    br     => { replace => '<br>' },
    hr     => { replace => "\n----\n" },
    pre    => { line_prefix => ' ', block => 1 },
    p      => { block => 1, trim => 1, line_format => 'multi' },
    i      => { start => "''", end => "''", line_format => 'single' },
    em     => { alias => 'i' },
    b      => { start => "'''", end => "'''", line_format => 'single' },
    strong => { alias => 'b' },
    tt     => { preserve => 1 },
    code   => { start => '<tt>', end => '</tt>' },

    a   => { replace => \&_link },
    img => { replace => \&_image },

    ul => { line_format => 'multi', block => 1 },
    ol => { alias => 'ul' },
    dl => { alias => 'ul' },

    li => { start => \&_li_start, trim_leading => 1 },
    dt => { alias => 'li' },
    dd => { alias => 'li' },
  );

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
  my $depth = @parent_lists;

  my $bullet = '';
  $bullet = '*' if $node->parent->tag eq 'ul';
  $bullet = '#' if $node->parent->tag eq 'ol';
  $bullet = ':' if $node->parent->tag eq 'dl';
  $bullet = ';' if $node->parent->tag eq 'dl' and $node->tag eq 'dt';

  my $prefix = "\n".( ( $bullet ) x $depth );
  $prefix = ' '.$bullet if $node->left && $node->left->tag eq 'dt';
  return $prefix.' ';
}

sub _link {
  my( $wc, $node, $rules ) = @_;
  my $url = $node->attr('href') || '';
  my $text = $wc->get_elem_contents($node) || '';
  return $url if $url eq $text;
  return "[$url $text]";
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
