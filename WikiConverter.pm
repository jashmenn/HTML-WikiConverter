package HTML::WikiConverter;
use warnings;
use strict;

use URI;
use Encode;
use HTML::Entities;
use HTML::TreeBuilder;
use vars '$VERSION';
$VERSION = '0.40';
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

sub attributes { (
  dialect        => undef,  # Dialect to use (required unless instantiated from an H::WC subclass)
  base_uri       => undef,  # Base URI for relative links
  wiki_uri       => undef,  # Wiki URI for wiki links
  wrap_in_html   => 1,      # Wrap HTML in <html> and </html>
  strip_comments => 1,      # Strip HTML comments
  strip_head     => 1,      # Strip head element
  strip_scripts  => 1,      # Strip script elements
  encoding       => 'utf8', # Input encoding
) }

sub __root { shift->__param( __root => @_ ) }
sub __rules { shift->__param( __rules => @_ ) }
sub parsed_html { shift->__param( __parsed_html => @_ ) }

sub __param {
  my( $self, $param, $value ) = @_;
  $self->{$param} = $value if defined $value;
  return $self->{$param} || '';
}

# Attribute accessors and mutators
sub AUTOLOAD {
  my $self = shift;
  my %attrs = $self->attributes;
  ( my $attr = $AUTOLOAD ) =~ s/.*://;
  return $self->__param( $attr => @_ ) if exists $attrs{$attr};
  die "Can't locate method '$attr' in package ".ref($self);
}

# So AUTOLOAD doesn't intercept calls to this method
sub DESTROY { }

# FIXME: Should probably be using File::Slurp...
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

  $html = "<html>$html</html>" if $self->wrap_in_html;

  # Slurp file so parsed HTML is exactly what was in the source file,
  # including whitespace, etc. This avoids HTML::Parser's parse_file
  # method, which reads and parses files incrementally, often not
  # resulting in the same *exact* parse tree (esp. whitespace).
  $html = $self->__slurp($file) if $file && $slurp;

  # Decode into Perl's internal form
  $html = decode( $self->encoding, $html );

  my $tree = new HTML::TreeBuilder();
  $tree->store_comments(1);
  $tree->p_strict(1);
  $tree->implicit_body_p_tag(1);
  $tree->ignore_unknown(0); # <ruby> et al

  # Parse the HTML string or file
  if( $html ) { $tree->parse($html); }
  else { $tree->parse_file($file); }

  # Preprocess, save tree and parsed HTML
  $self->__root( $tree );
  $self->__preprocess_tree();
  $self->parsed_html( $tree->as_HTML(undef, '  ') );

  # Convert and preprocess
  my $output = $self->__wikify($tree);
  $self->__postprocess_output(\$output);

  # Avoid leaks
  $tree->delete();

  # Return to original encoding
  $output = encode( $self->encoding, $output );

  return $output;
}

sub __wikify {
  my( $self, $node ) = @_;

  # Concatenate adjacent text nodes
  $node->normalize_content();

  if( $node->tag eq '~text' ) {
    return $node->attr('text');
  } elsif( $node->tag eq '~comment' ) {
    return '<!--' . $node->attr('text') . '-->';
  } else {
    my $rules = $self->__rules->{$node->tag};
    $rules = $self->__rules->{$rules->{alias}} if $rules->{alias};

    return $self->__subst($rules->{replace}, $node, $rules) if exists $rules->{replace};

    # Set private preserve rules
    if( $rules->{preserve} ) {
      $rules->{__start} = \&__preserve_start,
      $rules->{__end} = $rules->{empty} ? undef : '</'.$node->tag.'>';
    }

    my $output = $self->get_elem_contents($node);

    # Unspecified tags have their whitespace preserved (this allows
    # 'html' and 'body' tags [among others] to keep formatting when
    # inner tags like 'pre' need to preserve whitespace).
    my $trim = exists $rules->{trim} ? $rules->{trim} : 'none';
    $output =~ s/^\s+// if $trim eq 'both' or $trim eq 'leading';
    $output =~ s/\s+$// if $trim eq 'both' or $trim eq 'trailing';

    my $lf = $rules->{line_format} || 'none';
    $output =~ s/^\s*\n/\n/gm  if $lf ne 'none';
    if( $lf eq 'blocks' ) {
      $output =~ s/\n{3,}/\n\n/g;
    } elsif( $lf eq 'multi' ) {
      $output =~ s/\n{2,}/\n/g;
    } elsif( $lf eq 'single' ) {
      $output =~ s/\n+/ /g;
    } elsif( $lf eq 'none' ) {
      # Do nothing
    }

    # Substitutions
    $output =~ s/^/$self->__subst($rules->{line_prefix}, $node, $rules)/gem if $rules->{line_prefix};
    $output = $self->__subst($rules->{__start}, $node, $rules).$output if $rules->{__start};
    $output = $output.$self->__subst($rules->{__end}, $node, $rules) if $rules->{__end};
    $output = $self->__subst($rules->{start}, $node, $rules).$output if $rules->{start};
    $output = $output.$self->__subst($rules->{end}, $node, $rules) if $rules->{end};
    
    # Nested block elements are not blocked
    $output = "\n\n$output\n\n" if $rules->{block} && ! $node->parent->look_up( _tag => $node->tag );
    
    return $output;
  }
}

