package HTML::WikiConverter;

use warnings;
use strict;

use vars qw( $VERSION );
$VERSION = '0.10';

use HTML::PrettyPrinter;
use HTML::TreeBuilder;
use Image::Grab;
use Image::Size;
use URI;

=head1 NAME

HTML::WikiConverter - An HTML-to-wiki markup converter

=head1 SYNOPSIS

  my $wc = new HTML::WikiConverter(
    html => $html
  );

  print $wc->output, "\n";

=head1 DESCRIPTION

There are lots of programs out there that convert wiki markup into
HTML, but relatively few that convert HTML into wiki
markup. HTML::WikiConverter falls into the latter category, converting
HTML source into wiki markup. The resulting markup is suitable for
most wiki engines, but is admittedly targeted for MediaWiki (on which
Wikipedia runs -- see http://wikipedia.org)

=head1 METHODS

=over

=item B<new>

  $wc = new HTML::WikiConverter( %attribs )

Accepts a list of attribute name/value pairs and returns
a new HTML::WikiConverter object. Allowed attribute names:

 file     - (scalar) name of HTML file to convert to wikitext
 html     - (scalar) HTML source to convert
 base_url - (scalar) base URL used to make absolute URLs

If both the 'file' and 'html' attributes are specified, only
the 'file' attribute will be used.

=cut

sub new {
  my( $pkg, %attr ) = @_;

  my $self = bless {
    file     => $attr{file},
    html     => $attr{html},
    base_url => $attr{base_url},
    root     => new HTML::TreeBuilder(),
    
    # XXX These should be made configurable
    convert_wplinks => 1,
    default_wplang  => 'en',

    tag_handlers => {
      html   => '',
      head   => '',
      title  => '',
      meta   => '',
      body   => '',

      br     => "<br />",
      b      => [ "'''" ],
      strong => [ "'''" ],
      i      => [ "''"  ],
      em     => [ "''"  ],
      hr     => "----\n\n",

      # PRE blocks are handled specially (see tidy_whitespace and
      # wikify methods)
      pre    => [ "<pre>", "</pre>" ],

      p      => \&wikify_p,
      ul     => \&wikify_list_start,
      ol     => \&wikify_list_start,
      li     => \&wikify_list_item,
      table  => \&wikify_table,
      tr     => \&wikify_tr,
      td     => \&wikify_td,
      th     => \&wikify_td,
      div    => \&wikify_div,
      img    => \&wikify_img,
      a      => \&wikify_link,

      h1     => \&wikify_heading,
      h2     => \&wikify_heading,
      h3     => \&wikify_heading,
      h4     => \&wikify_heading,
      h5     => \&wikify_heading,
      h6     => \&wikify_heading,
    }
  }, $pkg;

  $self->{root}->implicit_tags(1);
  $self->{root}->implicit_body_p_tag(1);
  $self->{root}->ignore_ignorable_whitespace(1);
  $self->{root}->no_space_compacting(1);
  $self->{root}->ignore_unknown(0);
  $self->{root}->p_strict(1);

  if( $self->{file} ) {
    $self->{root}->parse_file( $self->{file} );
  } else {
    $self->{root}->parse( $self->{html} );
  }

  return $self;
}

=item B<output>

  $wikitext = $wc->output

Returns the converted HTML as wikitext markup.

=cut

sub output {
  my $self = shift;
  my $output = $self->wikify( $self->{root} );
  $self->tidy_whitespace( \$output );
  return $output;
}

=item B<rendered_html>

  $html = $wc->rendered_html

Returns a pretty-printed version of the HTML that WikiConverter used
to produce wikitext markup. This will almost certainly differ from the
HTML input provided to C<new> because of internal processing done by
HTML::TreeBuilder, namely that all end tags are closed, HTML, BODY,
and HEAD tags are automatically wrapped around the provided HTML
source (if not already present), tags are converted to lowercase,
attributes are quoted, etc.

=cut

sub rendered_html {
  my $self = shift;

  my $pp = new HTML::PrettyPrinter(
    allow_forced_nl => 1,
    wrap_at_tagend  => HTML::PrettyPrinter::ALWAYS,
    uppercase       => 0,
    quote_attr      => 1
  );
  $pp->set_nl_after( 1, 'all!' );

  my $fmt = $pp->format($self->{root});
  return join '', @$fmt;
}

=back

=head1 PROTECTED METHODS

These internal methods are used to format the HTML source into
wikitext. They should be considered protected methods in the sense
that you should only call them from a class derived from
HTML::WikiConverter.

=over

=item B<tidy_whitespace>

  $wc->tidy_whitespace( \$text )

Removes unnecessary space from the text to tidy it up for presentation
purposes. Removes all leading and trailing whitespace, and any
occurrence of three or more consecutive newlines are converted into
two newlines. Special care is taken not to disturb preformatted text
contained within PRE blocks.

=cut

sub tidy_whitespace {
  my( $self, $output ) = @_;

  # Strip leading/trailing whitespace
  $$output =~ s/^\s+//;
  $$output =~ s/\s+$//;

  #
  # Tidy up whitespace by replacing two or more endlines
  # (\n or \r) with \n\n. This must take care not to
  # disturb PRE blocks, whose whitespace cannot be ignored.
  #
  # Method:
  #
  #   1. Replace <PRE>...</PRE> with <unique_string>[<index>],
  #      where <unique_string> is some long, random, unlikely-
  #      to-be-present-in-output string, and <index> is the
  #      order in which the PRE block appears in the output.
  #      Store each PRE block in @pre_blocks, which is indexed
  #      by <index>
  #   2. Convert [\n\r]{2,n} into \n\n
  #   3. Replace each occurence of <unique_string>[<index>]
  #      in the output with the corresponding item from
  #      @pre_blocks
  #
  # This is essentially borrowed from the MediaWiki source.
  #

  my @pre_blocks;
  my $pre_index = 0;

  my $unique = '3iyZiyA7iMwg5rhxP0Dcc9oTnj8qD1jm1Sfv4';

  $$output =~ s{<\s*pre.*?>(.*?)<\s*/\s*pre\s*>}{
    push @pre_blocks, $1;
    $unique.'['.$pre_index++.']';
  }gise;

  # Strip extra newlines
  $$output =~ s/\r\n/\n/g;
  $$output =~ s/\n{2,}/\n\n/g;

  # Put the PRE blocks back in
  $$output =~ s{$unique\[(\d+)\]}{$pre_blocks[$1]}g;
}

=item B<wikify>

  $output = $wc->wikify( $elem [, $parent] )

Converts the HTML::Element specified by $elem into wikitext markup
and returns the wikitext.

=cut

sub wikify {
  my( $self, $node, $parent ) = @_;

  # Will be returned at end
  my $output = '';

  # Determine how to process
  if( UNIVERSAL::isa( $node, 'HTML::Element' ) ) {
    my $conv = $self->{tag_handlers}->{$node->tag};
    if( ref $conv eq 'CODE' ) {
      $output = $conv->($self, $node);
    } elsif( ref $conv eq 'ARRAY' ) {
      $output .= $self->wikify($_, $node) for $node->content_list;
      $output = $conv->[0].$output.$conv->[-1];
    } elsif( defined $conv ) {
      $output = $conv;
      $output .= $self->wikify($_, $node) foreach $node->content_list;
    } else {
      $output .= $self->wikify($_, $node) for $node->content_list;
    }
  } else {
    $output = $node;
    $output =~ s/ {2,}/ /g unless _elem_has_ancestor( $node, 'pre' ); #ref $parent and $parent->tag eq 'pre';
    $output = '' unless $output =~ /\S/;
  }

  return $output;
}

=item B<elem_contents>

  $outpupt = $wc->elem_contents( $elem );

Returns a wikified version of the contents of the specified
HTML element. This is done by passing each element of this
element's content list through the C<wikify()> method, and
returning the concatenated result.

=cut

sub elem_contents {
  my( $self, $node ) = @_;
  my $output = '';
  $output .= $self->wikify($_) foreach $node->content_list;
  return $output;
}

=item B<absolute_url>

  $absurl = $wc->absolute_url( $url )

If the 'base_url' attribute was specified in the WikiConverter constructor,
then converts $url into an absolute URL and returns it. Otherwise a canonical
version of $url is returned (see the URI module for a definition of canonical).

=cut

sub absolute_url {
  my( $self, $url ) = @_;
  my $uri = new URI( $url );
  return $self->{base_url} ? $uri->abs($self->{base_url}) : $uri->canonical;
}

=item B<log>

  $log = $wc->log( [ $msg ] )

Appends $msg to the log of activity for this WikiConverter instance
and returns the log.

=cut

sub log {
  my $self = shift;
  foreach my $msg ( @_ ) {
    $self->{log} .= "$msg\n";
  }
  return $self->{log};
}

=back

=head1 TAG HANDLERS

Tag handlers are the real workhorse of the HTML::WikiConverter module. They
essentially do all the converting of HTML elements into their corresponding
wiki markup.

There are three types of handlers: 1) replacement, 2) flank, and 3) code.

