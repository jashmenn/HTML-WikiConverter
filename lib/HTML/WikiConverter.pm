package HTML::WikiConverter;
use warnings;
use strict;

use Params::Validate ':all';
use HTML::TreeBuilder;
use HTML::Entities;
use HTML::Tagset;
use File::Spec;
use DirHandle;
use Encode;

use URI::Escape;
use URI;

our $VERSION = '0.54';
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
  PbWiki
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
your system. Additional attributes may be specified in C<%attrs>; see
L</"ATTRIBUTES"> for a list of recognized attributes.

=cut

sub new {
  my $pkg = shift;
  return $pkg->__new_dialect(@_) if $pkg eq __PACKAGE__;

  my $self = bless { }, $pkg;
  $self->__load_attribute_specs();
  $self->__setup(@_);
  return $self;
}

sub __new_dialect {
  my( $pkg, %opts ) = @_;
  die "Required 'dialect' parameter is missing" unless $opts{dialect};
  my @dialect_classes = ( __PACKAGE__.'::'.$opts{dialect}, $opts{dialect} );
  foreach my $dialect_class ( @dialect_classes ) {
    return $dialect_class->new( %opts ) if eval "use $dialect_class; 1" or $dialect_class->isa($pkg);
  }
  die "Dialect '$opts{dialect}' could not be loaded (tried @dialect_classes). Error: $@";
}

sub __setup {
  my $self = shift;
  $self->__attrs( {} );
  $self->__validate_attributes(@_);
  $self->__load_rules();
  $self->__validate_rules();
}

sub __original_attrs { shift->_attr( { internal => 1 }, __original_attrs => @_ ) }
sub __attrs { shift->_attr( { internal => 1 }, __attrs => @_ ) }
sub __root { shift->_attr( { internal => 1 }, __root => @_ ) }
sub __rules { shift->_attr( { internal => 1 }, __rules => @_ ) }
sub __attribute_specs { shift->_attr( { internal => 1 }, __attribute_specs => @_ ) }

# Pass '{internal=>1}' as first arg for params that aren't attributes
sub _attr {
  my( $self, $opts, $param, @value ) = ref $_[1] eq 'HASH' ? @_ : ( +shift, {}, @_ );
  my $store = $opts->{internal} ? $self : $self->__attrs;
  $store->{$param} = $value[0] if @value;
  return defined $store->{$param} ? $store->{$param} : '';
}

# Attribute accessors and mutators
sub AUTOLOAD {
  my $self = shift;
  ( my $attr = $AUTOLOAD ) =~ s/.*://;
  return $self->_attr( $attr => @_ ) if exists $self->__attribute_specs->{$attr};
  die "Can't locate method '$attr' in package ".ref($self);
}

# So AUTOLOAD doesn't intercept calls to this method
sub DESTROY { }

sub __slurp {
  my( $self, $file ) = @_;
  eval "use File::Slurp;";
  return $self->__simple_slurp($file) if $@;
  return scalar File::Slurp::read_file($file);
}

sub __simple_slurp {
  my( $self, $file ) = @_;
  open my $fh, $file or die "can't open file $file for reading: $!";
  my $text = do { local $/; <$fh> };
  close $fh;
  return $text;
}

=head2 html2wiki

  $wiki = $wc->html2wiki( $html, %attrs );
  $wiki = $wc->html2wiki( html => $html, %attrs );
  $wiki = $wc->html2wiki( file => $file, %attrs );

Converts HTML source to wiki markup for the current dialect. Accepts
either an HTML string C<$html> or an HTML file C<$file> to read from.

Attributes assigned in C<%attrs> (see L</"ATTRIBUTES">) will override
previously assigned attributes for the duration of the C<html2wiki()>
call.

=cut

