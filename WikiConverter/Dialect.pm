package HTML::WikiConverter::Dialect;

use vars qw($VERSION);
$VERSION = '0.16';

require Exporter;
use base 'Exporter';
use vars qw( @EXPORT_OK );
@EXPORT_OK = qw/trim passthru/;

use URI;

#
# Changes
#
# version: 0.16
# date:    Fri 5/28/04 11:38:42 PDT
# changes:
#  - added elem_style_attr_props method
#  - documentation additions
#  - tags that are meant to be stripped (e.g., HTML, META, OBJECT) no
#    longer need to be assigned an empty replacement handler (they can
#    simply be excluded from the list of tag handlers)
#  - added 'block_elements' method
#  - removed 'line_elements' method
#

=head1 NAME

HTML::WikiConverter::Dialect - Base class for creating new wiki dialects

=head1 SYNOPSIS

  #
  # Create a subclass of HTML::WikiConverter::Dialect
  #

  package HTML::WikiConverter::Dialect::MyWikiEngine;

  use HTML::WikiConverter::Dialect qw(trim passthru);
  use base 'HTML::WikiConverter::Dialect';

  sub tag_handlers {
    return {
      html      => "",           # replacement handler
      i         => [ "/", "/" ], # flank handler
      pre       => \&wikify_pre, # code handler (defined below)
      nowiki    => \&passthru,   # code handler (default handler)
      # ... etc.
    }
  }

  sub wikify_pre {
    my( $self, $node ) = @_;

    my $text = $self->elem_contents( $node );
    # ... process $text
    return $text;
  }

  #
  # Use your new wiki dialect
  #

  my $wc = new HTML::WikiConverter(
    html    => qq(
      <P> My name is <B>David</B> and I am happy. </P>
      <PRE> print join " ", reverse qw(fun is Perl); </PRE>
    ),
    dialect => "MyWikiEngine"
  );

  print $wc->output;

=head1 DESCRIPTION

HTML::WikiConverter::Dialect is a base class for wiki engine
dialects. It is meant for use only by developers creating new wiki
dialects to be used with the HTML::WikiConverter interface. All wikis
have particular markup specifications. For example, the MediaWiki
markup differs from the CGI::Kwiki markup, which differs from the
PhpWiki markup, etc. Each of these wiki engines is considered to
have a different "dialect" of wiki markup, and this module serves as
the base class for each of them.

B<Note>: If you are trying to convert HTML to wiki markup, you should
not be using this module directly. Use HTML::WikiConverter instead.
Only developers of new wiki dialects should need this module.

For simplicity, the following documentation assumes you are creating a
wiki dialect called HTML::WikiConverter::Dialect::MyWikiEngine.

=head1 CREATING A WIKI DIALECT

=head2 Step 1: Subclass HTML::WikiConverter::Dialect

New wiki dialects can be added to HTML::WikiConverter relatively
easily.  The first step involves subclassing the
HTML::WikiConverter::Dialect class (or one of its subclasses, such as
HTML::WikiConverter::Dialect::MediaWiki).

  package HTML::WikiConverter::Dialect::MyWikiEngine;
  use base 'HTML::WikiConverter::Dialect';

=head2 Step 2: Define the tag handlers

The only other requirement (per se) is that you specify a set of
tag handlers to be invoked during HTML translation. To do so,
simply define a C<tag_handlers> method that returns a reference
to a hash of tag-to-handler mappings:

  sub tag_handlers {
    return {
      b     => [ '*', '*' ],
      i     => [ '/', '/' ],
      hr    => "----\n",
    }
  }

B<Note>: For more details on how to specify tag handlers, see the "Tag
handlers" section below.

=head2 Step 3: Specify whitespace handling (optional)

For additional control of whitespace handling, you can also define
arrays for three types of HTML tags: block elements, container elements,
and non-breaking elements.

=head3 Block elements
  
  Default elements: PRE DL OL UL P HR DIV TABLE H1 H2 H3 H4 H5 H6

