package HTML::WikiConverter::Dialect;

use vars qw($VERSION);
$VERSION = '0.14';

require Exporter;
use base 'Exporter';
use vars qw( @EXPORT_OK );
@EXPORT_OK = qw/trim passthru/;

use URI;

=head1 NAME

HTML::WikiConverter::Dialect - Base class for wiki engine dialects

=head1 SYNOPSIS

  #
  # Create a subclass of HTML::WikiConverter::Dialect
  #

  package HTML::WikiConverter::Dialect::MyWikiEngine;
  use base 'HTML::WikiConverter::Dialect';

  sub tag_handlers {
    return {
      i   => [ "/", "/" ],
      pre => \&wikify_pre
      # ... etc.
    }
      
  }

  sub wikify_pre {
    my( $self, $node ) = @_;
    # ...
  }

  #
  # Use your new wiki dialect
  #

  my $wc = new HTML::WikiConverter(
    html    => "<B>My HTML</B>",
    dialect => "MyWikiENgine"
  );

  print $wc->output;

=head1 DESCRIPTION

HTML::WikiConverter::Dialect is a base class for wiki engine
dialects. It is meant for use only by developers creating new wiki
dialects to be used with the HTML::WikiConverter interface.

B<Note>: If you are trying to convert HTML to wiki markup, you should
not be using this module directly. Use HTML::WikiConverter instead.
Only developers of new wiki dialects should need this module.

=head1 METHODS

=over

=item B<new>

  $d = new HTML;;WikiConverter::Dialect::MyDialect( %attr )

Default constructor (intended for subclassing).

=cut

sub new {
  my( $pkg, %attr ) = @_;
  return bless \%attr, $pkg;
}

=item B<tag_handlers>

  $hashref = $d->tag_handlers

Returns a reference to a hash of tag handlers defined (meant
to be overriden by subclass).

=cut

sub tag_handlers { return {} }

=item B<root>

  $elem = $d->root

Returns the root HTML::Element associated with this dialect.

=cut

sub root { shift->{root} }

sub container_elements {
  return { map { $_ => 1 } qw(
    table tr dl dd dt ul ol li
  ) };
}

sub block_elements {
  return { map { $_ => 1 } qw(
    dl dt dd p div table
  ) };
}

sub line_elements {
  return { map { $_ => 1 } qw(
    li
  ) };
}

=item B<output>

  $wikitext = $wc->output()

Converts the original HTML source and returns it as wiki markup.

=cut

sub output {
  my $self = shift;

  my $output = $self->wikify( $self->root );
  $self->tidy_whitespace( \$output );

  return $output;
}

=item B<tidy_whitespace>

  $wc->tidy_whitespace( \$text )

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

=item B<wikify>

  $output = $wc->wikify( $elem [, $parent ] )

Converts the HTML::Element specified by $elem into wikitext markup and
returns the wikitext. If $elem is a text element, then $parent (if
defined) will be used as its parent.

=cut

sub wikify {
  my( $self, $node, $parent ) = @_;

  # Will be returned at end
  my $output = '';

  # Determine how to process
  if( UNIVERSAL::isa( $node, 'HTML::Element' ) ) {
    # HTML::Element node
    my $conv = $self->tag_handlers->{$node->tag};
    if( ref $conv eq 'CODE' ) {
      # Code handler
      $output = $conv->( $self, $node );
    } elsif( ref $conv eq 'ARRAY' ) {
      # Flank handler
      $output .= $self->wikify($_, $node) for $node->content_list;
      $output = $conv->[0].$output.$conv->[-1];
    } elsif( defined $conv ) {
      # Replacement handler
      $output = $conv;
      $output .= $self->wikify($_, $node) foreach $node->content_list;
    } else {
      # No handler
      $output = $self->wikify($_, $node) for $node->content_list;
    }
  } else {
    # Text-only node
    $output = $node;

    # Whitespace inside non display containers is ignored
    if( ref $parent and $self->container_elements->{$parent->tag} and $node !~ /\S/ ) {
      $output = '';
    }

    if( ref $parent and $self->block_elements->{$parent->tag} and $output ) {
      $output =~ s/^[\r\n]+/ /;
      $output =~ s/[\r\n]+$/ /;
    }

    # Two or more spaces are converted into a single space, and trailing
    # newlines are replaced with a single newline (unless we're inside
    # a PRE tag)
    unless( ref $parent and $parent->tag eq 'pre' ) {
      $output =~ s/[\r\n]+$/\n/;
      $output =~ s/ {2,}/ /g;
    }

    # Line elements have a single trailing newline
    if( ref $parent and $self->line_elements->{$parent->tag} and $output ) {
      $output =~ s/[\r\n]*$/\n/;
    }
  }

  return $output;
}

