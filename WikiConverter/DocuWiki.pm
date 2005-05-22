package HTML::WikiConverter::DocuWiki;
use warnings;
use strict;

sub rules {
  my %rules = (
    b => { start => '**', end => '**' },
    strong => { alias => 'b' },
    i => { start => '//', end => '//' },
    em => { alias => 'i' },
    u => { start => '__', end => '__' },

    tt => { start => '"', end => '"' },
    code => { alias => 'tt' },

    pre => { line_format => 'blocks', line_prefix => '  ' },

    p => { block => 1, trim => 1, line_format => 'multi' },
    br => { replace => "\\\\\n" },
    hr => { replace => "\n----\n" },

    sup => { preserve => 1 },
    sub => { preserve => 1 },
    del => { preserve => 1 },

    ul => { line_format => 'multi', block => 1, line_prefix => '  ' },
    ol => { alias => 'ul' },
    li => { line_format => 'multi', start => \&_li_start, trim_leading => 1 },
  );

  for( 1..6 ) {
    my $str = ( '=' ) x $_;
    $rules{"h$_"} = { start => "$str ", end => " $str", block => 1, trim => 1, line_format => 'single' };
  }

  return \%rules;
}

sub _li_start {
  my( $wc, $node, $rules ) = @_;
  my @parent_lists = $node->look_up( _tag => qr/ul|ol/ );

  my $bullet = '';
  $bullet = '*' if $node->parent->tag eq 'ul';
  $bullet = '-' if $node->parent->tag eq 'ol';

  return "\n$bullet ";
}

1;
