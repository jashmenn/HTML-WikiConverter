package HTML::WikiConverter;
use warnings;
use strict;

use URI;
use HTML::TreeBuilder;
use vars '$VERSION';
$VERSION = '0.22';

my %defaults = (
  dialect => undef,   # (Required) Which wiki dialect to use
  base_uri => '',     # Base URI for relative links
  wiki_uri => '',     # Wiki URI for wiki links
  wrap_in_html => 0,  # Wrap HTML in <html> and </html>
);

sub new {
  my( $pkg, %attrs ) = @_;

  my %opts = ( );
  while( my($attr, $value) = each %defaults ) {
    $opts{$attr} = $attrs{$attr} || $defaults{$attr};
  }

  die "Required 'dialect' parameter is missing." unless $opts{dialect};
  $opts{dialect_class} = "HTML::WikiConverter::$opts{dialect}";

  die "Dialect '$opts{dialect}' could not be loaded. " .
      "Perhaps $opts{dialect_class} isn't installed? Error: $@"
      unless eval "use $opts{dialect_class}; 1";

  # Load dialect's rules
  $opts{rules} = $opts{dialect_class}->rules;
  _check_rules( $opts{dialect}, $opts{rules} );

  return bless \%opts, $pkg;
}

sub base_uri {
  my( $self, $base_uri ) = @_;
  $self->{base_uri} = $base_uri if defined $base_uri;
  return $self->{base_uri} || '';
}

sub wiki_uri {
  my( $self, $wiki_uri ) = @_;
  $self->{wiki_uri} = $wiki_uri if defined $wiki_uri;
  return $self->{wiki_uri} || '';
}

sub wrap_in_html {
  my( $self, $wrap_in_html ) = @_;
  $self->{wrap_in_html} = $wrap_in_html if defined $wrap_in_html;
  return $self->{wrap_in_html} || '';
}

sub html2wiki {
  my( $self, $html ) = @_;

  return unless $html;
  $html = "<html>$html</html>" if $self->wrap_in_html;

  my $tree = new HTML::TreeBuilder();
  $tree->p_strict(1);
  $tree->implicit_body_p_tag(1);
  $tree->parse($html);

  # Preprocess the tree, giving dialect classes an opportunity to make
  # any necessary changes to the tree structure
  $self->_preprocess_tree($tree);

  # Save the HTML syntax tree and parsed HTML for later
  $self->{root} = $tree;
  $self->{parsed_html} = $tree->as_HTML( undef, '  ' );

  # Convert HTML to wiki markup
  my $output = $self->_wikify($tree);
  
  # Clean up newlines
  $output =~ s/\n[\s^\n]+\n/\n\n/g;
  $output =~ s/\n{2,}/\n\n/g;

  # Trim leading newlines and trailing whitespace; in supported wikis,
  # leading spaces likely have meaning, so we can't muck with 'em.
  # Leading and trailing newlines shouldn't be significant at all, so
  # we can safely discard them.
  $output =~ s/^\n+//s;
  $output =~ s/\s+$//s;

  # Delete the HTML syntax tree to prevent memory leaks
  $tree->delete();

  return $output;
}

sub parsed_html { return shift->{parsed_html} }

#
# Private methods
#

sub _wikify {
  my( $self, $node ) = @_;

  # Concatenate adjacent text nodes
  $node->normalize_content();

  if( $node->tag eq '~text' ) {
    return $node->attr('text');
  } else {
    # Get conversion rules
    my $rules = $self->{rules}->{$node->tag};
    $rules = $self->{rules}->{$rules->{alias}} if $rules->{alias};

    # The 'preserve' rule is an alias for "{ start =>
    # \&_preserve_start, end => '</tag>' }" This means that 'preserve'
    # cannot be specified with 'start' and 'end'; 'preserve' takes
    # precedence over the other two rules.
    if( $rules->{preserve} ) {
      $rules->{start} = \&_preserve_start,
      $rules->{end} = '</'.$node->tag.'>';
    }

    # Apply replacement
    return $self->_subst($rules->{replace}, $node, $rules) if exists $rules->{replace};

    # Get element's content
    my $output = $self->get_elem_contents($node);

    # Unspecified tags have their whitespace preserved (this allows
    # 'html' and 'body' tags [among others] to keep formatting when
    # inner tags like 'pre' need to preserve whitespace).
    my $trim = exists $rules->{trim} ? $rules->{trim} : 0;
    $output =~ s/^\s+// if $trim or $rules->{trim_leading};
    $output =~ s/\s+$// if $trim or $rules->{trim_trailing};

    # Handle newlines
    my $lf = $rules->{line_format} || '';
    if( $lf eq 'blocks' ) {
      # Three or more newlines are converted into \n\n
      $output =~ s/^\s*\n/\n/gm;
      $output =~ s/\n{3,}/\n\n/g;
    } elsif( $lf eq 'multi' ) {
      # Two or more newlines are converted into \n
      $output =~ s/^\s*\n/\n/gm;
      $output =~ s/\n{2,}/\n/g;
    } elsif( $lf eq 'single' ) {
      # Newlines are removed and replaced with single spaces
      $output =~ s/^\s*\n/\n/gm;
      $output =~ s/\n+/ /g;
    }

    # Apply substitutions
    $output = $self->_subst($rules->{start}, $node, $rules).$output if $rules->{start};
    $output = $output.$self->_subst($rules->{end}, $node, $rules) if $rules->{end};
    $output =~ s/^/$self->_subst($rules->{line_prefix}, $node, $rules)/mge if $rules->{line_prefix};
    
    # Nested block elements are not blocked
    $output = "\n\n$output\n\n" if $rules->{block} && ! $node->parent->look_up( _tag => $node->tag );
    
    return $output;
  }
}

