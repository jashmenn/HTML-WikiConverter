package HTML::WikiConverter;
use warnings;
use strict;

use URI;
use HTML::Entities;
use HTML::TreeBuilder;
use vars '$VERSION';
$VERSION = '0.30';
our $AUTOLOAD;

sub new {
  my( $pkg, %opts ) = @_;

  if( $pkg eq __PACKAGE__ ) {
    die "Required 'dialect' parameter is missing" unless $opts{dialect};
    my $dc = __PACKAGE__.'::'.$opts{dialect};

    die "Dialect '$opts{dialect}' could not be loaded. Perhaps $dc isn't installed? Error: $@" unless eval "use $dc; 1";
    return $dc->new(%opts);
  }

  my $self = bless { }, $pkg;

  # Merge %opts and %attrs
  my %attrs = $self->attributes;
  while( my( $attr, $default ) = each %attrs ) {
    $opts{$attr} = defined $opts{$attr} ? $opts{$attr} : $default;
  }

  while( my( $attr, $value ) = each %opts ) {
    die "'$attr' is not a valid attribute." unless exists $attrs{$attr};
    $self->$attr($value);
  }

  $self->__rules( $self->rules );
  $self->__check_rules();
  return $self;
}

# List of allowed attributes with their defaults
sub attributes { (
  dialect        => undef, # Dialect to use (required unless instantiated from an H::WC subclass)
  base_uri       => undef, # Base URI for relative links
  wiki_uri       => undef, # Wiki URI for wiki links
  wrap_in_html   => 0,     # Wrap HTML in <html> and </html>
  strip_comments => 1,     # Strip HTML comments
  strip_head     => 1,     # Strip head element
  strip_scripts  => 1,     # Strip script elements
) }

# Private attributes
sub __root { shift->_param( __root => @_ ) }
sub __rules { shift->_param( __rules => @_ ) }

# Public accessors
sub parsed_html { shift->_param( __parsed_html => @_ ) }

# Utility method to make it easy to create accessors
sub _param {
  my( $self, $param, $value ) = @_;
  $self->{$param} = $value if defined $value;
  return $self->{$param} || '';
}

# For attribute accessors and mutators
sub AUTOLOAD {
  my $self = shift;
  my %attrs = $self->attributes;
  ( my $attr = $AUTOLOAD ) =~ s/.*://;
  return $self->_param( $attr => @_ ) if exists $attrs{$attr};
  die "Can't locate method '$attr' in package ".ref($self);
}

# So AUTOLOAD doesn't intercept calls to this method
sub DESTROY { }

# Should probably be using File::Slurp...
sub __slurp {
  my( $self, $file ) = @_;
  local *F; local $/;
  open F, $file or die "can't open file $file for reading: $!";
  my $f = <F>;
  close F;
  return $f;
}

sub html2wiki {
  my $self = shift;

  my %args = @_ == 1 ? ( html => +shift ) : @_;
  die "missing 'html' or 'file' argument to html2wiki" unless exists $args{html} or $args{file};
  die "cannot specify both 'html' and 'file' arguments to html2wiki" if exists $args{html} and exists $args{file};
  my $html = $args{html} || '';
  my $file = $args{file} || '';
  my $slurp = $args{slurp} || 0;

  # Wrap in <html> tags; this step must occur before slurping, as we
  # only apply 'wrap_in_html' to HTML strings, not files
  $html = "<html>$html</html>" if $self->wrap_in_html;

  # Slurp file to ensure that parsed HTML is exactly what was in the
  # source file, including whitespace, etc. This avoids HTML::Parser's
  # parse_file method, which reads and parses files incrementally,
  # which often does not result in the same exact parsing of
  # whitespace, etc.
  $html = $self->__slurp($file) if $file && $slurp;

  # Setup the tree builder
  my $tree = new HTML::TreeBuilder();
  $tree->store_comments(1);
  $tree->p_strict(1);
  $tree->implicit_body_p_tag(1);
  $tree->ignore_unknown(0); # <ruby> et al

  # Parse the HTML string or file
  if( $html ) {
    $tree->parse($html);
  } else { # file
    $tree->parse_file($file);
  }

  # Preprocess then save the HTML tree and parsed HTML
  $self->__preprocess_tree($tree);
  $self->__root( $tree );
  $self->parsed_html( $tree->as_HTML(undef, '  ') );

  # Convert HTML->wiki and post-process
  my $output = $self->__wikify($tree);
  $self->__postprocess_output(\$output);

  # Avoid memory leaks
  $tree->delete();

  return $output;
}

