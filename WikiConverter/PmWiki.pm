package HTML::WikiConverter::PmWiki;
use warnings;
use strict;

sub rules {
  my %rules = (
    hr => { replace => "\n----\n" },
    br => { replace => " \\\\\n" },

    h1 => { start => '! ',      block => 1, trim => 1, line_format => 'single' },
    h2 => { start => '!! ',     block => 1, trim => 1, line_format => 'single' },
    h3 => { start => '!!! ',    block => 1, trim => 1, line_format => 'single' },
    h4 => { start => '!!!! ',   block => 1, trim => 1, line_format => 'single' },
    h5 => { start => '!!!!! ',  block => 1, trim => 1, line_format => 'single' },
    h6 => { start => '!!!!!! ', block => 1, trim => 1, line_format => 'single' },

    blockquote => { start => \&_blockquote_start, trim => 1, block => 1, line_format => 'multi' },
    pre        => { line_prefix => ' ', block => 1 },
    p          => { block => 1, trim => 1, line_format => 'multi' },

    b      => { start => "'''", end => "'''", line_format => 'single' },
    strong => { alias => 'b' },
    i      => { start => "''", end => "''", line_format => 'single' },
    em     => { alias => 'i' },
    tt     => { start => '@@', end => '@@', trim => 1, line_format => 'single' },
    code   => { alias => 'tt' },

    big   => { start => '+',  end => '+',  line_format => 'single' },
    small => { start => '-',  end => '-',  line_format => 'single' },
    sup   => { start => '^',  end => '^',  line_format => 'single' },
    sub   => { start => '_',  end => '_',  line_format => 'single' },
    ins   => { start => '{+', end => '+}', line_format => 'single' },
    del   => { start => '{-', end => '-}', line_format => 'single' },

    ul => { line_format => 'multi', block => 1 },
    ol => { alias => 'ul' },
    li => { start => \&_li_start, trim_leading => 1 },

    dl => { alias => 'ul' },
    dt => { start => \&_li_start, line_format => 'single', trim => 1 },
    dd => { start => ': ' },

    a   => { replace => \&_link },
    img => { replace => \&_image },

    table => { start => \&_table_start, block => 1 },
    tr    => { start => "\n||", line_format => 'single' },
    td    => { start => \&_td_start, end => \&_td_end },
    th    => { alias => 'td' }
  );

  return \%rules;
}

sub _table_start {
  my( $wc, $node, $rules ) = @_;
  my @attrs = qw/ border cellpadding cellspacing width bgcolor align /;
  return '|| '.$wc->get_attr_str( $node, @attrs );
}

sub _td_start {
  my( $wc, $node, $rules ) = @_;
  my $prefix = $node->tag eq 'th' ? '!' : '';

  my $align = $node->attr('align') || 'left';
  $prefix .= ' ' if $align eq 'center' or $align eq 'right';

  return $prefix;
}

sub _td_end {
  my( $wc, $node, $rules ) = @_;
  my $colspan = $node->attr('colspan') || 1;
  my $suffix = ( '||' ) x $colspan;

  my $align = $node->attr('align') || 'left';
  $suffix = ' '.$suffix if $align eq 'center' or $align eq 'left';

  return $suffix;
}

sub _blockquote_start {
  my( $wc, $node, $rules ) = @_;
  my @parent_bqs = $node->look_up( _tag => 'blockquote' );
  my $depth = @parent_bqs;
  
  my $start = ( '-' ) x $depth;
  return "\n".$start.'>';
}

sub _li_start {
  my( $wc, $node, $rules ) = @_;
  my @parent_lists = $node->look_up( _tag => qr/ul|ol|dl/ );
  my $depth = @parent_lists;

  my $bullet = '';
  $bullet = '*' if $node->parent->tag eq 'ul';
  $bullet = '#' if $node->parent->tag eq 'ol';
  $bullet = ':' if $node->parent->tag eq 'dl';

  my $prefix = ( $bullet ) x $depth;
  return "\n".$prefix.' ';
}

sub _link {
  my( $wc, $node, $rules ) = @_;
  my $url = $node->attr('href') || '';
  my $text = $wc->get_elem_contents($node) || '';
  return "[[$url | $text]]";
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