sub html2wiki {
  my $self = shift;

  my %args = @_ % 2 ? ( html => +shift, @_ ) : @_;
  die "missing 'html' or 'file' argument to html2wiki" unless exists $args{html} or $args{file};
  die "cannot specify both 'html' and 'file' arguments to html2wiki" if exists $args{html} and exists $args{file};
  my $html = delete $args{html} || '';
  my $file = delete $args{file} || '';

  $self->__original_attrs( $self->__attrs );
  $self->__attrs( { %{ $self->__attrs }, %args } );

  $html = $self->__slurp($file) if $file && $self->slurp;
  $html = "<html>$html</html>" if $html and $self->wrap_in_html;

  # Decode into Perl's internal form
  $html = decode( $self->encoding, $html );

  my $tree = new HTML::TreeBuilder();
  $tree->store_comments(1);
  $tree->p_strict(1);
  $tree->implicit_body_p_tag(1);
  $tree->ignore_unknown(0); # <ruby> et al

  # Parse the HTML string or file
  if( $html ) {
    $tree->parse($html);
    $tree->eof();
  } else {
    $tree->parse_file($file);
  }

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
  
  $self->__attrs( { %{ $self->__original_attrs } } );

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

# Maps a tag name to its URI attribute
my %rel2abs = ( a => 'href', img => 'src' );

my %emptyTag = ( %HTML::Tagset::emptyElement, '~comment' => 1, '~text' => 1 );

sub __preprocess_tree {
  my $self = shift;

  $self->__root->objectify_text();

  my %strip_tag = map { $_ => 1 } @{ $self->strip_tags || [] };

  foreach my $node ( $self->__root->descendents ) {
    $node->tag('') unless $node->tag;
    $node->delete, next if $strip_tag{$node->tag};
    $node->delete, next if $self->remove_empty and !$emptyTag{$node->tag} and !$node->content_list;
    $self->__rm_invalid_text($node);
    $self->__encode_entities($node) if $node->tag eq '~text';
    $self->__rel2abs($node) if $self->base_uri and $rel2abs{$node->tag};
    $self->preprocess_node($node);
  }

  # Reobjectify in case preprocessing added new text
  $self->__root->objectify_text();

  $self->preprocess->( $self->__root ) if ref $self->preprocess;
}

# Encodes high-bit and control chars in node's text to HTML entities.
sub __encode_entities {
  my( $self, $node ) = @_;
  my $text = defined $node->attr('text') ? $node->attr('text') : '';
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
  my $tag = defined $node->tag ? $node->tag : '';
  if( $containers{$tag} ) {
    $_->delete for grep { $_->tag eq '~text' } $node->content_list;
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

sub __default_attribute_specs { {
  slurp        => { type => BOOLEAN,  default => 0 },
  remove_empty => { type => BOOLEAN,  default => 0 },
  preprocess   => { type => CODEREF,  default => undef },
  strip_tags   => { type => ARRAYREF, default => [ qw/ ~comment head script style / ] },
  encoding     => { type => SCALAR,   default => 'utf-8' },
  wrap_in_html => { type => BOOLEAN,  default => 1 },
  wiki_uri     => { type => SCALAR | ARRAYREF, default => undef },
  base_uri     => { type => SCALAR,   default => undef },
  dialect      => { type => SCALAR,   optional => 0 },
} }

sub attributes { {} }

sub __load_attribute_specs {
  my $self = shift;

  # Get default attribute specs
  my $default_specs = $self->__default_attribute_specs;

  # Get dialect attribute specs
  my @dialect_specs = $self->attributes;
  my $dialect_specs = @dialect_specs == 1 && ref $dialect_specs[0] eq 'HASH' ? $dialect_specs[0] : {@dialect_specs};

  my %attr_specs = %$default_specs;
  while( my( $attr, $spec ) = each %$dialect_specs ) {
    $attr_specs{$attr} = $spec;
  }

  $self->__attribute_specs( \%attr_specs );
}

sub __validate_attributes {
  my $self = shift;

  my %attrs = validate( @_, $self->__attribute_specs );
  while( my( $attr, $value ) = each %attrs ) {
    $self->$attr($value);
  }
}

sub rules { {} }

sub __load_rules {
  my $self = shift;
  $self->__rules( $self->rules );
}

my %meta_rules = (
  trim        => { range => [ qw/ none both leading trailing / ] },
  line_format => { range => [ qw/ none single multi blocks / ] },
  replace     => { singleton => 1 },
  alias       => { singleton => 1 },
  attributes  => { depends => [ qw/ preserve / ] },
  empty       => { depends => [ qw/ preserve / ] },
);

sub __validate_rules {
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

      $self->__rule_error( $tag, "Unknown '$opt' value '$rules->{$opt}'. '$opt' must be one of ", join(', ', map { "'$_'" } @range) )
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
  my $str =  join '', map { $self->__wikify($_) } $node->content_list;
  return defined $str ? $str : '';
}

sub get_wiki_page {
  my( $self, $url ) = @_;
  my @wiki_uris = ref $self->wiki_uri eq 'ARRAY' ? @{$self->wiki_uri} : $self->wiki_uri;
  foreach my $wiki_uri ( @wiki_uris ) {
    my $page = $self->__extract_wiki_page( $url => $wiki_uri );
    return $page if $page;
  }

  return undef;
}

sub __extract_wiki_page {
  my( $self, $url, $wiki_uri ) = @_;
  return undef unless $wiki_uri;

  if( ref $wiki_uri eq 'Regexp' ) {
    return $url =~ $wiki_uri ? $1 : undef;
  } elsif( ref $wiki_uri eq 'CODE' ) {
    return $wiki_uri->( $self, $url );
  } else {
    return undef unless index( $url, $wiki_uri ) == 0;
    return undef unless length $url > length $wiki_uri;
    return substr( $url, length $wiki_uri );
  }
}

# Adapted from Kwiki source
my $UPPER    = '\p{UppercaseLetter}';
my $LOWER    = '\p{LowercaseLetter}';
my $WIKIWORD = "$UPPER$LOWER\\p{Number}\\p{ConnectorPunctuation}";

sub is_camel_case { return $_[1] =~ /(?:[$UPPER](?=[$WIKIWORD]*[$UPPER])(?=[$WIKIWORD]*[$LOWER])[$WIKIWORD]+)/ }

sub get_attr_str {
  my( $self, $node, @attrs ) = @_;
  my %attrs = map { $_ => $node->attr($_) } @attrs;
  my $str = join ' ', map { $_.'="'.encode_entities($attrs{$_}).'"' } grep { $attrs{$_} } @attrs;

  # (bug #19046) partial fix: attributes must be contained on a single line
  $str =~ s/[\n\r]/ /g if $str;

  return defined $str ? $str : '';
}

=head2 parsed_html

  my $html = $wc->parsed_html;

Returns L<HTML::TreeBuilder>'s string representation of the
last-parsed syntax tree, showing how the input HTML was parsed
internally. Useful for debugging.

=cut

sub parsed_html { shift->_attr( { internal => 1 }, __parsed_html => @_ ) }

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
constructor, or can be called as object methods on an H::WC object.

Some dialects allow other attributes in addition to those below, and
may override the attributes' default values. Consult the dialect's
documentation for details.

=head2 dialect

(Required) Dialect to use for converting HTML into wiki markup. See
the L</"DESCRIPTION"> section above for a list of dialects. C<new()>
will fail if the dialect given is not installed on your system. Use
C<available_dialects()> to list installed dialects.

=head2 base_uri

URI to use for converting relative URIs to absolute ones. This
effectively ensures that the C<src> and C<href> attributes of image
and anchor tags, respectively, are absolute before converting the HTML
to wiki markup, which is necessary for wiki dialects that handle
internal and external links separately. Relative URLs are only
converted to absolute ones if the C<base_uri> argument is
present. Defaults to C<undef>.

=head2 wiki_uri

Takes a URI, regular expression, or coderef (or a reference to an
array of elements of these types) used to determine which links are to
wiki pages: a link whose C<href> parameter matches C<wiki_uri> will be
treated as a link to a wiki page. In addition, C<wiki_uri> will be
used to extract the title of the wiki page. The way this is done
depends on whether the C<wiki_uri> has been set to a string, regexp,
or coderef. The default is C<undef>, meaning that all links will be
treated as external links by default.

If C<wiki_uri> is a string, it is assumed that URIs to wiki pages are
created by joining the C<wiki_uri> with the wiki page title. For
example, the English Wikipedia might use
C<"http://en.wikipedia.org/wiki/"> as the value of C<wiki_uri>. Ward's
wiki might use C<"http://c2.com/cgi/wiki?">. 

C<wiki_uri> can also be a regexp that matches URIs to wiki pages and
also extracts the page title from them. For example, the English
Wikipedia might use
C<qr~http://en\.wikipedia\.org/w/index\.php\?title\=([^&]+)~>.

C<wiki_uri> can also be a coderef that takes the current
C<HTML::WikiConverter> object and a L<URI> object. It should return
the title of the wiki page extracted from the URI, or C<undef> if the
URI doesn't represent a link to a wiki page.

As mentioned above, the C<wiki_uri> attribute can either take a single
URI/regexp/coderef element or it may be assigned a reference to an
array of any number of these elements. This is useful for wikis that
have different ways of creating links to wiki pages. For example, the
English Wikipedia might use:

  my $wc = new HTML::WikiConverter(
    dialect => 'MediaWiki',
    wiki_uri => [
      'http://en.wikipiedia.org/wiki/',
      sub { pop->query_param('title') } # requires URI::QueryParam
    ]
  );

=head2 wrap_in_html

Helps L<HTML::TreeBuilder> parse HTML fragments by wrapping HTML in
C<E<lt>htmlE<gt>> and C<E<lt>/htmlE<gt>> before passing it through
C<html2wiki>. Boolean, enabled by default.

=head2 encoding

Specifies the encoding used by the HTML to be converted. Also
determines the encoding of the wiki markup returned by the
C<html2wiki> method. Defaults to C<'utf8'>.

=head2 strip_tags

A reference to an array of tags to be removed from the HTML input
prior to conversion to wiki markup. Tag names are the same as those
used in L<HTML::Element>. Defaults to C<[ '~comment', 'head',
'script', 'style' ]>.

=head2 preprocess

Code reference that gets invoked after HTML is parsed but before it is
converted into wiki markup. The callback is passed two arguments: the
C<HTML::WikiConverter> object and a L<HTML::Element> pointing to the
root node of the HTML tree created by L<HTML::TreeBuilder>.

=head2 remove_empty

Removes elements containing no content (unless those elements
legitimately contain no content, such as is the case for C<br> and
C<img> elements, for example). Defaults to false.

=head2 slurp

When parsing HTML files, bypasses C<HTML::Parser>'s incremental
parsing (thus I<slurping> the file in all at once). If L<File::Slurp>
is installed, its C<read_file()> function will be used to perform
slurping; otherwise, a common Perl idiom will be used for slurping
instead. This option has no effect if all you do is call
C<html2wiki()> with a single HTML string argument instead of a file.

=head1 ADDING A DIALECT

Consult L<HTML::WikiConverter::Dialects> for documentation on how to
write your own dialect module for C<HTML::WikiConverter>. Or if you're
not up to the task, drop me an email and I'll have a go at it when I
get a spare moment.

=head1 SEE ALSO

L<HTML::Tree>, L<Convert::Wiki>

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

My thanks also goes to Martin Kudlvasr for catching (and fixing!) a
bug in the logic of how HTML files were processed.

Big thanks to Dave Schaefer for the PbWiki dialect and for the idea
behind the new C<attributes()> implementation.

=head1 COPYRIGHT & LICENSE

Copyright 2006 David J. Iberri, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
