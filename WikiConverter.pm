package HTML::WikiConverter;
use warnings;
use strict;

use URI;
use HTML::TreeBuilder;
use vars '$VERSION';
$VERSION = '0.20';

=head1 NAME

HTML::WikiConverter - An HTML to wiki markup converter

=head1 SYNOPSIS

  use HTML::WikiConverter;
  my $wc = new HTML::WikiConverter( dialect => 'MediaWiki' );
  print $wc->html2wiki($html);

=head1 DESCRIPTION

HTML::WikiConverter is an HTML to wiki converter. It can convert HTML source
into a variety of wiki markups, called wiki "dialects".

=head1 METHODS

=over

=item $wc = new HTML::WikiConverter( dialect => '...', [ %opts ] );

Returns a converter for the specified dialect. If 'dialect' is not
provided or is not installed on your system, this method
dies. Additional options are specified in %opts, and include:

  base_uri
    the URI to use for converting relative URIs to absolute ones

=cut

my %defaults = (
  dialect => undef,   # (Required) Which wiki dialect to use
  base_uri => '',     # Base URI for relative links
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

=pod

=item $base_uri = $wc->base_uri( [ $new_base_uri ] );

Gets or sets the 'base_uri' option used for converting relative to
absolute URIs.

=cut

sub base_uri {
  my( $self, $base_uri ) = @_;
  $self->{base_uri} = $base_uri if $base_uri;
  return $self->{base_uri};
}

=pod

=item $wiki = $wc->html2wiki( $html );

Converts the HTML source into wiki markup for the current dialect.

=cut

sub html2wiki {
  my( $self, $html ) = @_;

  my $tree = new HTML::TreeBuilder();
  $tree->p_strict(1);
  $tree->implicit_body_p_tag(1);

  $tree->parse($html);
  $self->_preprocess_tree($tree);

  $self->{root} = $tree;
  $self->{parsed_html} = $tree->as_HTML( undef, '  ' );

  # Convert HTML to wiki markup
  my $output = $self->_wikify($tree);
  
  # Clean up newlines
  $output =~ s/\n[\s^\n]+\n/\n\n/gm;
  $output =~ s/\n{2,}/\n\n/gm;
  $output =~ s/^\s+//s;
  $output =~ s/\s+$//s;
  
  $tree->delete();
  return $output;
}

=pod

=item $html = $wc->parsed_html;

Returns the HTML representative of the last-parsed syntax tree. Use
this to see how your input HTML was parsed internally, which is useful
for debugging.

=cut

sub parsed_html { return shift->{parsed_html} }

#
# Internal methods
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
    return $self->_subst($rules->{replace}, $node, $rules) if $rules->{replace};

    # Get element's content
    my $output = $self->elem_contents($node);

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

sub _preserve_start {
  my( $self, $node, $rules ) = @_;
  my @attrs = exists $rules->{attributes} ? @{$rules->{attributes}} : ( );
  @attrs = map {
    my $attr = $node->attr($_);
    "$_=\"$attr\"";
  } grep { $node->attr($_) } @attrs;

  my $tag = $node->tag;
  my $attr_str = @attrs ? ' '.join(' ',@attrs) : '';
  return "<$tag$attr_str>";
}

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
    $self->_rel2abs_uri($node) if $self->{base_uri} and $abs2rel{$tag};
    $self->_rm_whitespace($node);
    $dc->preprocess_node( $self, $node ) if $dc_pn;
  }

  # Must objectify text again in case preprocessing happened to add
  # any new text nodes
  $root->objectify_text();
}

# Convert relative to absolute URIs
sub _rel2abs_uri {
  my( $self, $node ) = @_;
  my $attr = $abs2rel{$node->tag};
  return unless $node->attr($attr); # don't add attribute if it's not already there
  $node->attr( $attr => URI->new($node->attr($attr))->abs($self->base_uri)->as_string );
}

my %containers = map { $_ => 1 } qw/ table tr tbody ul ol dl menu /;

sub _rm_whitespace {
  my( $self, $node ) = @_;
  my $tag = $node->tag || '';
  if( $containers{$tag} ) {
    foreach my $child ( grep { $_->tag eq '~text' } $node->content_list ) {
      $child->replace_with('')->delete();
    }
  }
}

my %rule_spec = (
  trim       => { disallow => [ qw/ trim_leading trim_trailing / ] },
  replace    => { singleton => 1 },
  alias      => { singleton => 1 },
  preserve   => { disallow => [ qw/ start end / ] },
  attributes => { require  => [ qw/ preserve / ] },
);

sub _check_rules {
  my( $dialect, $ruleset ) = @_;

  foreach my $tag ( keys %$ruleset ) {
    my $rules = $ruleset->{$tag};

    foreach my $opt ( keys %$rules ) {
      my $spec = $rule_spec{$opt} or next;

      my $singleton = $spec->{singleton} || 0;
      my @disallow = ref $spec->{disallow} eq 'ARRAY' ? @{ $spec->{disallow} } : ( );
      my @require = ref $spec->{require} eq 'ARRAY' ? @{ $spec->{require} } : ( );

      die "$opt' cannot be combined with any other option in tag '$tag', dialect '$dialect'."
        if $singleton and keys %$rules != 1;

      exists $rules->{$_} && die "'$opt' cannot be combined with '$_' in tag '$tag', dialect '$dialect'."
        foreach @disallow;

      ! exists $rules->{$_} && die "'$opt' must be combined with '$_' in tag '$tag', dialect '$dialect'."
        foreach @require;
    }
  }
}