=item B<elem_contents>

  $outpupt = $wc->elem_contents( $elem )

Returns a wikified version of the contents of the specified HTML
element. This is done by passing each element of the content list
through the C<wikify()> method, and returning the concatenated result.

=cut

sub elem_contents {
  my( $self, $node ) = @_;

  my $output = '';
  $output .= $self->wikify($_, $node) foreach $node->content_list;
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

sub list_nest_level {
  my( $self, $node ) = @_;
  return $self->list_nest_level($node->parent) if ref $node and $node->tag =~ /(?:ol|ul)/;
  return 1 + $self->list_nest_level($node->parent) if $self->elem_has_ancestor($node, 'li');
  return 1;
}

=item B<passthru>

  $output = passthru( $elem )

This handler should be assigned to all tags that do not
need further processing. For example, in order to preserve
FONT tags from the HTML source in the wiki output, one
must use

  $wc->set_handler( font => \&HTML::WikiConverter::passthru );

This ensures that FONT tags are not simply removed from the
HTML source.

=cut

sub passthru {
  my( $self, $node ) = @_;

  my $content = $self->elem_contents($node);

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

#
# Private function: elem_attr_str( $elem, @attrs )
#
# Returns a string containing a list of attribute names and
# values associated with the specified HTML element. Only
# attribute names included in @attrs will be added to the
# string of attributes that is returned. The return value
# is suitable for inserting into an HTML document, as
# attribute name/value pairs are specified in attr="value"
# format.
#

sub elem_attr_str {
  my( $self, $node, @attrs ) = @_;
  return join ' ', map {
    "$_=\"".$node->attr($_)."\""
  } grep {
    my $attr = $node->attr($_);
    defined $attr && length $attr
  } @attrs;
}

#
# Private function: $self->elem_has_ancestor( $elem, $tag )
#
# Returns true if the specified HTML::Element has an ancestor element
# whose element tag matches $tag. The $tag parameter may be either a
# string corresponding to the name of the ancestor tag, or it may be a
# compiled regexp (qr//) with which to match. This is useful for
# determining if an element belongs to the specified tag.
#

sub elem_has_ancestor {
  my( $self, $node, $tag ) = @_;

  return 0 unless ref $node;

  # Force interpretation as regular expression
  $tag = qr/^$tag$/i unless ref $tag eq 'Regexp';

  if( ref $node->parent ) {
    if( my @vals  = $node->parent->tag =~ $tag ) {
      return @vals;
    }
    return $self->elem_has_ancestor( $node->parent, $tag );
  }

  return 0;
}

#
# Private function: elem_is_image_div( $elem )
#
# Returns true $elem is a container element (P or DIV) meant only to
# lay out an IMG.
#
# More specifically, returns true if the given element is a DIV or P
# element and the only child it contains is an IMG tag or an IMG tag
# contained within a sole A tag (not counting child elements with
# whitespace text only).
#

sub elem_is_image_div {
  my( $self, $node ) = @_;

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

#
# Private function: trim( \$text )
#
# Strips leading and trailing whitespace from $text. Modifies $text,
# returning nothing valuable.
#

sub trim {
  my $text = shift;
  $$text =~ s/^\s+//;
  $$text =~ s/\s+$//;
}

1;