#
# Private methods
#

sub __wikify {
  my( $self, $node ) = @_;

  # Concatenate adjacent text nodes
  $node->normalize_content();

  if( $node->tag eq '~text' ) {
    return $node->attr('text');
  } elsif( $node->tag eq '~comment' ) {
    return '<!--' . $node->attr('text') . '-->';
  } else {
    # Get conversion rules
    my $rules = $self->__rules->{$node->tag};
    $rules = $self->__rules->{$rules->{alias}} if $rules->{alias};

    # The '__start' and '__end' rules are private; they get applied
    # before the public 'start' and 'end' rules. This allows dialects
    # to combine the 'start' and 'end' rules with the 'preserve' rule.
    if( $rules->{preserve} ) {
      $rules->{__start} = \&__preserve_start,
      $rules->{__end} = $rules->{empty} ? undef : '</'.$node->tag.'>';
    }

    # Apply replacement
    return $self->__subst($rules->{replace}, $node, $rules) if exists $rules->{replace};

    # Get element's content
    my $output = $self->get_elem_contents($node);

    # Unspecified tags have their whitespace preserved (this allows
    # 'html' and 'body' tags [among others] to keep formatting when
    # inner tags like 'pre' need to preserve whitespace).
    my $trim = exists $rules->{trim} ? $rules->{trim} : 'none';
    $output =~ s/^\s+// if $trim eq 'both' or $trim eq 'leading';
    $output =~ s/\s+$// if $trim eq 'both' or $trim eq 'trailing';

    # Handle newlines
    my $lf = $rules->{line_format} || 'none';
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
    } elsif( $lf eq 'none' ) {
      # Don't do anything
    }

    # Apply substitutions
    $output =~ s/^/$self->__subst($rules->{line_prefix}, $node, $rules)/mge if $rules->{line_prefix};
    $output = $self->__subst($rules->{__start}, $node, $rules).$output if $rules->{__start};
    $output = $output.$self->__subst($rules->{__end}, $node, $rules) if $rules->{__end};
    $output = $self->__subst($rules->{start}, $node, $rules).$output if $rules->{start};
    $output = $output.$self->__subst($rules->{end}, $node, $rules) if $rules->{end};
    
    # Nested block elements are not blocked
    $output = "\n\n$output\n\n" if $rules->{block} && ! $node->parent->look_up( _tag => $node->tag );
    
    return $output;
  }
}

