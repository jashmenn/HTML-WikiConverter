package HTML::WikiConverter;

use warnings;
use strict;

use vars qw( $VERSION );
$VERSION = '0.15';

use Carp 'croak';
use HTML::PrettyPrinter;
use HTML::TreeBuilder;

#
# Changes
#
# Vers 0.15 - 5/20/04
# o Added support for wiki dialects via HTML::WikiConverter::Dialect interface
# o Added HTML::WikiConverter::Dialect
# o Added HTML::WikiConverter::Dialect::MediaWiki
# o Added HTML::WikiConverter::Dialect::PhpWiki
# o Added HTML::WikiConverter::Dialect::Kwiki
# o Fixed spacing issues in tidy_whitespace
# o Added handling of containers, blocks, and line elements
# o Now supports multiply-indented blocks
# o 
#
# Vers 0.14 - 5/17/04
# o Changed 'wikify_default' to 'passthru' for semantic clarity
# o NOWIKI blocks are no longer preserved -- they shouldn't
#   appear in the HTML input, only in the WC output
# o Bug fix: Add newline to HTML source before wikification --
#   avoids apparent bugs in HTML::TreeBuilder that prevent proper
#   tag nesting
# o Added trim method to encapsulate whitespace trimming
# o '_elem_has_ancestor' now accepts a compiled regexp or
#   a tag name
# o If a regexp with capturing parens is passed into
#   '_elem_has_ancestor', then captured values will be returned
#   on a successful match
# o Added support for nested lists (though mixed UL/OL lists are
#   not handled correctly)
# o Bug fix: extra whitespace in PRE blocks is no longer trimmed
#   (required $parent parameter to 'wikify' method)
# o Ensures that PRE blocks have at least one single space at 
#   the start of each line contained within. So "<PRE>test</PRE>"
#   becomes " test" (on its own line).
# o CENTER and SMALL tags are now preserved (passthru support)
# o Added 'escape_wikitext' method to preserve "{{...}}" blocks
#   such as "{{msg:stub}}" or "{{NUMBEROFARTICLES}}"
# o Bug fix: Add leading space before wiki links
# o Can now produce "[[programming language]]s" wiki links
#
# Vers 0.12 - 5/14/04
# o Bug fix: removed reference to non-existent 'has_parent'
#   method within '_elem_has_ancestor'
# o Bug fix: fixed potential bug in 'wikify_list_item'
#   which used $node->parent->tag eq '...' instead of
#   _elem_has_ancestor($node, '...')
# o Added support for definition lists
# o Added support for indentation
# o Replace code handler for P tag with flank handler
# o Replace code handler for OL/UL tags with flank handlers
# o Renamed 'wikify_heading' to 'wikify_h' for consistency
#   with other 'wikify_*' handlers
# o NOWIKI blocks are now preserved
# o Introduced beginnings of Unicode support with the
#   use of HTML::Entities
#
# Vers 0.11 - 5/10/04
# o Added wikify_default -- a default handler for
#   tags that should be preserved. Tags without
#   handlers are removed from the wiki markup. So
#   for example, "<TAG>content</TAG>" becomes 
#   "content". By assigning the TAG to wikify_default,
#   the resulting wiki markup is "<tag>content</tag>".
#   All attributes are preserved as well.
# o Added wikify_span
# o New tags handled
#   - FONT, SUP, SUB are now preserved in wiki markup (see wikify_default)
#   - SPAN: attempts to convert into FONT (see wikify_span)
#

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
 dialect  - (scalar) wiki engine target, either MediaWiki
                     or PhpWiki (default: MediaWiki)

If both the 'file' and 'html' attributes are specified, only
the 'file' attribute will be used.

=cut

sub new {
  my( $pkg, %attr ) = @_;

  my $self = bless {
    file     => $attr{file},
    html     => $attr{html},
    root     => new HTML::TreeBuilder(),
    dialect  => $attr{dialect} || 'MediaWiki'
  }, $pkg;

  # Configure up the tree builder
  $self->root->implicit_tags(1);
  $self->root->implicit_body_p_tag(1);
  $self->root->ignore_ignorable_whitespace(1);
  $self->root->no_space_compacting(1);
  $self->root->ignore_unknown(0);
  $self->root->p_strict(1);

  # Load the tag handler class or croak
  $self->{tag_handler_class} = "HTML::WikiConverter::Dialect::$self->{dialect}";
  eval "use $self->{tag_handler_class};";
  croak "No such tag handler class found '$self->{tag_handler_class}': $!" if $@;

  $self->{tag_handler} = $self->tag_handler_class->new( %attr );
  $self->{tag_handler}->{root} = $self->root;
  $self->{tag_handler}->{base_url} = $attr{base_url};
 
  # Parse HTML source
  if( $self->{file} ) {
    $self->root->parse_file( $self->file );
  } else {
    chomp $self->{html};
    $self->root->parse( $self->html."\n" );
  }

  return $self;
}

sub file { shift->{file} }
sub html { shift->{html} }
sub root { shift->{root} }
sub dialect { shift->{dialect} }
sub tag_handler { shift->{tag_handler} }
sub tag_handler_class { shift->{tag_handler_class} }

=item B <output>

  $output = $wc->output

Converts HTML input to wiki markup.

=cut

sub output {
  shift->tag_handler->output;
}

=item B<log>

  $log_output = $wc->log

Returns log information accumulated during conversion.

=cut

sub log {
  shift->tag_handler->log;
}

=item B<rendered_html>

  $html = $wc->rendered_html

Returns a pretty-printed version of the HTML that WikiConverter used
to produce wikitext markup. This will almost certainly differ from the
HTML input provided to C<new> because of internal processing done by
HTML::TreeBuilder, namely that all start tags are closed, HTML, BODY,
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

  my $fmt = $pp->format($self->root);
  return join '', @$fmt;
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

=head2 Code handlers

Code handlers are the most flexible type of tag handlers. When an
element is encountered that has a code handler, the handler is
executed as a method call. The code handler receives two arguments,
the current HTML::WikiConverter instance, and the HTML::Element
being processed. The return value of the handler should be wikitext
markup.

Since code handlers must return wikitext markup, they must be sure
to continue processing the tree of elements contained within the
element passed to the handler. This can be done with the C<elem_contents>
function:

  sub wikify_table {
    my( $wc, $elem ) = @_;
    return "{|\n".$wc->elem_contents($elem)."\n|}";
  }

This ensures that elements contained within $elem are wikified properly
(i.e., they're appropriate handlers are dispatched).

=back

=cut

# Deletes the underlying HTML tree (see HTML::Element)
sub DESTROY {
  my $self = shift;
  $self->root->delete();
}

=head1 COPYRIGHT

Copyright (c) 2004 David J. Iberri

This library is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

David J. Iberri <diberri@yahoo.com>

=cut

1;
