package HTML::WikiConverter;

use warnings;
use strict;

use vars qw( $VERSION );
$VERSION = '0.17';

use Carp 'croak';
use HTML::PrettyPrinter;
use HTML::TreeBuilder;

#
# Changes
#
# version: 0.17
# date:    Wed 7/7/04 12:24:11 PST
# changes:
# - More documentation
# - Update test suite
# - Remove warnings reported by cpan testers
#
# version: 0.16
# date:    Fri 5/15/04 10:16:33 PST
# changes:
# - Added benchmarking (using Time::HiRes if available)
# - More Unicode support
# - Lots has been moved to HTML::WikiConverter::Dialect module
#
# version: 0.15
# date:    Sun 5/20/04 14:32:33 PST
# changes:
# - Added support for wiki dialects via HTML::WikiConverter::Dialect interface
# - Added HTML::WikiConverter::Dialect
# - Added HTML::WikiConverter::Dialect::MediaWiki
# - Added HTML::WikiConverter::Dialect::PhpWiki
# - Added HTML::WikiConverter::Dialect::Kwiki
# - Fixed spacing issues in tidy_whitespace
# - Added handling of container, block, and line elements
# - Now supports multiply-indented blocks
#
# version: 0.14
# date:    Thu 5/17/04 15:52:41 PST
# changes:
# - Changed 'wikify_default' to 'passthru' for semantic clarity
# - NOWIKI blocks are no longer preserved -- they shouldn't
#   appear in the HTML input, only in the WC output
# - Bug fix: Add newline to HTML source before wikification --
#   avoids apparent bugs in HTML::TreeBuilder that prevent proper
#   tag nesting
# - Added trim method to encapsulate whitespace trimming
# - '_elem_has_ancestor' now accepts a compiled regexp or
#   a tag name
# - If a regexp with capturing parens is passed into
#   '_elem_has_ancestor', then captured values will be returned
#   on a successful match
# - Added support for nested lists (though mixed UL/OL lists are
#   not handled correctly)
# - Bug fix: extra whitespace in PRE blocks is no longer trimmed
#   (required $parent parameter to 'wikify' method)
# - Ensures that PRE blocks have at least one single space at 
#   the start of each line contained within. So "<PRE>test</PRE>"
#   becomes " test" (on its own line).
# - CENTER and SMALL tags are now preserved (passthru support)
# - Added 'escape_wikitext' method to preserve "{{...}}" blocks
#   such as "{{msg:stub}}" or "{{NUMBEROFARTICLES}}"
# - Bug fix: Add leading space before wiki links
# - Can now produce "[[programming language]]s" wiki links
#
# version: 0.12
# date:    Mon 5/14/04 10:12:11 PST
# changes:
# - Bug fix: removed reference to non-existent 'has_parent'
#   method within '_elem_has_ancestor'
# - Bug fix: fixed potential bug in 'wikify_list_item'
#   which used $node->parent->tag eq '...' instead of
#   _elem_has_ancestor($node, '...')
# - Added support for definition lists
# - Added support for indentation
# - Replace code handler for P tag with flank handler
# - Replace code handler for OL/UL tags with flank handlers
# - Renamed 'wikify_heading' to 'wikify_h' for consistency
#   with other 'wikify_*' handlers
# - NOWIKI blocks are now preserved
# - Introduced beginnings of Unicode support with the
#   use of HTML::Entities
#
# version: 0.11
# date:    Thu 5/10/04 15:06:57 PST
# changes:
# - Added wikify_default -- a default handler for
#   tags that should be preserved. Tags without
#   handlers are removed from the wiki markup. So
#   for example, "<TAG>content</TAG>" becomes 
#   "content". By assigning the TAG to wikify_default,
#   the resulting wiki markup is "<tag>content</tag>".
#   All attributes are preserved as well.
# - Added wikify_span
# - New tags handled (FONT, SUP, SUB, SPAN->FONT conversion)
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
HTML source into wiki markup.