# $subst is either a coderef or some other scalar: if it's a coderef,
# we call the coderef with three params; otherwise, we just return the
# scalar. Note that (unfortunately) this is not an object method call.
sub __subst {
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
sub __preserve_start {
  my( $self, $node, $rules ) = @_;

  my $tag = $node->tag;
  my @attrs = exists $rules->{attributes} ? @{$rules->{attributes}} : ( );
  my $attr_str = $self->get_attr_str( $node, @attrs );
  my $slash = $rules->{empty} ? ' /' : '';

  return '<'.$tag.' '.$attr_str.$slash.'>' if $attr_str;
  return '<'.$tag.$slash.'>';
}

# Maps tag name to the attribute that should contain an absolute URI
my %rel2abs = ( a => 'href', img => 'src' );

# Traverse the tree, making adjustments according to the parameters
# passed during construction.
sub __preprocess_tree {
  my( $self, $root ) = @_;

  $root->objectify_text();

  foreach my $node ( $root->descendents ) {
    $node->tag('') unless $node->tag;

    # Remove comments, scripts, and head nodes
    $self->__rm_node($node), next if $node->tag eq '~comment' and $self->strip_comments;
    $self->__rm_node($node), next if $node->tag eq 'script' and $self->strip_scripts;
    $self->__rm_node($node), next if $node->tag eq 'head' and $self->strip_head;

    $self->__rm_invalid_text($node);
    $self->__encode_entities($node) if $node->tag eq '~text';
    $self->__rel2abs($node) if $self->base_uri and $rel2abs{$node->tag};

    # Dialect preprocessing
    $self->preprocess_node($node);
  }

  # Must objectify text again in case preprocessing happened to add
  # any new text content
  $root->objectify_text();
}

# Removes the given node
sub __rm_node { pop->replace_with('')->delete() }

# Encodes high-bit and control characters found in the node's text to
# their equivalent HTML entities. Note that the quotes (specifically
# double quotes) aren't encoded because of their expected ubiquity in
# node text.
sub __encode_entities {
  my( $self, $node ) = @_;
  my $text = $node->attr('text') || '';
  encode_entities( $text, '^\n\r\t !\#\$%\'-;=?-~"' );
  $node->attr( text => $text );
}

# Convert relative to absolute URIs
sub __rel2abs {
  my( $self, $node ) = @_;
  my $attr = $rel2abs{$node->tag};
  return unless $node->attr($attr); # don't add attribute if it's not already there
  $node->attr( $attr => URI->new($node->attr($attr))->abs($self->base_uri)->as_string );
}

# Removes text nodes directly inside container elements, since
# container elements cannot contain text. This is intended to remove
# excess whitespace in these elements.
my %containers = map { $_ => 1 } qw/ table tbody tr ul ol dl menu /;

sub __rm_invalid_text {
  my( $self, $node ) = @_;
  my $tag = $node->tag || '';
  if( $containers{$tag} ) {
    $self->__rm_node($_) for grep $_->tag eq '~text', $node->content_list;
  }
}

# Can be overridden in dialects
sub preprocess_node { }

# Post-process wiki markup, esp. newlines
sub __postprocess_output {
  my( $self, $outref ) = @_;

  # Clean up newlines
  $$outref =~ s/\n[\s^\n]+\n/\n\n/g;
  $$outref =~ s/\n{2,}/\n\n/g;

  # Trim leading newlines and trailing whitespace; in supported wikis,
  # leading spaces likely have meaning, so we can't muck with 'em.
  # Leading and trailing newlines shouldn't be significant at all, so
  # we can safely discard them.
  $$outref =~ s/^\n+//;
  $$outref =~ s/\s+$//;

  $self->postprocess_output($outref);
}

# Can be overridden in dialects
sub postprocess_output { }

# Specifies what rule combinations are allowed. For example, 'replace'
# cannot be used in combination with any other rule, so it's a
# singleton; the 'attributes' rule is invalid unless it's accompanied
# by the 'preserve' rule, etc.
my %rule_spec = (
  trim        => { range => [ qw/ none both leading trailing / ] },
  line_format => { range => [ qw/ none single multi blocks / ] },
  replace     => { singleton => 1 },
  alias       => { singleton => 1 },
  attributes  => { depends => [ qw/ preserve / ] },
  empty       => { depends => [ qw/ preserve / ] }
);

# Ensures that the dialect's rules are valid, according to %rule_spec
sub __check_rules {
  my $self = shift;

  foreach my $tag ( keys %{ $self->__rules } ) {
    my $rules = $self->__rules->{$tag};

    foreach my $opt ( keys %$rules ) {
      my $spec = $rule_spec{$opt} or next;

      my $singleton = $spec->{singleton} || 0;
      my @disallows = ref $spec->{disallows} eq 'ARRAY' ? @{ $spec->{disallows} } : ( );
      my @depends = ref $spec->{depends} eq 'ARRAY' ? @{ $spec->{depends} } : ( );
      my @range = ref $spec->{range} eq 'ARRAY' ? @{ $spec->{range} } : ( );
      my %range = map { $_ => 1 } @range;

      $self->__rule_error( $tag, "'$opt' cannot be combined with any other option" )
        if $singleton and keys %$rules != 1;

      $rules->{$_} && $self->__rule_error( $tag, "'$opt' cannot be combined with '$_'" )
        foreach @disallows;

      ! $rules->{$_} && $self->__rule_error( $tag, "'$opt' must be combined with '$_'" )
        foreach @depends;

      $self->__rule_error( $tag, "Unknown '$opt' value '$rules->{$opt}'. '$opt' must be one of ", join(', ', map "'$_'", @range) )
        if @range and ! exists $range{$rules->{$opt}};
    }
  }
}

# Die with a message about a broken rule
sub __rule_error {
  my( $self, $tag, @msg ) = @_;
  my $dialect = ref $self;
  die @msg, " in tag '$tag', dialect '$dialect'.\n";
}

#
# Utility methods
#

sub get_elem_contents {
  my( $self, $node ) = @_;
  my $output = '';
  $output .= $self->__wikify($_) for $node->content_list;
  return $output;
}

sub get_wiki_page {
  my( $self, $url ) = @_;
  return undef unless $self->wiki_uri;
  return undef unless index( $url, $self->wiki_uri ) == 0;
  return undef unless length $url > length $self->wiki_uri;
  return substr( $url, length $self->wiki_uri );
}

# Adapted from Kwiki source
my $UPPER    = '\p{UppercaseLetter}';
my $LOWER    = '\p{LowercaseLetter}';
my $WIKIWORD = "$UPPER$LOWER\\p{Number}\\p{ConnectorPunctuation}";

sub is_camel_case { return $_[1] =~ /(?:[$UPPER](?=[$WIKIWORD]*[$UPPER])(?=[$WIKIWORD]*[$LOWER])[$WIKIWORD]+)/ }

sub get_attr_str {
  my( $self, $node, @attrs ) = @_;
  my %attrs = map { $_ => $node->attr($_) } @attrs;
  my $str = join ' ', map { $_.'="'.encode_entities($attrs{$_}).'"' } grep $attrs{$_}, @attrs;
  return $str || '';
}

#
# Common methods for node preprocessing
#

sub strip_aname {
  my( $self, $node ) = @_;
  return if $node->attr('href');
  $node->replace_with_content->delete();
}

sub caption2para {
  my( $self, $node ) = @_;
  my $table = $node->parent;
  $node->detach();
  $table->preinsert($node);
  $node->tag('p');
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
source into a variety of wiki markups, called wiki "dialects". The following
dialects are supported:

  DocuWiki
  Kwiki
  MediaWiki
  MoinMoin
  Oddmuse
  PhpWiki
  PmWiki
  SlipSlap
  TikiWiki
  UseMod
  WakkaWiki

Note that while dialects usually produce satisfactory wiki markup, not
all features of all dialects are supported. Consult individual
dialects' documentation for details of supported features. Suggestions
for improvements, especially in the form of patches, are very much
appreciated.

=head1 METHODS

=over

=item new

  my $wc = new HTML::WikiConverter( dialect => $dialect, %attrs );

Returns a converter for the specified dialect. Dies if C<$dialect> is
not provided or is not installed on your system. Attributes may be
specified in C<%attrs>; see L</"ATTRIBUTES"> for a list of recognized
attributes.

=item html2wiki

  $wiki = $wc->html2wiki( $html );
  $wiki = $wc->html2wiki( html => $html );
  $wiki = $wc->html2wiki( file => $path, slurp => $slurp );

Converts HTML source to wiki markup for the current dialect. Accepts
either an HTML string C<$html> or an HTML file C<$path> to read from.
You may optionally bypass C<HTML::Parser>'s incremental parsing of
HTML files by giving C<$slurp> a true value.

=item dialect

  my $dialect = $wc->dialect;

Returns the name of the dialect used to construct this
C<HTML::WikiConverter> object.

=item parsed_html

  my $html = $wc->parsed_html;

Returns C<HTML::TreeBuilder>'s representation of the last-parsed
syntax tree, showing how the input HTML was parsed internally. This is
often useful for debugging.

=back

=head1 ATTRIBUTES

You may configure C<HTML::WikiConverter> using a number of
attributes. These may be passed as arguments to the C<new>
constructor, or can be called as object methods on a
C<HTML::WikiConverter> object.

=over

=item base_uri

URI to use for converting relative URIs to absolute ones. This
effectively ensures that the C<src> and C<href> attributes of image
and anchor tags, respectively, are absolute before converting the HTML
to wiki markup, which is necessary for wiki dialects that handle
internal and external links separately. Relative URLs are only
converted to absolute ones if the C<base_uri> argument is
present. Defaults to C<undef>.

=item wiki_uri

URI used in determining which links are wiki links. This assumes that
URLs to wiki pages are created by joining the C<wiki_uri> with the
(possibly escaped) wiki page name. For example, the English Wikipedia
would use C<"http://en.wikipedia.org/wiki/">, while Ward's wiki would
use C<"http://c2.com/cgi/wiki?">. Defaults to C<undef>.

=item wrap_in_html

Helps C<HTML::TreeBuilder> parse HTML fragments by wrapping HTML in
C<E<lt>htmlE<gt>> and C<E<lt>/htmlE<gt>> before passing it through
C<html2wiki>. Defaults to C<0>.

=item strip_comments

Removes HTML comments from the input before conversion to wiki markup.
Defaults to C<1>.

=item strip_head

Removes the HTML C<head> element from the input before
converting. Defaults to C<1>.

=item strip_scripts

Removes all HTML C<script> elements from the input before
converting. Defaults to C<1>.

=back

Some dialects allow other parameters in addition to these. Consult
individual dialect documentation for details.

=head1 DIALECTS

C<HTML::WikiConverter> can convert HTML into markup for a variety of
wiki engines. The markup used by a particular engine is called a wiki
markup dialect. Support is added for dialects by installing dialect
modules which provide the rules for how HTML is converted into that
dialect's wiki markup.

Dialect modules are registered in the C<HTML::WikiConverter::>
namespace an are usually given names in CamelCase. For example, the
rules for the MediaWiki dialect are provided in
C<HTML::WikiConverter::MediaWiki>. And PhpWiki is specified in
C<HTML::WikiConverter::PhpWiki>.

This section is intended for dialect module authors.

=head2 Conversion rules

To interface with C<HTML::WikiConverter>, dialect modules must define a
single C<rules> class method. It returns a reference to a hash of
rules that specify how individual HTML elements are converted to wiki
markup.

=head3 Supported rules

The following rules are recognized:

  start
  end

  preserve
  attributes
  empty

  replace
  alias

  block
  line_format
  line_prefix

  trim

=head3 Simple rules method

For example, the following C<rules> method could be used for a wiki
dialect that uses *asterisks* for bold and _underscores_ for italic
text:

  sub rules {
    return {
      b => { start => '*', end => '*' },
      i => { start => '_', end => '_' }
    };
  }

=head3 Aliases

To add E<lt>strongE<gt> and E<lt>emE<gt> as aliases of E<lt>bE<gt> and
E<lt>iE<gt>, use the C<alias> rule:

  sub rules {
    return {
      b => { start => '*', end => '*' },
      strong => { alias => 'b' },

      i => { start => '_', end => '_' },
      em => { alias => 'i' }
    };
  }

Note that if you specify the C<alias> rule, no other rules are allowed.

=head3 Blocks

Many wiki dialects separate paragraphs and other block-level elements
with a blank line. To indicate this, use the C<block> rule:

  p => { block => 1 }

Note that if a block-level element is nested inside another
block-level element, blank lines are only added to the outermost
block-level element.

=head3 Line formatting

However, many such wiki engines require that the text of a paragraph
be contained on a single line of text. Or that a paragraph cannot
contain any blank lines. These formatting options can be specified
using the C<line_format> rule, which can be assigned the value
C<"single">, C<"multi">, or C<"blocks">.

If the element must be contained on a single line, then the
C<line_format> rule should be C<"single">. If the element can span
multiple lines, but there can be no blank lines contained within, then
it should be C<"multi">. If blank lines (which delimit blocks) are
allowed, then use C<"blocks">. For example, paragraphs are specified
like so in the MediaWiki dialect:

  p => { block => 1, line_format => 'multi', trim => 'both' }

=head3 Trimming whitespace

The C<trim> rule specifies whether leading or trailing whitespace (or
both) should be stripped from the paragraph. To strip leading
whitespace only, use C<"leading">; for trailing whitespace, use
C<"trailing">; for both, use the aptly named C<"both">; for neither
(the default), use C<"none">.

=head3 Line prefixes

Some multi-line elements require that each line of output be prefixed
with a particular string. For example, preformatted text in the
MediaWiki dialect is prefixed with a space:

  pre => { block => 1, line_prefix => ' ' }

=head3 Replacement

In some cases, conversion from HTML to wiki markup is as simple as
string replacement. When you want to replace a tag and its contents
with a particular string, use the C<replace> rule. For example, in the
PhpWiki dialect, three percent signs '%%%' represents a linebreak
C<E<lt>br /E<gt>>, hence the rule:

  br => { replace => '%%%' }

If you specify the C<replace> rule, no other options are allowed.

=head3 Preserving HTML tags

Finally, many wiki dialects allow a subset of HTML in their markup,
such as for superscripts, subscripts, and text centering.  HTML tags
may be preserved using the C<preserve> rule. For example, to allow the
E<lt>fontE<gt> tag in wiki markup, one might say:

  font => { preserve => 1 }

Preserved tags may also specify a whitelist of attributes that may
also passthrough from HTML to wiki markup. This is done with the
C<attributes> option:

  font => { preserve => 1, attributes => [ qw/ font size / ] }

The C<attributes> rule must be used in conjunction C<preserve>.

Some HTML elements have no content (e.g. line breaks), and should be
preserved specially. To indicate that a preserved tag should have no
content, use the C<empty> rule. This will cause the element to be
replaced with C<"E<lt>tag /E<gt>">, with no end tag and any attributes
you specified. For example, the MediaWiki dialect handles line breaks
like so:

  br => {
    preserve => 1,
    attributes => qw/ id class title style clear /,
    empty => 1
  }

This will convert, e.g., C<"E<lt>br clear='both'E<gt>"> into
C<"E<lt>br clear='both' /E<gt>">.  Without specifying the C<empty>
rule, this would be converted into the undesirable C<"E<lt>br
clear='both'E<gt>E<lt>/brE<gt>">.

The C<empty> rule must be combined with the C<preserve> rule.

=head2 Dynamic rules

Instead of simple strings, you may use coderefs as values for the
C<start>, C<end>, C<replace>, and C<line_prefix> rules. If you do, the
code will be called as a method on the current C<HTML::WikiConverter>
dialect object, and will be passed the current L<HTML::Element> node
and a hashref of the dialect's rules for processing elements of that
type.

For example, the MoinMoin dialect uses the following rules for lists:

  ul => { line_format => 'multi', block => 1, line_prefix => '  ' }
  li => { start => \&_li_start, trim => 'leading' }
  ol => { alias => 'ul' }

It then defines C<_li_start> like so:

  sub _li_start {
    my( $self, $rules ) = @_;
    my $bullet = '';
    $bullet = '*'  if $node->parent->tag eq 'ul';
    $bullet = '1.' if $node->parent->tag eq 'ol';
    return "\n$bullet ";
  }

This ensures that every unordered list item is prefixed with C<*> and
every ordered list item is prefixed with C<1.>, required by the
MoinMoin syntax. It also ensures that each list item is on a separate
line and that there is a space between the prefix and the content of
the list item.

=head2 Rule validation

Certain rule combinations are not allowed. For example, the C<replace>
and C<alias> rules cannot be combined with any other rules, and
C<attributes> can only be specified alongside C<preserve>. Invalid
rule combinations will trigger an error when the
C<HTML::WikiConverter> object is instantiated.

=head2 Dialect attributes

The attributes that are recognized by the C<HTML::WikiConverter> are
given in the C<attributes> method, which returns a hash of attribute
names and their defaults. Dialects that wish to alter the set of
recognized attributes must override this method. For example, to add
a boolean attribute called C<camel_case> with is disabled by default,
a dialect would define an C<attributes> method like so:

  sub attributes { (
    shift->SUPER::attributes,
    camel_case => 0
  ) }

Attributes defined liks this are given accessor and mutator methods,
as in:

  my $ok = $wc->camel_case; # accessor
  $wc->camel_case(0); # mutator

=head2 Preprocessing

The first step in converting HTML source to wiki markup is to parse
the HTML into a syntax tree using L<HTML::TreeBuilder>. It is often
useful for dialects to preprocess the tree prior to converting it into
wiki markup. Dialects that elect to preprocess the tree do so by
defining a C<preprocess_node> object method which will be called on
each node of the tree (traversal is done in pre-order). As its only
argument the method receives the current L<HTML::Element> node being
traversed. It may modify the node or decide to ignore it.  The return
value of the C<preprocess_node> method is discarded.

=head3 Built-in preprocessors

Because they are so commonly needed, two preprocessing steps are
automatically carried out by C<HTML::WikiConverter>, regardless of the
dialect: 1) relative URIs in images and links are converted to
absolute URIs (based upon the C<base_uri> parameter), and 2) ignorable
text (e.g. between E<lt>/tdE<gt> and E<lt>tdE<gt>) is discarded.

