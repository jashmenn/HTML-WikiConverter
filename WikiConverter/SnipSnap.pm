package HTML::WikiConverter::SnipSnap;
use base 'HTML::WikiConverter';
use warnings;
use strict;

sub rules {
  my %rules = (
    b => { start => '__', end => '__' },
    strong => { alias => 'b' },
    i => { start => '~~', end => '~~' },
    em => { alias => 'i' },
    strike => { start => '--', end => '--' },

    p => { block => 1, trim => 'both', line_format => 'multi' },
    hr => { replace => "\n----\n" },
    br => { replace => "\\\\" },

    a => { replace => \&_link },
    blockquote => { start => '{quote}', end => '{quote}' },

    ul => { line_format => 'multi', block => 1 },
    ol => { alias => 'ul' },
    li => { start => \&_li_start, trim => 'leading' },

    table => { start => "{table}\n", end => '{table}', block => 1, line_format => 'multi' },
    tr => { line_format => 'single', end => "\n" },
    td => { end => \&_td_end },
    th => { alias => 'td' },

    h1 => { start => '1 ', block => 1 },
  );

  for( 2..6 ) {
    $rules{"h$_"} = { start => '1.1 ', block => 1 };
  }

  return \%rules;
}

sub _td_end {
  my( $self, $node, $rules ) = @_;
  my @right_cells = grep { $_->tag && $_->tag =~ /th|td/ } $node->right;
  return ' | ' if @right_cells;
  return '';
}

sub _link {
  my( $self, $node, $rules ) = @_;
  my $url = $node->attr('href') || '';
  my $text = $self->get_elem_contents($node) || '';

  if( my $title = $self->get_wiki_page($url) ) {
    $text =~ s~\+~ ~g;
    return "[$text]" if lc $text eq lc $title;
    return "[$text|$title]";
  } else {
    return $url if $url eq $text;
    return "{link:$text|$url}";
  }
}

sub _li_start {
  my( $self, $node, $rules ) = @_;

  my $bullet = $node->parent->tag eq 'ol' ? '1' : '*';
  my @parents = $node->look_up( _tag => qr/ul|ol/ );
  my $prefix = ( $bullet ) x @parents;
  $prefix .= '.' if $node->parent->tag eq 'ol';

  return "\n$prefix ";
}

1;

__END__

=head1 NAME

HTML::WikiConverter::SnipSnap - HTML-to-wiki conversion rules for SnipSnap

=head1 SYNOPSIS

  use HTML::WikiConverter;
  my $wc = new HTML::WikiConverter( dialect => 'SnipSnap' );
  print $wc->html2wiki( $html );

=head1 DESCRIPTION

This module contains rules for converting HTML into SnipSnap
markup. See L<HTML::WikiConverter> for additional usage details.

=head1 AUTHOR

David J. Iberri <diberri@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2005 David J. Iberri

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
