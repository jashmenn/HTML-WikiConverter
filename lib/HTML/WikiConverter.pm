package HTML::WikiConverter;
use warnings;
use strict;

use URI;
use Encode;
use DirHandle;
use File::Spec;
use HTML::Entities;
use HTML::TreeBuilder;
use URI::Escape;

our $VERSION = '0.51';
our $AUTOLOAD;

=head1 NAME

HTML::WikiConverter - Convert HTML to wiki markup

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
  WikkaWiki

Note that while dialects usually produce satisfactory wiki markup, not
all features of all dialects are supported. Consult individual
dialects' documentation for details of supported features. Suggestions
for improvements, especially in the form of patches, are very much
appreciated.

=head1 METHODS

=head2 new

  my $wc = new HTML::WikiConverter( dialect => $dialect, %attrs );

Returns a converter for the specified wiki dialect. Dies if
C<$dialect> is not provided or its dialect module is not installed on
your system. Attributes may be specified in C<%attrs>; see
L</"ATTRIBUTES"> for a list of recognized attributes.

=cut

sub new {
  my( $pkg, %opts ) = @_;

  if( $pkg eq __PACKAGE__ ) {
    die "Required 'dialect' parameter is missing" unless $opts{dialect};
    my $dc = __PACKAGE__.'::'.$opts{dialect};

    die "Dialect '$opts{dialect}' could not be loaded. Perhaps $dc isn't installed? Error: $@" unless eval "use $dc; 1" or $dc->isa($pkg);
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
  preprocess     => undef,  # Client callback to preprocess tree before converting
  wiki_page_extractor => undef, # Coderef to use for extracting wiki page titles from URIs
) }

sub __root { shift->__param( __root => @_ ) }
sub __rules { shift->__param( __rules => @_ ) }

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

=head2 html2wiki

  $wiki = $wc->html2wiki( $html );
  $wiki = $wc->html2wiki( html => $html );
  $wiki = $wc->html2wiki( file => $file );
  $wiki = $wc->html2wiki( file => $file, slurp => $slurp );

Converts HTML source to wiki markup for the current dialect. Accepts
either an HTML string C<$html> or an HTML file C<$file> to read from.

You may optionally bypass C<HTML::Parser>'s incremental parsing of
HTML files (thus I<slurping> the file in all at once) by giving C<$slurp>
a true value.

=cut

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
    
    # Nested block elements are not blocked...
    $output = "\n\n$output\n\n" if $rules->{block} && ! $node->parent->look_up( _tag => $node->tag );

    # ...but they are put on their own line
    $output = "\n$output" if $rules->{block} and $node->parent->look_up( _tag => $node->tag ) and $trim ne 'none';
    
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

  $self->preprocess->( $self->__root ) if ref $self->preprocess;
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
  $node->attr( $attr => uri_unescape( URI->new_abs( $node->attr($attr), $self->base_uri )->as_string ) );
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
  $$outref =~ s/\n[\s^\n]+\n/\n\n/g;
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
  return join '', map $self->__wikify($_), $node->content_list;
}

sub get_wiki_page {
  my( $self, $url ) = @_;
  my $page = $self->wiki_page_extractor->( $self, URI->new_abs( $url, $self->base_uri ) ) if $self->wiki_page_extractor;
  return $page if $page;
  return $self->_extract_wiki_page( $url );
}

sub _extract_wiki_page {
  my( $self, $url ) = @_;

  my @wiki_uris = ref $self->wiki_uri eq 'ARRAY' ? @{$self->wiki_uri} : $self->wiki_uri;
  foreach my $wiki_uri ( @wiki_uris ) {
    my $page = $self->__simply_extract_wiki_page( $url => $wiki_uri );
    return $page if $page;
  }

  return undef;
}