C<HTML::WikiConverter> also provides additional preprocessing steps
that may be explicitly enabled by dialect modules.

=over

=item strip_aname

Removes from the HTML input any anchor elements that do not contain an
C<href> attribute.

=item caption2para

Removes table captions and reinserts them as paragraphs before the
table.

=back

Dialects may apply these preprocessing steps by calling them as
methods on the dialect object inside C<preprocess_node>. For example:

  sub preprocess_node {
    my( $self, $node ) = @_;
    $self->strip_aname($node);
    $self->caption2para($node);
  }

=head2 Postprocessing

Once the work of converting HTML, it is sometimes useful to
postprocess the resulting wiki markup. Postprocessing can be used to
clean up whitespace, fix subtle bugs in the markup that can't
otherwise be done in the original conversion, etc.

Dialects that want to postprocess the wiki markup should define a
C<postprocess_output> object method that will be called just before
theC<html2wiki> method returns to the client. The method will be
passed a single argument, a reference to the wiki markup. It may
modify the wiki markup that the reference points to. Its return value
is discarded.

For example, to convert a series of line breaks to be replaced with
a pair of newlines, a dialect might implement this:

  sub postprocess_output {
    my( $self, $outref ) = @_;
    $$outref =~ s/<br>\s*<br>/\n\n/g;
  }

(This example assumes that HTML line breaks were replaced with
C<E<lt>brE<gt>> in the wiki markup.)

=head2 Dialect utility methods

C<HTML::WikiConverter> defines a set of utility methods for use by
dialect modules.

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

=head1 BUGS

Please report bugs using http://rt.cpan.org.

=head1 SEE ALSO

L<HTML::Tree>, L<HTML::Element>

=head1 AUTHOR

David J. Iberri <diberri@yahoo.com>

=head1 COPYRIGHT

Copyright (c) 2004-2005 David J. Iberri

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