sub __subst {
  my( $self, $subst, $node, $rules ) = @_;
  return ref $subst eq 'CODE' ? $subst->( $self, $node, $rules ) : $subst;
}

sub __preserve_start {
  my( $self, $node, $rules ) = @_;

  my $tag = $node->tag;
  my @attrs = exists $rules->{attributes} ? @{$rules->{attributes}} : ( );
  my $attr_str = $self->get_attr_str( $node, @attrs );
  my $slash = $rules->{empty} ? ' /' : '';

  return '<'.$tag.' '.$attr_str.$slash.'>' if $attr_str;
  return '<'.$tag.$slash.'>';
}

# Maps tag name to its URI attribute
my %rel2abs = ( a => 'href', img => 'src' );

sub __preprocess_tree {
  my $self = shift;

  $self->__root->objectify_text();

  foreach my $node ( $self->__root->descendents ) {
    $node->tag('') unless $node->tag;
    $self->__rm_node($node), next if $node->tag eq '~comment' and $self->strip_comments;
    $self->__rm_node($node), next if $node->tag eq 'script' and $self->strip_scripts;
    $self->__rm_node($node), next if $node->tag eq 'head' and $self->strip_head;
    $self->__rm_invalid_text($node);
    $self->__encode_entities($node) if $node->tag eq '~text';
    $self->__rel2abs($node) if $self->base_uri and $rel2abs{$node->tag};
    $self->preprocess_node($node);
  }

  # Reobjectify in case preprocessing added new text
  $self->__root->objectify_text();
}

sub __rm_node { pop->replace_with('')->delete() }

# Encodes high-bit and control chars in node's text to HTML entities.
sub __encode_entities {
  my( $self, $node ) = @_;
  my $text = $node->attr('text') || '';
  encode_entities( $text, '<>&' );
  $node->attr( text => $text );
}

# Convert relative to absolute URIs
sub __rel2abs {
  my( $self, $node ) = @_;
  my $attr = $rel2abs{$node->tag};
  return unless $node->attr($attr); # don't add attribute if it's not already there
  $node->attr( $attr => URI->new($node->attr($attr))->abs($self->base_uri)->as_string );
}

# Removes text nodes directly inside container elements.
my %containers = map { $_ => 1 } qw/ table tbody tr ul ol dl menu /;

sub __rm_invalid_text {
  my( $self, $node ) = @_;
  my $tag = $node->tag || '';
  if( $containers{$tag} ) {
    $self->__rm_node($_) for grep $_->tag eq '~text', $node->content_list;
  }
}

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

sub preprocess_node { }

sub __postprocess_output {
  my( $self, $outref ) = @_;
  $$outref =~ s/\n[\s^\n]+\n/\n\n/g; # XXX this is causing bug 14527
  $$outref =~ s/\n{2,}/\n\n/g;
  $$outref =~ s/^\n+//;
  $$outref =~ s/\s+$//;
  $$outref =~ s/[ \t]+$//gm;
  $self->postprocess_output($outref);
}