sub _subst {
  my( $self, $subst, $node, $rules ) = @_;
  return $subst->( $self, $node, $rules ) if ref $subst eq 'CODE';
  return $subst;
}

#
# Returns a start string form preserved HTML elements and their
# attributes, if any. For example, if this was the HTML:
#
#   <span id='warning' class='alert' onclick="alert('Hey!')">Hey</span>
#
# And the rule for the 'span' element is
#
#   span => { preserve => 1, attributes => [ qw/ class / ] }
#
# Then this function will return '<span class="alert">'.
#
sub _preserve_start {
  my( $self, $node, $rules ) = @_;

  my $tag = $node->tag;
  my @attrs = exists $rules->{attributes} ? @{$rules->{attributes}} : ( );
  my $attr_str = $self->get_attr_str( $node, @attrs );

  return '<'.$tag.' '.$attr_str.'>' if $attr_str;
  return '<'.$tag.'>';
}

# Maps tag name to the attribute that should contain an absolute URI
my %abs2rel= (
  a => 'href',
  img => 'src'
);

# Traverse the tree, making adjustments according to the parameters
# passed during construction.
sub _preprocess_tree {
  my( $self, $root ) = @_;

  my $dc = $self->{dialect_class};
  my $dc_pn = $dc->can('preprocess_node') ? 1 : 0;

  $root->objectify_text();

  foreach my $node ( $root->descendents ) {
    my $tag = $node->tag || '';
    $self->_rel2abs_uri($node) if $self->base_uri and $abs2rel{$tag};
    $self->_rm_invalid_text($node);
    $dc->preprocess_node( $self, $node ) if $dc_pn;
  }

  # Must objectify text again in case preprocessing happened to add
  # any new text content
  $root->objectify_text();
}

# Convert relative to absolute URIs
sub _rel2abs_uri {
  my( $self, $node ) = @_;
  my $attr = $abs2rel{$node->tag};
  return unless $node->attr($attr); # don't add attribute if it's not already there
  $node->attr( $attr => URI->new($node->attr($attr))->abs($self->base_uri)->as_string );
}

# Removes text nodes directly inside container elements, since
# container elements cannot contain text. This is intended to
# remove excess whitespace in these elements.
my %containers = map { $_ => 1 } qw/ table tr tbody ul ol dl menu /;

sub _rm_invalid_text {
  my( $self, $node ) = @_;
  my $tag = $node->tag || '';
  if( $containers{$tag} ) {
    foreach my $child ( grep { $_->tag eq '~text' } $node->content_list ) {
      $child->replace_with('')->delete();
    }
  }
}

# Specifies what rule combinations are allowed. For example, 'trim'
# cannot be specified alongside 'trim_leading' or 'trim_trailing'.
# And 'replace' cannot be used in combination with any other rule,
# so it's a singleton. The 'attributes' rule is invalid unless it's
# accompanied by the 'preserve' rule.
my %rule_spec = (
  trim       => { disallow => [ qw/ trim_leading trim_trailing / ] },
  replace    => { singleton => 1 },
  alias      => { singleton => 1 },
  preserve   => { disallow => [ qw/ start end / ] },
  attributes => { require  => [ qw/ preserve / ] },
);