HTML to wiki conversion may be used in conjunction with in-browser
WYSIWYG text editors to provide a WYSIWYG wiki interface. For example,
a wiki edit page could allow users to modify text using a WYSIWYG
editor such as HTMLArea (see
http://dynarch.com/mishoo/htmlarea.epl). When the page is saved, HTML
is submitted to the server, which can then use HTML::WikiConverter to
translate the HTML back to its wikitext equivalent. Some alternative
solutions are enumerated at
http://meta.wikipedia.org/wiki/WYSIWYG_editor.

=head1 METHODS

=over

=item B<new>

  $wc = new HTML::WikiConverter( %attribs )

Accepts a list of attribute name/value pairs and returns
a new HTML::WikiConverter object. Allowed attribute names:

 file      - (scalar) name of HTML file to convert to wikitext
 html      - (scalar) HTML source to convert
 base_url  - (scalar) base URL used to make absolute URLs
 dialect   - (scalar) wiki engine target (default is 'MediaWiki')
 benchmark - (scalar) true value indicates that benchmarks
                      should be recorded

Supported wiki dialects are in the HTML::WikiConverter::Dialect
namespace. The default installation of HTML::WikiConverter includes
HTML::WikiConverter::Dialect::MediaWiki.

If both the 'file' and 'html' attributes are specified, only
the 'file' attribute will be used. The HTML source (from the 'html'
or 'file' attribute) is parsed immediately in the constructor.

All attributes (including those not listed above) will be passed
to the dialect class when creating a tag handler instance.

=cut

sub new {
  my( $pkg, %attr ) = @_;

  my $self = bless {
    file      => $attr{file},
    html      => $attr{html},
    root      => new HTML::TreeBuilder(),
    dialect   => $attr{dialect} || 'MediaWiki',
    benchmark => $attr{benchmark},
  }, $pkg;

  # Configure up the tree builder
  $self->root->implicit_tags(1);
  $self->root->implicit_body_p_tag(1);
  $self->root->ignore_ignorable_whitespace(1);
  $self->root->no_space_compacting(1);
  $self->root->ignore_unknown(0);
  $self->root->p_strict(1);

  # Load the dialect class or croak
  $self->{tag_handler_class} = "HTML::WikiConverter::Dialect::$self->{dialect}";
  eval "use $self->{tag_handler_class};";
  croak "No such tag handler class found '$self->{tag_handler_class}': $!" if $@;

  # Construct a new HTML::WikiConverter::Dialect::* object
  $self->{tag_handler} = $self->tag_handler_class->new( %attr, root => $self->root );
  $self->{tag_handler}->{root} = $self->root;
  $self->{tag_handler}->{base_url} = $attr{base_url};

  # Figure out if we should benchmark (only if
  # we were passed the "benchmarks" option and
  # Time::HiRes is installed)
  if( $self->{benchmark} ) {
    eval { require Time::HiRes; };
    $self->{do_benchmarks} = 1 unless $@;
  }
 
  # Parse HTML source
  if( $self->{file} ) {
    $self->root->parse_file( $self->file );
  } else {
    chomp $self->{html};

    # Convert HTML entities to Unicode characters
    eval {
      require HTML::Entities;
      HTML::Entities::decode_entities( $self->{html} );
    };

    my $time1 = [Time::HiRes::time()] if $self->{do_benchmarks};
    $self->root->parse( $self->html."\n" );
    $self->{parse_duration} = Time::HiRes::tv_interval( $time1 ) if $self->{do_benchmarks};
  }

  return $self;
}

=item B<file>

  $file = $wc->file

Returns the value of the 'file' property passed to the C<new> constructor.

=cut

sub file { shift->{file} }

=item B<html>

  $html = $wc->html

Returns the value of the 'html' property passed to the C<new> constructor.

=cut

sub html { shift->{html} }

=item B<root>

  $root = $wc->root

Returns the root HTML::Element of the HTML tree 

=cut

sub root { shift->{root} }

=item B<dialect>

=item B<tag_handler>

=item B<tag_handler_class>

  $dialect       = $wc->dialect
  $handler       = $wc->tag_handler
  $handler_class = $wc->tag_handler_class

Related methods that return information about the current dialect
being used to process incoming HTML. The C<dialect> method returns
whatever value was passed as the C<dialect> property in the C<new>
constructor.

The C<tag_handler_class> method returns the name of the dialect class,
such as "HTML::WikiConverter::Dialect::MediaWiki".

The C<tag_handler> returns the instance of the tag handler class that
is being used for HTML conversion.

=cut

sub dialect { shift->{dialect} }
sub tag_handler { shift->{tag_handler} }
sub tag_handler_class { shift->{tag_handler_class} }

=item B<output>

  $output = $wc->output

Converts HTML input to wiki markup.

=cut

sub output {
  my $self = shift;
  my $time1 = [Time::HiRes::time()] if $self->{do_benchmarks};
  my $output = $self->tag_handler->output;
  $self->{output_duration} = Time::HiRes::tv_interval( $time1 ) if $self->{do_benchmarks};
  return $output;
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
tag attributes are quoted, etc.

This method is useful for debugging.

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
