package HTML::WikiConverter::WakkaWiki;
use base 'HTML::WikiConverter';
use warnings;
use strict;

sub rules {
  my %rules = (
    b => { start => '**', end => '**' },
    strong => { alias => 'b' },
    i => { start => '//', end => '//' },
    em => { alias => 'i' },
    u => { start => '__', end => '__' },
    tt => { start => '##', end => '##' },
    code => { start => '%%', end => '%%' },

    p => { block => 1, trim => 'both', line_format => 'multi' },
    hr => { replace => "\n----\n" },
    a => { replace => \&_link },
    img => { preserve => 1, attributes => [ qw/ src alt width height / ], start => '""', end => '""', empty => 1 },

    ul => { line_format => 'multi', block => 1, line_prefix => "\t", start => \&_list_start },
    ol => { alias => 'ul' },
    li => { line_format => 'multi', start => \&_li_start, trim => 'leading' },
  );

  for( 1..5 ) {
    my $str = ( '=' ) x (7 - $_ );
    $rules{"h$_"} = { start => "$str ", end => " $str", block => 1, trim => 'both', line_format => 'single' };
  }
  $rules{h6} = { alias => 'h5' };

  return \%rules;
}

# This is a kludge that's only used to mark the start of an ordered
# list element; there's no WakkaWiki markup to start such a list.
my %li_count = ( );
sub _list_start {
  my( $self, $node ) = @_;
  return '' unless $node->tag eq 'ol';
  $li_count{$node->address} = 0;
  return '';
}

sub _li_start {
  my( $self, $node, $rules ) = @_;
  my @parent_lists = $node->look_up( _tag => qr/ul|ol/ );

  my $bullet = '-';
  if( $node->parent->tag eq 'ol' ) {
    $bullet = ++$li_count{$node->parent->address};
    $bullet .= ')';
  }

  return "\n$bullet ";
}

sub _link {
  my( $self, $node, $rules ) = @_;
  my $url = $node->attr('href') || '';
  my $text = $self->get_elem_contents($node) || '';
  
  # Internal linksw
  if( my $title = $self->get_wiki_page($url) ) {
    $title =~ s/_/ /g;
    # Remember [[MiXed cAsE]] ==> <a href="http://site/wiki:mixed_case">MiXed cAsE</a>
    return $text if lc $title eq lc $text and $self->is_camel_case($text);
    return "[[$title|$text]]";
  }

  # External links
  return $url if $url eq $text;
  return "[[$url $text]]";
}

1;

__END__

=head1 NAME

HTML::WikiConverter::WakkaWiki - HTML-to-wiki conversion rules for WakkaWiki

=head1 SYNOPSIS

  use HTML::WikiConverter;
  my $wc = new HTML::WikiConverter( dialect => 'WakkaWiki' );
  print $wc->html2wiki( $html );

=head1 DESCRIPTION

This module contains rules for converting HTML into WakkaWiki
markup. See L<HTML::WikiConverter> for additional usage details.

=head1 AUTHOR

David J. Iberri <diberri@yahoo.com>

=head1 COPYRIGHT

Copyright (c) 2005 David J. Iberri

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