# Ensures that the dialect's rules are valid, according to %rule_spec
sub _check_rules {
  my( $dialect, $ruleset ) = @_;

  foreach my $tag ( keys %$ruleset ) {
    my $rules = $ruleset->{$tag};

    foreach my $opt ( keys %$rules ) {
      my $spec = $rule_spec{$opt} or next;

      my $singleton = $spec->{singleton} || 0;
      my @disallow = ref $spec->{disallow} eq 'ARRAY' ? @{ $spec->{disallow} } : ( );
      my @require = ref $spec->{require} eq 'ARRAY' ? @{ $spec->{require} } : ( );

      die "'$opt' cannot be combined with any other option in tag '$tag', dialect '$dialect'."
        if $singleton and keys %$rules != 1;

      $rules->{$_} && die "'$opt' cannot be combined with '$_' in tag '$tag', dialect '$dialect'."
        foreach @disallow;

      ! $rules->{$_} && die "'$opt' must be combined with '$_' in tag '$tag', dialect '$dialect'."
        foreach @require;
    }
  }
}

#
# Utility methods
#

sub get_elem_contents {
  my( $self, $node ) = @_;
  my $output = '';
  $output .= $self->_wikify($_) for $node->content_list;
  return $output;
}

sub get_wiki_page {
  my( $self, $url ) = @_;
  return undef unless $self->wiki_uri;
  return undef unless index( $url, $self->wiki_uri ) == 0;
  return undef unless length $url > length $self->wiki_uri;
  return substr( $url, length $self->wiki_uri );
}

my $UPPER    = '\p{UppercaseLetter}';
my $LOWER    = '\p{LowercaseLetter}';
my $WIKIWORD = "$UPPER$LOWER\\p{Number}\\p{ConnectorPunctuation}";

sub is_camel_case {
  return $_[1] =~ /(?:[$UPPER](?=[$WIKIWORD]*[$UPPER])(?=[$WIKIWORD]*[$LOWER])[$WIKIWORD]+)/;
}

sub get_attr_str {
  my( $self, $node, @attrs ) = @_;
  my %attrs = map { $_ => $node->attr($_) } @attrs;
  my $str = join ' ', map { "$_=\"$attrs{$_}\"" } grep $attrs{$_}, @attrs;
  return $str || '';
}

1;
__END__

=head1 NAME

HTML::WikiConverter - An HTML to wiki markup converter

=head1 SYNOPSIS

  use HTML::WikiConverter;
  my $wc = new HTML::WikiConverter( dialect => 'MediaWiki' );
  print $wc->html2wiki( $html );

=head1 DESCRIPTION

C<HTML::WikiConverter> is an HTML to wiki converter. It can convert HTML
source into a variety of wiki markups, called wiki "dialects".

=head1 METHODS

=over

=item new

  my $wc = new HTML::WikiConverter( dialect => $dialect, %attrs );

Returns a converter for the specified dialect. Dies if C<$dialect> is
not provided or is not installed on your system. (See L<Supported
dialects> for a list of supported dialects.) Additional parameters are
optional and can be included in C<%attrs>:

  base_uri
    URI to use for converting relative URIs to absolute ones

  wiki_uri
    URI used in determining which links are wiki links. For example,
    the English Wikipedia would use 'http://en.wikipedia.org/wiki/'

  wrap_in_html
    Helps C<HTML::TreeBuilder> parse HTML fragments by wrapping HTML
    in <html> and </html> before passing it through html2wiki()

=item html2wiki

  my $wiki = $wc->html2wiki( $html );

Converts the HTML source into wiki markup for the current dialect.

=item parsed_html

  my $html = $wc->parsed_html;

Returns the HTML representative of the last-parsed syntax tree. Use
this to see how your input HTML was parsed internally, which is often
useful for debugging.

=item base_uri

  my $base_uri = $wc->base_uri;
  $wc->base_uri( $new_base_uri );

Gets or sets the C<base_uri> option used for converting relative to
absolute URIs.

=item wiki_uri

  my $wiki_uri = $wc->wiki_uri;
  $wc->wiki_uri( $new_wiki_uri );

Gets or sets the C<wiki_uri> option used for determining which links
are links to wiki pages.

=item wrap_in_html

  my $wrap_in_html = $wc->wrap_in_html;
  $wc->wrap_in_html( $new_wrap_in_html );

Gets or sets the C<wrap_in_html> option used to help
C<HTML::TreeBuilder> parse (broken) fragments of HTML that aren't
contained within a parent element. For example, the following HTML
fragment causes trouble:

  Hello<br> goodbye.

