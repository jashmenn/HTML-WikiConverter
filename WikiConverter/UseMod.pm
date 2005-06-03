package HTML::WikiConverter::UseMod;
use base 'HTML::WikiConverter';
use warnings;
use strict;

sub rules {
  my %rules = (
    br     => { replace => '<br>' },
    hr     => { replace => "\n----\n" },
    pre    => { line_prefix => ' ', block => 1 },
    p      => { block => 1, trim => 'both', line_format => 'multi' },
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

    li => { start => \&_li_start, trim => 'leading' },
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
      trim => 'both',
      line_format => 'single'
    };
  }

  return \%rules;
}

# Calculates the prefix that will be placed before each list item.
# List item include ordered, unordered, and definition list items.
sub _li_start {
  my( $self, $node, $rules ) = @_;
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
  my( $self, $node, $rules ) = @_;
  my $url = $node->attr('href') || '';
  my $text = $self->get_elem_contents($node) || '';
  return $url if $url eq $text;
  return "[$url $text]";
}

sub _image {
  my( $self, $node, $rules ) = @_;
  return $node->attr('src') || '';
}

sub preprocess_node {
  my( $self, $node ) = @_;
  $self->strip_aname($node) if $node->tag eq 'a';
  $self->caption2para($node) if $node->tag eq 'caption';
}

1;

__END__

=head1 NAME

HTML::WikiConverter::UseMod - HTML-to-wiki conversion rules for UseMod

=head1 SYNOPSIS

  use HTML::WikiConverter;
  my $wc = new HTML::WikiConverter( dialect => 'UseMod' );
  print $wc->html2wiki( $html );

=head1 DESCRIPTION

This module contains rules for converting HTML into UseMod markup. See
L<HTML::WikiConverter> for additional usage details.

=head1 AUTHOR

David J. Iberri <diberri@yahoo.com>

=head1 COPYRIGHT

Copyright (c) 2005 David J. Iberri

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
