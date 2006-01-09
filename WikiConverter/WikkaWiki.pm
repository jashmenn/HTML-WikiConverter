package HTML::WikiConverter::WikkaWiki;
use base 'HTML::WikiConverter';
use warnings;
use strict;
use URI;

sub rules {
  my %rules = (
    b => { start => '**', end => '**' },
    strong => { alias => 'b' },

    i => { start => '//', end => '//' },
    em => { alias => 'i' },

    u => { start => '__', end => '__' },
    tt => { start => '##', end => '##' },
    code => { alias => 'tt' },

    strike => { start => '++', end => '++' },
    kbd => { start => '#%', end => '#%' },
    center => { start => '@@', end => '@@' },
    br => { replace => '---' },

    # table
    tr => { line_format => 'single', start => '|| ', end => "\n" },
    td => { end => ' || ' },
    th => { alias => 'td' },

    ul => { line_format => 'multi', block => 1 },
    ol => { alias => 'ul' },
    li => { line_format => 'multi', start => \&_li_start, trim => 'leading' },

    img => { replace => \&_image },
    a => { replace => \&_link },

    p => { block => 1, trim => 'both', line_format => 'multi' },
    hr => { replace => "\n----\n" },
  );

  for( 1..5 ) {
    my $str = ( '=' ) x (7 - $_ );
    $rules{"h$_"} = { start => "$str ", end => " $str", block => 1, trim => 'both', line_format => 'single' };
  }
  $rules{h6} = { alias => 'h5' };

  return \%rules;
}

# {{image class="center" alt="DVD logo" title="An Image Link" url="images/dvdvideo.gif" link="RecentChanges"}}
sub _image {
  my( $self, $node, $rules ) = @_;
  return '' unless $node->attr('src');
  $node->attr( src => URI->new($node->attr('src'))->rel($self->base_uri) );
  my $attr_str = $self->get_attr_str( $node, qw/ alt title src wikka_link / );
  return "{{image $attr_str}}";
}

sub _li_start {
  my( $self, $node, $rules ) = @_;
  my @parent_lists = $node->look_up( _tag => qr/ul|ol/ );
  my $depth = @parent_lists;

  my $bullet = $node->parent->tag eq 'ol' ? '1)' : '-';
  my $indent = ( '~' ) x $depth;

  return "\n".$indent.$bullet.' ';
}

sub _link {
  my( $self, $node, $rules ) = @_;
  my $url = $node->attr('href') || '';
  my $text = $self->get_elem_contents($node) || '';
  
  if( my $title = $self->get_wiki_page($url) ) {
    $title =~ s/_/ /g;
    return $text if lc $title eq lc $text and $self->is_camel_case($text);
    return "[[$title $text]]";
  } else {
    return $url if $url eq $text;
    return "[[$url $text]]";
  }
}

sub preprocess_node {
  my( $self, $node ) = @_;
  # FIXME: What if img isn't the only thing under this anchor tag?
  return unless $node->tag eq 'img' and $node->parent->tag eq 'a';
  $node->attr( wikka_link => $node->parent->attr('href') );
  $node->parent->replace_with_content()->delete;
}

1;

__END__

=head1 NAME

HTML::WikiConverter::WikkaWiki - HTML-to-wiki conversion rules for WikkaWiki

=head1 SYNOPSIS

  use HTML::WikiConverter;
  my $wc = new HTML::WikiConverter( dialect => 'WikkaWiki' );
  print $wc->html2wiki( $html );

=head1 DESCRIPTION

This module contains rules for converting HTML into WikkaWiki
markup. See L<HTML::WikiConverter> for additional usage details.

=head1 AUTHOR

David J. Iberri <diberri@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2005 David J. Iberri

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