This is parsed by C<HTML::TreeBuilder> as:

  <html>
    <head>
    </head>
    <body>
      <p><~text text="Hello"></~text><br>
    </body>
  </html>

Note that the string " goodbye" is missing. This can be resolved by
wrapping the HTML fragment in a parent element. In many cases a
E<lt>pE<gt> tag is appropriate, but it the general case E<lt>htmlE<gt>
is preferred: it has no meaning to wiki dialects and therefore has
very little chance of interfering with HTML-to-wiki conversion.

=back

=head1 UTILITY METHODS

These methods are for use only by dialect modules.

=over

=item get_elem_contents

  my $wiki = $wc->get_elem_contents( $node );

Converts the contents of C<$node> (i.e. its children) into wiki markup
and returns the resulting wiki markup.

=item get_wiki_page

  my $title = $wc->get_wiki_page( $url );

Attempts to extract the title of a wiki page from the given URL,
returning the title on success, undef on failure. If C<wiki_uri> is
empty, this method always return C<undef>. Assumes that URLs to wiki
pages are constructed using I<E<lt>wiki-uriE<gt>E<lt>page-nameE<gt>>.

=item is_camel_case

  my $ok = $wc->is_camel_case( $str );

Returns true if C<$str> is in CamelCase, false
otherwise. CamelCase-ness is determined using the same rules as
L<CGI::Kwiki>'s formatting module uses.

=item get_attr_str

  my $attr_str = $wc->get_attr_str( $node, @attrs );

Returns a string containing the specified attributes in the given
node. The returned string is suitable for insertion into an HTML tag.
For example, if C<$node> refers to the HTML

  <style id="ht" class="head" onclick="editPage()">Header</span>

and C<@attrs> contains "id" and "class", then C<get_attr_str> will
return 'id="ht" class="head"'.

=back

=head1 DIALECTS

C<HTML::WikiConverter> can convert HTML into markup for a variety of wiki
engines. The markup used by a particular engine is called a wiki
markup dialect. Support is added for dialects by installing dialect
modules which provide the rules for how HTML is converted into that
dialect's wiki markup.

Dialect modules are registered in the C<HTML::WikiConverter::>
namespace an are usually given names in CamelCase. For example, the
rules for the MediaWiki dialect are provided in
C<HTML::WikiConverter::MediaWiki>. And PhpWiki is specified in
C<HTML::WikiConverter::PhpWiki>.

=head2 Supported dialects

C<HTML::WikiConverter> supports conversions for the following dialects:

  Kwiki
  MediaWiki
  MoinMoin
  PhpWiki
  PmWiki
  UseMod

While under most conditions the each will produce satisfactory wiki
markup, the complete syntactic sugar of each dialect has not yet been
implemented. Suggestions, especially in the form of patches, are very
welcome.

Of these, the MediaWiki dialect is probably the most complete. I am a
Wikipediholic, after all. :-)

=head2 Conversion rules

To interface with C<HTML::WikiConverter>, dialect modules must define a
single C<rules> class method. It returns a reference to a hash of
rules that specify how individual HTML elements are converted to wiki
markup. The following rules are recognized:

  start
  end

  preserve
  attributes

  replace
  alias

  block
  line_format
  line_prefix
  
  trim
  trim_leading
  trim_trailing

For example, the following C<rules> method could be used for a wiki
dialect that uses *asterisks* for bold and _underscores_ for italic
text:

  sub rules {
    return {
      b => { start => '*', end => '*' },
      i => { start => '_', end => '_' }
    };
  }

To add E<lt>strongE<gt> and E<lt>emE<gt> as aliases of E<lt>bE<gt> and
E<lt>iE<gt>, use the 'alias' rule:

  sub rules {
    return {
      b => { start => '*', end => '*' },
      strong => { alias => 'b' },

      i => { start => '_', end => '_' },
      em => { alias => 'i' }
    };
  }

(If you specify the 'alias' rule, no other rules are allowed.)

Many wiki dialects separate paragraphs and other block-level elements
with a blank line. To indicate this, use the 'block' keyword:

  p => { block => 1 }

(Note that if a block-level element is nested inside another
block-level element, blank lines are only added to the outermost
block-level element.)

However, many such wiki engines require that the text of a paragraph
be contained on a single line of text. Or that a paragraph cannot
contain any blank lines. These formatting options can be specified
using the 'line_format' keyword, which can be assigned the value
'single', 'multi', or 'blocks'.