=head2 Replacement handlers

A replacement handler is the simplest type of handler. When a tag is
encountered that has a replacement handler, the tag is simply replaced
with the value of the replacement handler. This is used, for example,
to convert "<hr>" into "----".  Replacement handlers are string
values.

=head2 Flank handlers

In contrast, flank handlers don't completely replace the tag; they
simply place markup around the contents of the tag (stripping the
start and end tags). This is used, for example, to convert "<b>bold
text</b>" into "'''bold text'''".  A flank handler is specified with
an anonymous array of two elements: the first specifies the text that
should replace the start tag, and the second element specified the
text that should replace the end tag. If only one item is in the array,
it is used to replace both the start and end tag.

For example:

  $wc->set_handler( b => [ "'''" ] );
  $wc->set_handler( i => [ "''" ] );

=head2 Code handlers

Code handlers are the most flexible type of tag handlers. When an
element is encountered that has a code handler, the handler is
executed as a method call. The code handler receives two arguments,
the current HTML::WikiConverter instance, and the HTML::Element
being processed. The return value of the handler should be wikitext
markup.

For example,

  $wc->set_handler( table => \&handle_table );

Since code handlers must return wikitext markup, they must be sure
to continue processing the tree of elements contained within the
element passed to the handler. This can be done with the C<elem_contents>
function:

  sub handle_table {
    my( $wc, $elem ) = @_;
    return "{|\n".$wc->elem_contents($elem)."\n|}";
  }

