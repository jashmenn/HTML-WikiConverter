package HTML::WikiConverter;
use warnings;
use strict;

use URI;
use Encode;
use HTML::Entities;
use HTML::TreeBuilder;
use vars '$VERSION';
$VERSION = '0.41';
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
  WikkaWiki

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
C<html2wiki>. Boolean, enabled by default.

=item encoding

Specifies the encoding used by the HTML to be converted. Also
determines the encoding of the wiki markup returned by the
C<html2wiki> method. Defaults to C<'utf8'>.

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

Some dialects allow other attributes in addition to these. Consult
individual dialect documentation for details.

=head1 ADDING A DIALECT

Consult L<HTML::WikiConverter::Dialects> for documentation on how to
write your own dialect module for C<HTML::WikiConverter>. Or if you're
not up to the task, drop me an email and I'll have a go at it when I
get a spare moment.

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