sub postprocess_output { }

my %meta_rules = (
  trim        => { range => [ qw/ none both leading trailing / ] },
  line_format => { range => [ qw/ none single multi blocks / ] },
  replace     => { singleton => 1 },
  alias       => { singleton => 1 },
  attributes  => { depends => [ qw/ preserve / ] },
  empty       => { depends => [ qw/ preserve / ] }
);

sub __check_rules {
  my $self = shift;

  foreach my $tag ( keys %{ $self->__rules } ) {
    my $rules = $self->__rules->{$tag};

    foreach my $opt ( keys %$rules ) {
      my $spec = $meta_rules{$opt} or next;

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

sub __rule_error {
  my( $self, $tag, @msg ) = @_;
  my $dialect = ref $self;
  die @msg, " in tag '$tag', dialect '$dialect'.\n";
}

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

  DokuWiki
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
  $wiki = $wc->html2wiki( file => $file );
  $wiki = $wc->html2wiki( file => $file, slurp => $slurp );

Converts HTML source to wiki markup for the current dialect. Accepts
either an HTML string C<$html> or an HTML file C<$file> to read from.

You may optionally bypass C<HTML::Parser>'s incremental parsing of
HTML files (thus I<slurping> the file in all at once) by giving C<$slurp>
a true value.

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
C<html2wiki>. Boolean, disabled by default.

=item strip_comments

Removes HTML comments from the input before conversion to wiki markup.
Boolean, enabled by default.

=item strip_head

Removes the HTML C<head> element from the input before
converting. Boolean, enabled by default.

=item strip_scripts

Removes all HTML C<script> elements from the input before
converting. Boolean, enabled by default.

=back

Some dialects allow other parameters in addition to these. Consult
individual dialect documentation for details.

=head1 DIALECTS

C<HTML::WikiConverter> can convert HTML into markup for a variety of
wiki dialects. The rules for converting HTML into a given dialect are
specified in a dialect module registered in the
C<HTML::WikiConverter::> namespace. For example, the rules for the
MediaWiki dialect are provided in C<HTML::WikiConverter::MediaWiki>,
while PhpWiki's rules are specified in
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
dialect that uses C<*asterisks*> for bold and C<_underscores_> for italic
text:

  sub rules {
    return {
      b => { start => '*', end => '*' },
      i => { start => '_', end => '_' }
    };
  }

=head3 Aliases

To add C<E<lt>strongE<gt>> and C<E<lt>emE<gt>> as aliases of C<E<lt>bE<gt>> and
C<E<lt>iE<gt>>, use the C<alias> rule:

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

Many dialects separate paragraphs and other block-level elements
with a blank line. To indicate this, use the C<block> rule:

  p => { block => 1 }

To better support nested block elements, if a block elements are
nested inside each other, blank lines are only added to the outermost
element.

=head3 Line formatting

Many dialects require that the text of a paragraph be contained on a
single line of text. Or perhaps that a paragraph cannot contain any
newlines. These options can be specified using the C<line_format>
rule, which can be assigned the value C<"single">, C<"multi">, or
C<"blocks">.

If the element must be contained on a single line, then the
C<line_format> rule should be C<"single">. If the element can span
multiple lines, but there can be no blank lines contained within, then
it should be C<"multi">. If blank lines (which delimit blocks) are
allowed, then use C<"blocks">. For example, paragraphs are specified
like so in the MediaWiki dialect:

  p => { block => 1, line_format => 'multi', trim => 'both' }

=head3 Trimming whitespace

The C<trim> rule specifies whether leading or trailing whitespace (or
both) should be stripped from the element. To strip leading whitespace
only, use C<"leading">; for trailing whitespace, use C<"trailing">;
for both, use the aptly named C<"both">; for neither (the default),
use C<"none">.

=head3 Line prefixes

Some elements require that each line be prefixed with a particular
string. For example, preformatted text in MediaWiki s prefixed with a
space:

  pre => { block => 1, line_prefix => ' ' }

=head3 Replacement

In some cases, conversion from HTML to wiki markup is as simple as
string replacement. To replace a tag and its contents with a
particular string, use the C<replace> rule. For example, in PhpWiki,
three percent signs '%%%' represents a linebreak C<E<lt>br /E<gt>>,
hence the rule:

  br => { replace => '%%%' }

(The C<replace> rule cannot be used with any other rule.)

=head3 Preserving HTML tags

Some dialects allow a subset of HTML in their markup. HTML tags can be
preserved using the C<preserve> rule. For example, to allow
C<E<lt>fontE<gt>> tag in wiki markup:

  font => { preserve => 1 }

Preserved tags may also specify a list of attributes that may also
passthrough from HTML to wiki markup. This is done with the
C<attributes> option:

  font => { preserve => 1, attributes => [ qw/ font size / ] }

(The C<attributes> rule must be used alongside the C<preserve> rule.)

Some HTML elements have no content (e.g. line breaks, images), and
should be preserved specially. To indicate that a preserved tag should
have no content, use the C<empty> rule. This will cause the element to
be replaced with C<"E<lt>tag /E<gt>">, with no end tag. For example,
MediaWiki handles line breaks like so:

  br => {
    preserve => 1,
    attributes => qw/ id class title style clear /,
    empty => 1
  }

This will convert, e.g., C<"E<lt>br clear='both'E<gt>"> into
C<"E<lt>br clear='both' /E<gt>">. Without specifying the C<empty>
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

For example, MoinMoin handles lists like so:

  ul => { line_format => 'multi', block => 1, line_prefix => '  ' }
  li => { start => \&_li_start, trim => 'leading' }
  ol => { alias => 'ul' }

And then defines C<_li_start>:

  sub _li_start {
    my( $self, $rules ) = @_;
    my $bullet = '';
    $bullet = '*'  if $node->parent->tag eq 'ul';
    $bullet = '1.' if $node->parent->tag eq 'ol';
    return "\n$bullet ";
  }

This ensures that every unordered list item is prefixed with C<*> and
every ordered list item is prefixed with C<1.>, required by the
MoinMoin formatting rules. It also ensures that each list item is on a
separate line and that there is a space between the prefix and the
content of the list item.

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

Attributes defined liks this are given accessor and mutator methods via
Perl's AUTOLOAD mechanism, so you can later say:

  my $ok = $wc->camel_case; # accessor
  $wc->camel_case(0); # mutator

=head2 Preprocessing

The first step in converting HTML source to wiki markup is to parse
the HTML into a syntax tree using L<HTML::TreeBuilder>. It is often
useful for dialects to preprocess the tree prior to converting it into
wiki markup. Dialects that need to preprocess the tree define a
C<preprocess_node> method that will be called on each node of the tree
(traversal is done in pre-order). As its only argument the method
receives the current L<HTML::Element> node being traversed. It may
modify the node or decide to ignore it. The return value of the
C<preprocess_node> method is discarded.

=head3 Built-in preprocessors

Because they are commonly needed, two preprocessing steps are
automatically carried out by C<HTML::WikiConverter>, regardless of the
dialect: 1) relative URIs in images and links are converted to
absolute URIs (based upon the C<base_uri> parameter), and 2) ignorable
text (e.g. between C<E<lt>/tdE<gt>> and C<E<lt>tdE<gt>>) is discarded.

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

Dialects may apply these optional preprocessing steps by calling them
as methods on the dialect object inside C<preprocess_node>. For
example:

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

Converts the contents of C<$node> into wiki markup and returns the
resulting wiki markup.

=item get_wiki_page

  my $title = $wc->get_wiki_page( $url );

Attempts to extract the title of a wiki page from the given URL,
returning the title on success, C<undef> on failure. If C<wiki_uri> is
empty, this method always return C<undef>. Assumes that URLs to wiki
pages are constructed using "I<E<lt>wiki-uriE<gt>E<lt>page-nameE<gt>>".

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

and C<@attrs> contains C<"id"> and C<"class">, then C<get_attr_str> will
return C<'id="ht" class="head"'>.

=back

=head1 BUGS

Please report bugs using http://rt.cpan.org.

=head1 SEE ALSO

L<HTML::Tree>, L<HTML::Element>

=head1 AUTHOR

David J. Iberri <diberri@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2004-2005 David J. Iberri

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