sub __simply_extract_wiki_page {
  my( $self, $url, $wiki_uri ) = @_;
  return undef unless $wiki_uri;
  return $1 if ref $wiki_uri eq 'Regexp' and $url =~ $wiki_uri;
  return undef unless index( $url, $wiki_uri ) == 0;
  return undef unless length $url > length $wiki_uri;
  return substr( $url, length $wiki_uri );
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

=head2 parsed_html

  my $html = $wc->parsed_html;

Returns L<HTML::TreeBuilder>'s string representation of the
last-parsed syntax tree, showing how the input HTML was parsed
internally. Useful for debugging.

=cut

sub parsed_html { shift->__param( __parsed_html => @_ ) }

=head2 available_dialects

  my @dialects = HTML::WikiConverter->available_dialects;

Returns a list of all available dialects by searching the directories
in C<@INC> for C<HTML::WikiConverter::> modules.

=cut

sub available_dialects {
  my @dialects;

  for my $inc ( @INC ) {
    my $dir = File::Spec->catfile( $inc, 'HTML', 'WikiConverter' );
    my $dh  = DirHandle->new( $dir ) or next;
    while ( my $f = $dh->read ) {
      next unless $f =~ /^(\w+)\.pm$/;
      push @dialects, $1;
    }
  }

  return wantarray ? sort @dialects : @dialects;
}

=head1 ATTRIBUTES

You may configure C<HTML::WikiConverter> using a number of
attributes. These may be passed as arguments to the C<new>
constructor, or can be called as object methods on a
C<HTML::WikiConverter> object.

Some dialects allow other attributes in addition to those
below. Consult individual dialect documentation for details.

=head2 dialect

(Required) Dialect to use for converting HTML into wiki markup. See
the L</"DESCRIPTION"> section above for a list of dialects. C<new>
will fail if the dialect given is not installed on your system.

=head2 base_uri

URI to use for converting relative URIs to absolute ones. This
effectively ensures that the C<src> and C<href> attributes of image
and anchor tags, respectively, are absolute before converting the HTML
to wiki markup, which is necessary for wiki dialects that handle
internal and external links separately. Relative URLs are only
converted to absolute ones if the C<base_uri> argument is
present. Defaults to C<undef>.

=head2 wiki_uri

URI or a reference to a list of URIs used in determining which links
are wiki links. This assumes that URLs to wiki pages are created by
joining the C<wiki_uri> with the (possibly escaped) wiki page
name. For example, the English Wikipedia might use

  my $wc = new HTML::WikiConverter(
    dialect => $dialect,
    wiki_uri => [
      'http://en.wikipedia.org/wiki/',
      'http://en.wikipedia.org/w/index.php?action=edit&title='
    ]
  );

Ward's wiki might use

  my $wc = new HTML::WikiConverter(
    dialect => $dialect,
    wiki_uri => 'http://c2.com/cgi/wiki?'
  );

The default is C<undef>, meaning that all links will be treated as
external links.

See also the C<wiki_page_extractor> method, which provides a more
flexible way of specifying how to extract page titles from URLs.

=head2 wiki_page_extractor

C<wiki_page_extractor> can be used instead of C<wiki_uri>, giving you
a more flexible way to extract page titles from URLs.

The attribute takes a coderef that extracts a wiki page title from the
given URL.  If C<undef> (the default), the built-in extractor (which
attempts to extract wiki page titles from URIs based on the value of
the C<wiki_uri> attribute) will be used instead.

The extractor subroutine will be passed two arguments, the current
L<HTML::WikiConverter> object and a L<URI> object. The return value
should be the title of the wiki page extracted from the URI given. If
no page title can be found or the URI does not refer to a wiki page,
then the extractor should return C<undef>, which will fallback to the
built-in extractor (which functions as mentioned previously).

=head2 wrap_in_html

Helps C<HTML::TreeBuilder> parse HTML fragments by wrapping HTML in
C<E<lt>htmlE<gt>> and C<E<lt>/htmlE<gt>> before passing it through
C<html2wiki>. Boolean, enabled by default.

=head2 encoding

Specifies the encoding used by the HTML to be converted. Also
determines the encoding of the wiki markup returned by the
C<html2wiki> method. Defaults to C<'utf8'>.

=head2 strip_comments

Removes HTML comments from the input before conversion to wiki markup.
Boolean, enabled by default.

=head2 strip_head

Removes the HTML C<head> element from the input before
converting. Boolean, enabled by default.

=head2 strip_scripts

Removes all HTML C<script> elements from the input before
converting. Boolean, enabled by default.

=head1 ADDING A DIALECT

Consult L<HTML::WikiConverter::Dialects> for documentation on how to
write your own dialect module for C<HTML::WikiConverter>. Or if you're
not up to the task, drop me an email and I'll have a go at it when I
get a spare moment.

=head1 SEE ALSO

L<HTML::TreeBuilder>, L<HTML::Element>

=head1 AUTHOR

David J. Iberri, C<< <diberri@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-html-wikiconverter at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=HTML-WikiConverter>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc HTML::WikiConverter

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/HTML-WikiConverter>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/HTML-WikiConverter>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=HTML-WikiConverter>

=item * Search CPAN

L<http://search.cpan.org/dist/HTML-WikiConverter>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Tatsuhiko Miyagawa for suggesting
L<Bundle::HTMLWikiConverter> as well as providing code for the
C<available_dialects()> class method.

=head1 COPYRIGHT & LICENSE

Copyright 2006 David J. Iberri, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