B<Block elements> are HTML tags that should be flanked with two
newlines ("\n\n") after they have been converted into wiki markup.
For example, in many wiki dialects, paragraphs (i.e. P blocks) should
be separated by two newlines.

=head3 Container elements

  Default elements: TABLE TR DL DD DT UL OL LI

B<Container elements> are HTML tags that should generally contain only
other HTML tags. For example, a UL tag should contain only LI tags,
and TABLE should contain only TR tags. Whitespace found between
container elements and their children will be ignored. For example,
"E<lt>ULE<gt> E<lt>LIE<gt>" will be interpreted as
"E<lt>ULE<gt>E<lt>LIE<gt>".

B<Note>: By default, LI is considered a container element because it
can contain other list container elements like UL and OL.

=head3 Non-breaking elements

  Default elements: DL DT DD P DIV TABLE

B<Non-breaking elements> are those whose internal whitespace can be
collapsed.  For example, in some wiki dialects, paragraphs are
delimited by two or more newlines. For this reason, newlines found
within P tags in the HTML source should be collapsed. It is best
to explain with an example. Consider the following HTML source:

  <P>My name is David
  
    and I am a human being.</P>

If no special whitespace processing were done on this block, the
resulting wiki markup would be:

  My name is David

    and I am a human being.

In some wiki dialects, this would be rendered incorrectly since
two newlines are an indicator to start a new paragraph section. In
these wikis, the above markup would be converted into the following
HTML (roughly):

  <P>My name is David</P>
  <P>  and I am a human being.</P>

What's actually expected is something equivalent to:

  <P>My name is David and I am a human being.</P>

To achieve this effect, extra newlines are removed from non-breaking
elements like paragraphs.

=head2 How to specify container and non-breaking elements

Each set of element types is specified via a method that returns a
hash reference mapping the tag name to a true value. To override the
default container element settings, you would define a
C<container_elements> method:

  sub container_elements {
    return { map { $_ => 1 } qw(
      table tr dl dd dt ul ol li
    ) };
  }

