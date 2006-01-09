package HTML::WikiConverter::Kwiki;
use base 'HTML::WikiConverter';
use warnings;
use strict;

sub rules {
  my %rules = (
    hr => { replace => "\n----\n" },
    br => { replace => "\n" },

    h1 => { start => '= ',      block => 1, trim => 'both', line_format => 'single' },
    h2 => { start => '== ',     block => 1, trim => 'both', line_format => 'single' },
    h3 => { start => '=== ',    block => 1, trim => 'both', line_format => 'single' },
    h4 => { start => '==== ',   block => 1, trim => 'both', line_format => 'single' },
    h5 => { start => '===== ',  block => 1, trim => 'both', line_format => 'single' },
    h6 => { start => '====== ', block => 1, trim => 'both', line_format => 'single' },

    p      => { block => 1, trim => 'both', line_format => 'multi' },
    b      => { start => '*', end => '*', line_format => 'single' },
    strong => { alias => 'b' },
    i      => { start => '/', end => '/', line_format => 'single' },
    em     => { alias => 'i' },
    u      => { start => '_', end => '_', line_format => 'single' },
    strike => { start => '-', end => '-', line_format => 'single' },
    s      => { alias => 'strike' },

    tt   => { start => '[=', end => ']', trim => 'both', line_format => 'single' },
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
    li => { start => \&_li_start, trim => 'leading' },
  );

  return \%rules;
}

sub _li_start {
  my( $self, $node, $rules ) = @_;
  my @parent_lists = $node->look_up( _tag => qr/ul|ol/ );
  my $depth = @parent_lists;

  my $bullet = '';
  $bullet = '*' if $node->parent->tag eq 'ul';
  $bullet = '0' if $node->parent->tag eq 'ol';

  my $prefix = ( $bullet ) x $depth;
  return "\n$prefix ";
}

sub _link {
  my( $self, $node, $rules ) = @_;
  my $url = $node->attr('href') || '';
  my $text = $self->get_elem_contents($node) || '';

  if( my $title = $self->get_wiki_page($url) ) {
    return $title if $self->is_camel_case( $title ) and $text eq $title;
    return "[$title]" if $text eq $title;
    return "[$text http:?$title]" if $text ne $title;
  } else {
    return $url if $text eq $url;
    return "[$text $url]";
  }
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

HTML::WikiConverter::Kwiki - HTML-to-wiki conversion rules for Kwiki

=head1 SYNOPSIS

  use HTML::WikiConverter;
  my $wc = new HTML::WikiConverter( dialect => 'Kwiki' );
  print $wc->html2wiki( $html );

=head1 DESCRIPTION

This module contains rules for converting HTML into Kwiki markup. See
L<HTML::WikiConverter> for additional usage details.

=head1 AUTHOR

David J. Iberri <diberri@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2005 David J. Iberri

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