=pod

=back

=head1 UTILITY METHODS

=over

=item $wiki = $wc->elem_contents( $node )

Converts the contents of $node into wiki markup.

=cut

sub elem_contents {
  my( $self, $node ) = @_;
  my $output = '';
  $output .= $self->_wikify($_) for $node->content_list;
  return $output;
}

=pod

=back

=head1 DIALECTS

HTML::WikiConverter can convert HTML into markup for a variety of wiki
engines. The markup used by a particular engine is called a wiki
markup dialect. Support is added for dialects by installing dialect
modules which provide the rules for how HTML is converted into that
dialect's wiki markup.

Dialect modules are registered in the C<HTML::WikiConverter::>
namespace an are usually given names in CamelCase. For example, the
rules for the MediaWiki dialect are provided in
C<HTML::WikiConverter::MediaWiki>. And PhpWiki is specified in
C<HTML::WikiConverter::PhpWiki>.

head2 Supported dialects

  MediaWiki
  MoinMoin
  PhpWiki
  Kwiki

=head2 Rules

To interface with HTML::WikiConverter, dialect modules must define a
single C<rules()> class method. It returns a reference to a hash of
rules that specify how individual HTML elements are converted to wiki
markup. For example, the following C<rules()> method could be used for
a wiki dialect that used *asterisks* for bold and _underscores_ for
italic text:

  sub rules {
    return {
      b => { start => '*', end => '*' },
      i => { start => '_', end => '_' }
    };
  }

It is sometimes to define tags as aliases, for example to treat
E<lt>strongE<gt> and E<lt>bE<gt> the same. For that, use the 'alias'
keyword:

  sub rules {
    return {
      b => { start => '*', end => '*' },
      i => { start => '_', end => '_' },

      strong => { alias => 'b' },
      em => { alias => 'i' }
    };
  }

(Note that if you specify the 'alias' option, no other options are
allowed.)

Many wiki dialects separate paragraphs and other block-level elements
with a blank line. To indicate this, use the 'block' keyword:

  p => { block => 1 }

However, many such wiki engines require that the text of a paragraph
be contained on a single line of text. Or that a paragraph cannot
contain any blank lines. These formatting options can be specified
using the 'line_format' keyword, which can be assigned the value
'single', 'multi', or 'blocks'.

If the element must be contained on a single line, then the 'line_format'
option should be 'single'. If the element can span multiple lines, but there
can be no blank lines contained within, then it should be 'multi'. If blank
lines (which delimit blocks) are allowed, then it should be 'blocks'. For
example, paragraphs are specified like so in the MediaWiki dialect:

  p => { block => 1, line_format => 'multi', trim => 1 }

The 'trim' option indicates that leading and trailing whitespace
should be stripped from the paragraph before other rules are
processed. You can use 'trim_leading' and 'trim_trailing' if you only
want whitespace trimmed from one end of the content.

Some multi-line elements require that each line of output be prefixed with
a particular string. For example, preformatted text in the MediaWiki
dialect is prefixed with one or more spaces. This is specified using the
'line_prefix' option:

  pre => { block => 1, line_prefix => ' ' }

In some cases, conversion from HTML to wiki markup is as simple as
replacing an element with a particular string. This is done with the
'replace' option.  For example, in the PhpWiki dialect, three percent
signs '%%%' represents a linebreak E<lt>brE<gt>:

  br => { replace => '%%%' }

(Note that if you specify the 'replace' option, no other options are
allowed.)

Finally, many (if not all) wiki dialects allow a subset of HTML in
their markup, such as for superscripts, subscripts, and text
centering.  HTML tags may be preserved using the 'preserve'
option. For example, to allow the E<lt>fontE<gt> tag in wiki markup,
one might say:

  font => { preserve => 1 }

Preserved tags may also specify a whitelist of attributes that may
also passthrough from HTML to wiki markup. This is done with the
'attributes' option:

  font => { preserve => 1, attributes => [ qw/ font size / ] )

=head3 Dynamic rules

Instead of simple strings, you may use coderefs as option values for
the 'start', 'end', 'replace', and 'line_prefix' rules. If you do, the
code will be called with three arguments: 1) the current
HTML::WikiConverter instance, 2) the current HTML::Element node, and
3) the rules for that node (as a hashref).

Specifying rules dynamically is often useful for handling nested
elements.

=head2 Preprocessing

The first step in converting HTML source to wiki markup is to parse
the HTML into a syntax tree using C<HTML::TreeBuilder>. It is often
useful for dialects to preprocess the tree prior to converting it into
wiki markup. Dialects that elect to preprocess the tree do so by
defining a C<preprocess_node()> class method, which will be called on
each node of the tree (traversal is done in pre-order). The method
receives three arguments: 1) the dialect's package name, 2) the
current HTML::WikiConverter instance, and 3) the current HTML::Element
node being traversed. It may modify the node or decide to ignore it.
The return value of the C<preprocess_node()> method is not used.

Because they are so commonly needed, two preprocessing steps are automatically
carried out by HTML::WikiConverter, regardless of the current dialect: 1)
relative URIs are converted to absolute URIs (based upon the 'base_uri' parameter), and 2)
ignorable content (e.g. between E<lt>/tdE<gt> and E<lt>tdE<gt>) is discarded.

=head1 SEE ALSO

  HTML::TreeBuilder
  HTML::Element

=head1 AUTHOR

David J. Iberri <diberri@yahoo.com>

=head1 COPYRIGHT

Copyright (c) 2004-2005 David J. Iberri

This library is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.

=cut

1;
