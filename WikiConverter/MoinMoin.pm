package HTML::WikiConverter::MoinMoin;
use warnings;
use strict;

sub rules {
  my %rules = (
    p   => { block => 1, trim => 1, line_format => 'multi' },
    pre => { block => 1, start => "{{{\n", end => "\n}}}" },

    i      => { start => "''", end => "''", line_format => 'single' },
    em     => { alias => 'i' },
    b      => { start => "'''", end => "'''", line_format => 'single' },
    strong => { alias => 'b' },
    u      => { start => '__', end => '__', line_format => 'single' },

    sup   => { start => '^', end => '^', line_format => 'single' },
    sub   => { start => ',,', end => ',,', line_format => 'single' },
    code  => { start => '`', end => '`', line_format => 'single' },
    tt    => { alias => 'code' },
    small => { start => '~-', end => '-~', line_format => 'single' },
    big   => { start => '~+', end => '+~', line_format => 'single' },

    a => { replace => \&_link },
    img => { replace => \&_image },

    ul => { line_format => 'multi', block => 1, line_prefix => \&_list_prefix },
    ol => { line_format => 'multi', block => 1, line_prefix => \&_list_prefix },

    li => {
      start => \&_li_start,
      line_format => 'multi', # converts two or more newlines into a single newline
      trim_leading => 1
    },

    dl => { line_format => 'multi' },
    dt => { trim => 1, end => ':: ' },
    dd => { trim => 1 },

    hr => { replace => "\n----\n" },

    table => { block => 1, line_format => 'multi' },
    tr => { end => "||\n", line_format => 'single' },
    td => { start => \&_td_start, end => ' ', trim => 1 },
    th => { alias => 'td' },
  );

  # Headings (h1-h6)
  my @headings = ( 1..6 );
  foreach my $level ( @headings ) {
    my $tag = "h$level";
    my $affix = ( '=' ) x ($level+1);
    $affix = '======' if $level == 6;
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

my %att2prop = (
  width => 'width',
  bgcolor => 'background-color',
);

sub _td_start {
  my( $wc, $td, $rules ) = @_;

  my $prefix = '||';

  my @style = ( );

  push @style, '|'.$td->attr('rowspan') if $td->attr('rowspan');
  push @style, '-'.$td->attr('colspan') if $td->attr('colspan');

  # If we're the first td in the table, then include table settings
  if( ! $td->parent->left && ! $td->left ) {
    my $table = $td->look_up( _tag => 'table' );
    my $attstr = _attrs2style( $table, qw/ width bgcolor / );
    push @style, "tablestyle=\"$attstr\"" if $attstr;
  }

  # If we're the first td in this tr, then include tr settings
  if( ! $td->left ) {
    my $attstr = $td->parent->attr('style');
    push @style, "rowstyle=\"$attstr\"" if $attstr;
  }

  # Include td settings
  my $attstr = join ' ', map { "$_=\"".$td->attr($_)."\"" } grep $td->attr($_), qw/ id class style /;
  push @style, $attstr if $attstr;

  my $opts = @style ? '<'.join(' ',@style).'>' : '';

  return $prefix.$opts.' ';
}

sub _attrs2style {
  my( $node, @attrs ) = @_;
  my %attrs = map { $_ => $node->attr($_) } grep $node->attr($_), @attrs;
  my $attstr = join '; ', map "$att2prop{$_}:$attrs{$_}", keys %attrs;
  return $attstr || '';
}

# Calculates the prefix that will be placed before each list item.
# List item include ordered, unordered, and definition list items.
sub _li_start {
  my( $wc, $node, $rules ) = @_;
  my $bullet = '';
  $bullet = '*'  if $node->parent->tag eq 'ul';
  $bullet = '1.' if $node->parent->tag eq 'ol';
  return "\n$bullet ";
}

sub _list_prefix {
  my( $wc, $node, $rules ) = @_;
  return '  ' if $node->parent->look_up( _tag => qr/ul|ol/ );
  return '';
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
  return $node->attr('src') || '';
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