If the element must be contained on a single line, then the
'line_format' option should be 'single'. If the element can span
multiple lines, but there can be no blank lines contained within, then
it should be 'multi'. If blank lines (which delimit blocks) are
allowed, then it should be 'blocks'. For example, paragraphs are
specified like so in the MediaWiki dialect:

  p => { block => 1, line_format => 'multi', trim => 1 }

The 'trim' option indicates that leading and trailing whitespace
should be stripped from the paragraph before other rules are
processed. You can use 'trim_leading' and 'trim_trailing' if you only
want whitespace trimmed from one end of the content.

Some multi-line elements require that each line of output be prefixed
with a particular string. For example, preformatted text in the
MediaWiki dialect is prefixed with one or more spaces. This is
specified using the 'line_prefix' option:

  pre => { block => 1, line_prefix => ' ' }

In some cases, conversion from HTML to wiki markup is as simple as
string replacement. When you want to replace a tag and its contents
with a particular string, use the 'replace' option. For example, in
the PhpWiki dialect, three percent signs '%%%' represents a linebreak
E<lt>brE<gt>, hence the rule:

  br => { replace => '%%%' }

(If you specify the 'replace' option, no other options are allowed.)

Finally, many wiki dialects allow a subset of HTML in their markup,
such as for superscripts, subscripts, and text centering.  HTML tags
may be preserved using the 'preserve' option. For example, to allow
the E<lt>fontE<gt> tag in wiki markup, one might say:

  font => { preserve => 1 }

(The 'preserve' rule cannot be combined with the 'start' or 'end'
rules.)

Preserved tags may also specify a whitelist of attributes that may
also passthrough from HTML to wiki markup. This is done with the
'attributes' option:

  font => { preserve => 1, attributes => [ qw/ font size / ] }

(The 'attributes' rule must be used in conjunction with the 'preserve'
rule.)

=head2 Dynamic rules

Instead of simple strings, you may use coderefs as option values for
the 'start', 'end', 'replace', and 'line_prefix' rules. If you do, the
code will be called with three arguments: 1) the current
C<HTML::WikiConverter> instance, 2) the current L<HTML::Element> node,
and 3) the rules for that node (as a hashref).

Specifying rules dynamically is often useful for handling nested
elements. For example, the MoinMoin dialect uses the following rules
for lists:

  ul => { line_format => 'multi', block => 1, line_prefix => '  ' }
  li => { start => \&_li_start, trim_leading => 1 }
  ol => { alias => 'ul' }

It then defines C<_li_start> like so:

  sub _li_start {
    my( $wc, $node, $rules ) = @_;
    my $bullet = '';
    $bullet = '*'  if $node->parent->tag eq 'ul';
    $bullet = '1.' if $node->parent->tag eq 'ol';
    return "\n$bullet ";
  }

This ensures that every unordered list item is prefixed with '*' and
every ordered list item is prefixed with '1.', per the MoinMoin
markup. It also ensures that each list item is on a separate line and
that there is a space between the prefix and the content of the list
item.

=head2 Rule validation

Certain rule combinations are not allowed. For example, the 'replace'
and 'alias' rules cannot be combined with any other rules, and
'attributes' can only be specified alongside 'preserve'. Invalid rule
combinations will trigger an error when the dialect module is loaded.

=head2 Preprocessing

The first step in converting HTML source to wiki markup is to parse
the HTML into a syntax tree using L<HTML::TreeBuilder>. It is often
useful for dialects to preprocess the tree prior to converting it into
wiki markup. Dialects that elect to preprocess the tree do so by
defining a C<preprocess_node> class method, which will be called on
each node of the tree (traversal is done in pre-order). The method
receives three arguments: 1) the dialect's package name, 2) the
current C<HTML::WikiConverter> instance, and 3) the current
L<HTML::Element> node being traversed. It may modify the node or
decide to ignore it.  The return value of the C<preprocess_node>
method is not used.

Because they are so commonly needed, two preprocessing steps are
automatically carried out by C<HTML::WikiConverter>, regardless of the
dialect: 1) relative URIs in images and links are converted to
absolute URIs (based upon the 'base_uri' parameter), and 2) ignorable
text (e.g. between E<lt>/tdE<gt> and E<lt>tdE<gt>) is discarded.

=head1 BUGS

Please report bugs using http://rt.cpan.org.

=head1 SEE ALSO

L<HTML::TreeBuilder>, L<HTML::Element>

=head1 AUTHOR

David J. Iberri <diberri@yahoo.com>

=head1 COPYRIGHT

Copyright (c) 2004-2005 David J. Iberri

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