This ensures that elements contained within $elem are wikified properly
(i.e., they're appropriate handlers are dispatched).

=over

=item B<set_handler>

  $wc->set_handler( $tag, $handler )

Assigns $handler as the tag handler for elements whose tag is $tag.

=cut

sub set_handler {
  my( $self, $tag, $handler ) = @_;
  $self->{tag_handlers}->{lc $tag} = $handler;
}

=item B<get_handler>

  $handler = $wc->get_handler( $tag )

Returns the tag handler associated with $tag.

=cut

sub get_handler {
  my( $self, $tag ) = @_;
  return $self->{tag_handlers}->{lc $tag};
}

=back

=head1 BUILT-IN TAG HANDLERS

The following tag handlers are built-in to HTML::WikiConverter. You
should not need to call these directly, but they are listed here for
the sake of completeness.

=over

=item B<wikify_table>

  $output = wikify_table( $elem )

=cut

sub wikify_table {
  my( $self, $node ) = @_;
  
  my @attrs = qw/cellpadding cellspacing border bgcolor align style class id/;
  my $output = "{| "._elem_attr_str($node, @attrs)."\n";
  $output .= $self->elem_contents($node);
  $output .= "|}\n\n";

  return $output;
}

=item B<wikify_tr>

  $output = wikify_tr( $elem )

=cut

sub wikify_tr {
  my( $self, $node ) = @_;
  
  # XXX
  # Shouldn't print a |- if this TR is the first
  # table row *and* the TR has no attributes
  # XXX

  my @attrs = qw/id style class bgcolor/;
  my $attr_str = _elem_attr_str($node, @attrs);

  my $output = "|- $attr_str\n";
  $output .= $self->elem_contents($node);

  return $output;
}

=item B<wikify_td>

  $output = wikify_td( $elem )

=cut

sub wikify_td {
  my( $self, $node ) = @_;

  my @attrs = qw/id style class bgcolor/;
  my $attr_str = _elem_attr_str($node, @attrs);
  $attr_str .= " | " if $attr_str;

  my $output = "| $attr_str";
  my $content = $self->elem_contents($node);
  $content =~ s/^\s+//;
  $content =~ s/\s+$//; # new
  $output .= $content;

  return "$output\n";
}

=item B<wikify_list_start>

  $output = wikify_list_start( $elem )

=cut

sub wikify_list_start {
  my( $self, $node ) = @_;
  my $content = $self->elem_contents($node);
  return "$content\n";
}

=item B<wikify_list_item>

  $output = wikify_list_item( $elem )

=cut

# XXX Doesn't properly handle nesting
sub wikify_list_item {
  my( $self, $node ) = @_;
  
  my $output = $node->parent->tag eq 'ol' ? '* ' : '# ';

  my $content = $self->elem_contents($node);

  # Trim whitespace
  $content =~ s/^\s+//;
  $content =~ s/\s+$//;

  $output .= $content;
  
  return "$output\n";
}

=item B<wikify_link>

  $output = wikify_link( $elem )

=cut

sub wikify_link {
  my( $self, $node ) = @_;
  
  my $url = $self->absolute_url( $node->attr('href') );
  my $title = $self->elem_contents($node);
  $title =~ s/^\s+// unless $url;
  $title =~ s/\s+$// unless $url;

  # Just return the link title if this tag is contained
  # within an header tag
  return $title if ref $node->parent and $node->parent->tag =~ /h\d/;

  # Return if this is a link to an image contained within
  return $title if _elem_is_image_div($node->parent);

  # Convert wikilinks
  if( $self->{convert_wplinks} ) {
    if( $url =~ m~http://(\w{2})\.wikipedia\.org/wiki/(.+)~ ) {
      my $lang = $1;
      ( my $wiki_page = $2 ) =~ s/_+/ /g;
      my $lang_interwiki = "$lang:" unless $lang eq $self->{default_wplang};
      return "[[$lang_interwiki$wiki_page]]" if $wiki_page eq $title;
      return "[[$lang_interwiki$wiki_page|$title]]";
    }
  }

  # If HREF is the same as the link title, then
  # just return the URL (it'll be converted into
  # a clickable link by the wiki engine)
  return $url if $url eq $title;
  return "[$url $title]";
}

=item B<wikify_img>

  $output = wikify_img( $elem )

=cut

sub wikify_img {
  my( $self, $node ) = @_;
  
  my $image_url = $self->absolute_url( URI->new( $node->attr('src') )->canonical );
  my $file = ( $image_url->path_segments )[-1];

  $self->log( "Processing IMG tag for SRC: ".$image_url->canonical."..." );

  #
  # Grab attributes to be added to the [[Image:]] markup
  #

  my $image_div = $node->parent if _elem_is_image_div( $node->parent );
  $image_div ||= $node->parent->parent if ref $node->parent and _elem_is_image_div( $node->parent->parent );

  my @attrs;
  if( $image_div ) {
    my $css_style = $image_div->attr('style');
    my $css_class = $image_div->attr('class');
    
    # Check for float attribute; if it's there,
    # then we'll add it to the [[Image:]] syntax
    $css_style =~ /float\:\s*(right|left)/i;
    my $alignment = $1;
    
    $css_class =~ /float(right|left)/i;
    $alignment ||= $1;
    
    if( $alignment ) {
      push @attrs, $alignment;

      $self->log( "  Image is contained within a DIV that specifies $alignment alignment" );
      $self->log( "  Adding '$alignment' to [[Image:]] markup attributes" );
    } else {
      $self->log( "  Image is not contained within a DIV for alignment" );
    }
  } else {
    $self->log( "  Image is not contained within a DIV" );
  }
  
  #
  # Check if we need to request a thumbnail of this
  # image; it's needed if the specified width attribute
  # differs from the default size of the image
  #

  if( my $width = $node->attr('width') ) {
    $self->log( "  Image has WIDTH attribute of $width" );
    $self->log( "  Checking whether resulting [[Image:]] markup should specify a thumbnail..." );

    # Download the image from the network and store
    # its contents in $buffer
    my $abs_url = $self->absolute_url( $node->attr('src') );
    $self->log( "    Fetching image '$abs_url' from the network" );
    my $image = new Image::Grab();
    $image->url( $abs_url );
    $image->grab();
    my $buffer = $image->image;
    
    # Grab the width & height of the image

    my( $actual_w, $actual_h ) = imgsize( \$buffer );
    $self->log( "    Calculating size of image '$abs_url': $actual_w x $actual_h" );

    # If the WIDTH attribute of the IMG tag is not equal
    # to the actual width of the image, then we need to
    # create a thumbnail
    if( $width =~ /^\d+$/ and $width != $actual_w ) {
      $self->log( "    IMG tag's WIDTH attribute ($width) differs from actual width of image ($actual_w)" );
      $self->log( "      -- that means we're going to need a thumbnail" );
      $self->log( "    Adding 'thumb' and '${width}px' to list of attributes for [[Image:]] markup" );
      push @attrs, 'thumb';
      push @attrs, "${width}px";
    }
  }

  if( my $alt = $node->attr('alt') ) {
    $self->log( "  Adding alternate text '$alt' to [[Image:]] markup" );
    push @attrs, $alt;
  }

  my $attr_str = join '|', @attrs;

  # All [[Image:]] markup ends with two newlines
  my $trail_space = "\n\n";

  $self->log( "...done processing IMG tag\n" );

  return "[[Image:$file|$attr_str]]$trail_space";
}

=item B<wikify_div>

  $output = wikify_div( $elem )

=cut

sub wikify_div {
  my( $self, $node ) = @_;
  
  my $contents = $self->elem_contents( $node );

  # Image DIVs will be removed because the [[Image:image.jpg|...]]
  # syntax (see wikify_img) can specify this information
  return $contents if _elem_is_image_div($node);

  # Normal (non-image) DIV
  my @attrs = qw/align class id style/;
  my $attr_str = _elem_attr_str($node, @attrs);
  $attr_str = " $attr_str" if $attr_str;
  return "<div$attr_str>$contents</div>\n\n";
}

=item B<wikify_p>

  $output = wikify_p( $elem )

=cut

sub wikify_p {
  my( $self, $node ) = @_;
  my $c = $self->elem_contents($node);
  $c =~ s/\s+$//;
  return "$c\n\n";
}

=item B<wikify_heading>

  $output = wikify_heading( $elem )

=cut

sub wikify_heading {
  my( $self, $node ) = @_;

  # Parse the heading level out of the tag name
  $node->tag =~ /h(\d)/;

  # Number of equal signs in wiki heading syntax
  # is equal to the heading level ($1)
  my $markup = ('=') x $1; 

  return $markup.' '.$self->elem_contents($node).' '.$markup."\n\n";
}

#
# Private function: _elem_attr_str( $elem, @attrs )
#
# Returns a string containing a list of attribute names and
# values associated with the specified HTML element. Only
# attribute names included in @attrs will be added to the
# string of attributes that is returned. The return value
# is suitable for inserting into an HTML document, as
# attribute name/value pairs are specified in attr="value"
# format.
#

sub _elem_attr_str {
  my( $node, @attrs ) = @_;
  return join ' ', map {
    "$_=\"".$node->attr($_)."\""
  } grep {
    my $attr = $node->attr($_);
    defined $attr && length $attr
  } @attrs;
}

#
# Private function: _elem_has_ancestor( $elem, $tagname )
#
# Returns true if the specified HTML::Element has an ancestor element
# whose element tag equals $tag. This is useful for determining if
# an element belongs to the specified tag.
#

sub _elem_has_ancestor {
  my( $node, $tag ) = @_;

  return 0 unless ref $node;

  if( ref $node->parent ) {
    return 1 if $node->parent->tag eq $tag;
    return has_parent( $node->parent, $tag );
  }

  return 0;
}

#
# Private function: _elem_is_image_div( $elem )
#
# Returns true $elem is a container element (P or DIV) meant only to
# lay out an IMG.
#
# More specifically, returns true if the given element is a DIV or P
# element and the only child it contains is an IMG tag or an IMG tag
# contained within a sole A tag (not counting child elements with
# whitespace text only).
#

sub _elem_is_image_div {
  my $node = shift;

  # Return false if node is undefined or isn't a DIV at all
  return 0 if not defined $node or $node->tag !~ /(?:p|div)/;

  # This counts the number of child nodes
  # that are either tags or are plain text
  # with at least one nonspace character
  my @contents = grep {
    ref $_ or $_ =~ /\S/
  } $node->content_list;

  # Returns true if sole child is an IMG tag  
  return 1 if @contents == 1 and ref $contents[0] and $contents[0]->tag eq 'img';

  # Check if child is a sole A tag that contains an IMG tag
  if( @contents == 1 and ref $contents[0] and $contents[0]->tag eq 'a' ) {
    my @children = grep {
      ref $_ or $_ =~ /\S/
    } $contents[0]->content_list;
    return 1 if @children == 1 and ref $children[0] and $children[0]->tag eq 'img';
  }

  return 0;
}

# Deletes the underlying HTML tree (see HTML::Element)
sub DESTROY {
  shift->{root}->delete();
}

=head1 COPYRIGHT

Copyright (c) 2004 David J. Iberri

This library is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

David J. Iberri <diberri@yahoo.com>

=cut

1;
