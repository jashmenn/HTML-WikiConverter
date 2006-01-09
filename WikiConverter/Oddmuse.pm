package HTML::WikiConverter::Oddmuse;
use base 'HTML::WikiConverter';
use warnings;
use strict;

sub rules {
  my %rules = (
    b => { start => '*', end => '*' },
    strong => { alias => 'b' },
    i => { start => '/', end => '/' },
    em => { start => '~', end => '~' },
    u => { start => '_', end => '_' },
    
    p => { block => 1, trim => 'both', line_format => 'multi' },
    img => { replace => \&_image },
    a => { replace => \&_link },

    ul => { line_format => 'multi', block => 1 },
    ol => { alias => 'ul' },
    li => { start => \&_li_start, trim => 'leading' },

    # http://www.oddmuse.org/cgi-bin/wiki/Table_Markup_Extension
    table => { block => 1, line_format => 'multi' },
    tr => { line_format => 'single', end => "||\n" },
    td => { start => \&_td_start, end => \&_td_end, trim => 'both' },
    th => { alias => 'td' },
  );

  return \%rules;
}

sub attributes { (
  shift->SUPER::attributes,
  camel_case => 0
) }

sub _td_start {
  my( $self, $node, $rules ) = @_;
  my $align = $node->attr('align') || 'left';
  my $colspan = $node->attr('colspan') || 1;

  my $prefix = ( '||' ) x $colspan;
  my $pad_for_align = $align eq 'left' ? '' : ' ';
  return $prefix.$pad_for_align;
}

sub _td_end {
  my( $self, $node, $rules ) = @_;
  my $align = $node->attr('align') || 'left';
  return $align eq 'right' ? '' : ' ';
}

sub _link {
  my( $self, $node, $rules ) = @_;
  my $url = $node->attr('href') || '';
  my $text = $self->get_elem_contents($node) || '';
  
  if( my $title = $self->get_wiki_page($url) ) {
    $title =~ s/_/ /g;
    return $text if $self->camel_case and lc $title eq lc $text and $self->is_camel_case($text);
    return "[[$text]]" if lc $text eq lc $title;
    return "[[$title|$text]]";
  } else {
    return $url if $url eq $text;
    return "[$url $text]";
  }
}

sub _image {
  my( $self, $node, $rules ) = @_;
  my $src = $node->attr('src') || '';
  return '' unless $src;

  # Could do something with an 'image_uri' option to handle local images
  return $src;
}

sub _li_start {
  my( $self, $node, $rules ) = @_;
  my @parent_lists = $node->look_up( _tag => qr/ul|ol/ );
  my $prefix = ('*') x @parent_lists;
  return "\n$prefix ";
}

1;

__END__

=head1 NAME

HTML::WikiConverter::Oddmuse - HTML-to-wiki conversion rules for Oddmuse

=head1 SYNOPSIS

  use HTML::WikiConverter;
  my $wc = new HTML::WikiConverter( dialect => 'Oddmuse' );
  print $wc->html2wiki( $html );

=head1 DESCRIPTION

This module contains rules for converting HTML into Oddmuse
markup. This dialect module supports most of Oddmuse's text formatting
rules described at [1], notably:

  * bold, strong, italic, emphasized, and underlined text
  * paragraph blocks
  * external images
  * internal and external links
  * unordered and ordered lists
  * tables [2]

 [1] http://www.oddmuse.org/cgi-bin/wiki/Text_Formatting_Rules
 [2] http://www.oddmuse.org/cgi-bin/wiki/Table_Markup_Extension

See L<HTML::WikiConverter> for usage details.

=head1 ATTRIBUTES

In addition to the regular set of attributes recognized by the
L<HTML::WikiConverter> constructor, this dialect also accepts the
following attributes:

=over

=item camel_case

Boolean indicating whether CamelCase links are enabled in the target
Oddmuse installation. This corresponds to Oddmuse's C<$WikiLinks>
configuration parameter. Enabling CamelCase links will turn HTML like
this:

  <p><a href="/wiki/CamelCase">CamelCase</a> links are fun.</p>

into this Oddmuse markup:

  CamelCase links are fun.

Disabling CamelCase links (the default) would convert that HTML into

  [[CamelCase]] links are fun.

=back

=head1 AUTHOR

David J. Iberri <diberri@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2005 David J. Iberri

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