Which is equivalent to:

  sub container_elements {
    return {
      table => 1,
      tr    => 1,
      dl    => 1,
      # ... etc
  }

Similarly, to specify non-breaking elements, simply define a
C<nonbreaking_elements> method that returns a hash reference in the same
way. The same can be done for block elements by defining a
C<block_elements> method.

If, rather than redefining the elements, you would like to append some
of your own, simply define a method like so:

  sub block_elements {
    return {
      shift->SUPER::block_elements,
      map { $_ => 1 } qw/center/
    };
  }

=head1 TAG HANDLERS

Tag handlers are the bread and butter of HTML::WikiConverter. They govern
how HTML elements are converted to their corresponding wiki markup.

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

=head2 Code handlers

Code handlers are the most flexible type of tag handlers. When an
element is encountered that has a code handler, the handler is
executed as a method call. The code handler receives two arguments,
the current dialect object, and the HTML::Element being processed. The
return value of the handler should be wikitext markup.

Since code handlers must return wikitext markup, they must be sure to
continue processing the tree of elements contained within the element
passed to the handler. This can be done with the C<elem_contents>
function:

  sub wikify_table {
    my( $d, $elem ) = @_;
    return "{|\n".$d->elem_contents($elem)."\n|}";
  }

This ensures that elements contained within $elem are wikified properly
(i.e., they're appropriate handlers are dispatched).

=head1 METHODS

=over

=item B<new>

  $d = new HTML::WikiConverter::Dialect::MyWikiEngine( %attr )
  $d = $pkg->SUPER::new( %attr )
  
Default constructor for wiki dialects. Takes all key-value arguments
and blesses them into the current package (determined by the
subclass). This is intended for use a simple constructor for wiki
dialects that do not require any special initialization. If you need
to further process arguments or otherwise have more control over the
initialization process, you should define your own C<new> method and
have it invoke this constructor. For example, in "MyWikiEngine.pm",
you might have:

  sub new {
    my( $pkg, %attr ) = @_;

    # Call default constructor from superclass
    my $self = $pkg->SUPER::new( %attr );

    # ... processing

    return $self;
  }

=cut

sub new {
  my( $pkg, %attr ) = @_;
  return bless \%attr, $pkg;
}

=item B<tag_handlers>

(Can be overridden)Returns a reference to a hash of tag handlers defined
(meant to be overriden by subclass). The hash should contain a list of
key-value pairs, where the key indicates the tag name, and the value
represents the handler to be used when that tag is encountered in the
HTML source.

For example:

  sub tag_handlers {
    return {
      html     => '',           # replacement handler
      b        => [ "*", "*" ], # flank handler
      img      => \&wikify_img, # code handler
    };
  }

There are three different types of tag handlers allowed: replacement
handlers, flank handlers, and code handlers. Read the section entitled
"Tag handlers" for more information.

=cut

sub tag_handlers { return {} }

=item B<container_elements>

(Can be overridden) Returns a reference to a hash mapping tag names to
boolean values. Read more in the "Container elements" section.

=cut

# 5/28/04 - rm LI from list
sub container_elements {
  return { map { $_ => 1 } qw(
    table tr dl dd dt ul ol
  ) };
}

=item B<nonbreaking_elements>

(Can be overridden) Returns a reference to a hash mapping tag names to
boolean values. Read more in the "Non-breaking elements" section.

=cut

# Added LI and H* (DL shouldn't be here though)
sub nonbreaking_elements {
  return { map { $_ => 1 } qw(
    li dt dd p div table h1 h2 h3 h4 h5 h6
  ) };
}

=item B<block_elements>

(Can be overridden) Returns a reference to a hash mapping tag names to
boolean values. Read more in the "Block elements" section.

=cut

sub block_elements {
  return { map { $_ => 1 } qw(
    pre dl ol ul p hr div table h1 h2 h3 h4 h5 h6
  ) };
}

=item B<output>

  $wikitext = $d->output()

Converts the original HTML source and returns it as wiki markup.

=cut

sub output {
  my $self = shift;

  my $output = $self->wikify( $self->root );
  $self->tidy_whitespace( \$output );

  return $output;
}

=item B<wikify>

  $output = $d->wikify( $elem [, $parent ] )

Converts the HTML::Element specified by $elem into wikitext markup and
returns the wikitext. If $elem is a text element, then $parent (if
defined) will be used as its parent.

B<Note>: It is very unlikely that you want to override this method,
as it is the workhorse of this module.

=cut

sub wikify {
  my( $self, $node, $parent ) = @_;

  # Will be returned at end
  my $output = '';

  # Determine how to process $node (an HTML::Element instance)
  if( $self->is_elem( $node ) ) {
    # Fetch tag handler
    my $conv = $self->tag_handlers->{$node->tag};

    if( ref $conv eq 'CODE' ) {
      # Code handler
      $output = $conv->( $self, $node );
    } elsif( ref $conv eq 'ARRAY' ) {
      # Flank handler
      $output = $self->elem_contents($node);
      $output = $conv->[0].$output.$conv->[-1];
    } elsif( defined $conv ) {
      # Replacement handler
      $output = $conv;
    } else {
      # No handler
      $output = $self->elem_contents($node);
    }

    # Block elements have leading and trailing "\n\n"
    if( $self->block_elements->{$node->tag} and !$self->elem_has_ancestor($node, $node->tag) and $node ) {
      $output = "\n\n$output\n\n";
    }
  } else {
    # This is a text-only node (not an HTML::Element)
    $output = $node;

    # Whitespace inside non display containers is ignored
    if( ref $parent and $self->container_elements->{$parent->tag} and $node !~ /\S/ ) {
      $output = '';
    }

    # Non-breaking elements should have no embedded newlines
    if( $self->nonbreaking_elements->{$parent->tag} and $output ) {
      if( $output =~ /^(\s*)(.+?)(\s*)$/ ) {
        my( $lead, $content, $trail ) = ( $1, $2, $3 );

        # Remove embedded newlines
        s/[\r\n]+/ /g for( $lead, $content );

        # Put it all back together
        $output = $lead.$content.$trail;
      }
    }

    # Strip excess whitespace except in PRE blocks
    unless( ( ref $parent and $parent->tag eq 'pre' ) or $self->elem_has_ancestor( $parent, 'pre' ) ) {
      $output =~ s/[\r\n]+$/\n/;
      $output =~ s/ {2,}/ /g;
    }
  }

  return $output;
}

=item B<log>

  $log = $d->log( [ $msg ] )

Appends $msg to the log of activity for this WikiConverter instance
and returns the log.

=cut

sub log {
  my $self = shift;
  $self->{log} .= join('', @_)."\n" if @_;
  return $self->{log};
}

=item B<root>

  $elem = $d->root

Returns the root HTML::Element associated with this dialect.

=cut

sub root { shift->{root} }

=back

=head1 BUILT-IN TAG HANDLERS

=over

=item B<passthru>

  $output = passthru( $elem )

This handler should be assigned to all tags that do not
need further processing. For example, in order to preserve
FONT tags from the HTML source in the wiki output

  use HTML::WikiConverter::Dialect 'passthru';

  sub tag_handlers {
    return {
      font => \&passthru,
      # ... other handlers
    };
  }

Without this specification, FONT tags will simply be removed
from the HTML source.

=cut

sub passthru {
  my( $self, $node ) = @_;

  my $content = '';
  $content .= $self->wikify($_, $node) foreach $node->content_list;

  my $attr_str = join ' ', map {
    my $attr = $node->attr($_);
    "$_=\"$attr\"";
  } grep {
    length $node->attr($_)
  } $node->all_external_attr_names;

  my $tag = $node->tag;
  $attr_str &&= " $attr_str";

  return "<$tag$attr_str>$content</$tag>";
}

=back

=head1 UTILITY METHODS

=over

=item B<elem_contents>

  $output = $d->elem_contents( $elem )

Returns a wikified version of the contents of the specified HTML
element. This is done by passing each element of the content list
through the C<wikify()> method, and returning the concatenated result.

If $elem is a text element (i.e. is not an HTML::Element object),
the text of $elem is returned.

=cut

sub elem_contents {
  my( $self, $node ) = @_;

  return $node unless $self->is_elem($node);

  my $output = '';
  $output .= $self->wikify($_, $node) foreach $node->content_list;
  return $output;
}

=item B<elem_attr_str>

  $attr_str = $d->elem_attr_str( $elem, @attrs )

Returns a string containing a list of attribute names and values
associated with the specified HTML element. Only attribute names
included in @attrs will be added to the string of attributes that is
returned. The return value is suitable for inserting into an HTML
document, as attribute name/value pairs are specified in attr="value"
format.

=cut

sub elem_attr_str {
  my( $self, $node, @attrs ) = @_;
  return join ' ', map {
    "$_=\"".$node->attr($_)."\""
  } grep {
    my $attr = $node->attr($_);
    defined $attr && length $attr
  } @attrs;
}

=item B<elem_style_attr_props>

  %props = $d->elem_style_attr_props( $elem )

Returns a hash of style properties and their values, or an empty hash
if no style attribute is set for the given $elem.

=cut

sub elem_style_attr_props {
  my( $self, $elem ) = @_;
  return unless UNIVERSAL::isa( $elem, 'HTML::Element' );

  my %props;
  if( my $style = $elem->attr( 'style' ) ) {
    my @pairs = split /\s*;\s*/, $style;
    foreach my $def ( @pairs ) {
      my( $prop, $val ) = split /\s*:\s*/, $def;
      $props{$prop} = $val;
    }

    return %props;
  }

  return ();
}

=item B<elem_has_ancestor>

  $bool = $d->elem_has_ancestor( $elem, $tag )

Returns true if the specified HTML::Element has an ancestor element
whose element tag matches $tag. The $tag parameter may be either a
string corresponding to the name of the ancestor tag, or it may be a
compiled regexp (qr//) with which to match. This is useful for
determining if an element belongs to the specified tag.

=cut

sub elem_has_ancestor {
  my( $self, $elem, $tag ) = @_;

  return 0 unless ref $elem;

  # Force interpretation as regexp
  $tag = qr/^$tag$/i unless ref $tag eq 'Regexp';

  $_->tag =~ $tag and return 1 foreach $elem->lineage;
  return 0;
}

sub elem_has_descendant {
  my( $self, $elem, $tag ) = @_;
  return 0 unless ref $elem;

  $tag = qr/^$tag$/i unless ref $tag eq 'Regexp';

  $_->tag =~ $tag and return 1 foreach $elem->descendants;
  return 0;
}

=item B<is_elem>

  $is_elem = $d->is_elem( $node )

Returns true if $node is of type C<HTML::Element>, false otherwise.
Exactly equivalent to:

  $is_elem = UNIVERSAL( $node, 'HTML::Element' );

This method is just a little more convenient.

=cut

sub is_elem {
  my( $self, $node ) = @_;
  return UNIVERSAL::isa( $node, 'HTML::Element' );
}

=item B<style_attr_str>

  $style_attr_str = $d->style_attr_str( %style )

Given a style attribute specification (such as that returned by the
elem_style_attr_props function), returns a string suitable for
assignment to the STYLE attribute of an HTML element.

=cut

sub style_attr_str {
  my( $self, %style ) = @_;

  my $style;
  while( my( $prop, $val ) = each %style ) {
    $style .= "$prop: $val; ";
  }

  # Remove trailing semicolon and space
  $style =~ s/; $//;

  return $style;
}

=item B<tidy_whitespace>

  $d->tidy_whitespace( \$text )

Removes unnecessary space from the text to tidy it up for presentation
purposes. Removes all leading and trailing whitespace, and any
occurrence of three or more consecutive newlines are converted into
two newlines.

=cut

sub tidy_whitespace {
  my( $self, $output ) = @_;
  $$output =~ s/\r\n/\n/g;
  $$output =~ s/\n+\s*\n+/\n\n/g;
  $$output =~ s/ {2,}/ /g;
  $$output =~ s/^ +//gm;
  trim( $output );
}

=item B<absolute_url>

  $absurl = $d->absolute_url( $url )

If the 'base_url' attribute was specified in the WikiConverter constructor,
then converts $url into an absolute URL and returns it. Otherwise a canonical
version of $url is returned (see the URI module for a definition of canonical).

=cut

sub absolute_url {
  my( $self, $url ) = @_;
  my $uri = new URI( $url );
  return $self->{base_url} ? $uri->abs($self->{base_url}) : $uri->canonical;
}

=item B<list_nest_level>

  $level = $d->list_nest_level( $elem )

Returns the nest level of the given list item.

=cut

sub list_nest_level {
  my( $self, $node ) = @_;
  return $self->list_nest_level($node->parent) if ref $node and $node->tag =~ /(?:ol|ul)/;
  return 1 + $self->list_nest_level($node->parent) if $self->elem_has_ancestor($node, 'li');
  return 1;
}

=item B<trim>

  use HTML::WikiConverter::Dialect 'trim';
  trim( \$text )

Strips leading and trailing whitespace from $text. Modified $text in
place, returning nothing.

=cut

sub trim {
  my $text = shift;
  $$text =~ s/^\s+//;
  $$text =~ s/\s+$//;

  # Ensure nothing's returned
  return;
}

1;

=head1 COPYRIGHT

Copyright (c) 2004 David J. Iberri

This library is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

David J. Iberri <diberri@yahoo.com>

=cut
