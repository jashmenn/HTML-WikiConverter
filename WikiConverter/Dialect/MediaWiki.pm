package HTML::WikiConverter::Dialect::MediaWiki;

use HTML::WikiConverter::Dialect qw(trim passthru);
use base 'HTML::WikiConverter::Dialect';

use vars qw($VERSION);
$VERSION = '0.14';

use HTML::Entities;
use Image::Grab;
use Image::Size;

sub new {
  my( $pkg, %attr ) = @_;

  my $self = bless {
    convert_wplinks => exists $attr{convert_wplinks} ? $attr{convert_wplinks} : 1,
    default_wplang  => exists $attr{default_wplang}  ? $attr{default_wplang}  : 'en'
  }, $pkg;

  return $self;
}

sub tag_handlers {
  return {
    html   => '',
    head   => '',
    title  => '',
    meta   => '',
    body   => '',
    object => '',

    br     => "<br />",
    b      => [ "'''" ],
    strong => [ "'''" ],
    i      => [ "''"  ],
    em     => [ "''"  ],
    hr     => "----\n\n",

    # PRE blocks are handled specially (see tidy_whitespace and
    # wikify methods)
    pre    => [ "<pre>", "</pre>\n\n" ],

    dl     => [ '', "\n\n" ],
    dt     => [ ';', '' ],
    dd     => [ ':', '' ],

    p      => [ "\n\n", "\n\n" ],
    ul     => [ '', "\n\n" ],
    ol     => [ '', "\n\n" ],

    li     => \&wikify_list_item,
    table  => \&wikify_table,
    tr     => \&wikify_tr,
    th     => \&wikify_th,
    td     => \&wikify_td,
    div    => \&wikify_div,
    img    => \&wikify_img,
    a      => \&wikify_link,
    span   => \&wikify_span,

    h1     => \&wikify_h,
    h2     => \&wikify_h,
    h3     => \&wikify_h,
    h4     => \&wikify_h,
    h5     => \&wikify_h,
    h6     => \&wikify_h,

    font   => \&passthru,
    sup    => \&passthru,
    sub    => \&passthru,
    center => \&passthru,
    small  => \&passthru,
  };
}

sub output {
  my $self = shift;

  my $output = $self->SUPER::output();

  # Unicode support (translates high bit chars
  # to corresponding HTML entities)
  encode_entities( $output, "\200-\377" );

  $self->escape_wikitext( \$output );
  return $output;
}

=item B<escape_wikitext>

  $wc->escape_wikitext( \$text )

Wraps all occurrences of {{...}} in NOWIKI tags (up to 20 characters
between the {{ and }}), resulting in
E<lt>NOWIKIE<gt>{{...}}E<lt>/NOWIKIE<gt>.

=cut

sub escape_wikitext {
  my( $self, $output ) = @_;
  $$output =~ s~({{.{1,20}?}})~<nowiki>$1</nowiki>~gm;
}

=item B<tidy_whitespace>

  $wc->tidy_whitespace( \$text )

Removes unnecessary space from the text to tidy it up for presentation
purposes. Removes all leading and trailing whitespace, and any
occurrence of three or more consecutive newlines are converted into
two newlines. Special care is taken not to disturb preformatted text
contained within PRE blocks.

=cut

sub tidy_whitespace {
  my( $self, $output ) = @_;

  #
  # Tidy up whitespace by replacing two or more endlines
  # (\n or \r) with \n\n. This must take care not to
  # disturb PRE blocks, whose whitespace cannot be ignored.
  #
  # Method:
  #
  #   1. Replace <PRE>...</PRE> with <unique_string>[<index>],
  #      where <unique_string> is some long, random, unlikely-
  #      to-be-present-in-output string, and <index> is the
  #      order in which the PRE block appears in the output.
  #      Store each PRE block in @pre_blocks, which is indexed
  #      by <index>
  #   2. Convert [\n\r]{2,n} into \n\n
  #   3. Replace each occurence of <unique_string>[<index>]
  #      in the output with the corresponding item from
  #      @pre_blocks
  #
  # This is essentially borrowed from the MediaWiki source,
  # which uses this method to prevent NOWIKI blocks from
  # being formatted.
  #

  my @pre_blocks;
  my $pre_index = 0;

  my $unique = '3iyZiyA7iMwg5rhxP0Dcc9oTnj8qD1jm1Sfv4';

  $$output =~ s{<\s*pre.*?>(.*?)<\s*/\s*pre\s*>}{
    push @pre_blocks, $1;
    $unique.'['.$pre_index++.']';
  }gise;

  # Ensure that each line of PRE block has a leading space
  for( @pre_blocks ) {
    s[^(.*)$][
      my $pre_text = $1;
      if( $pre_text =~ /^\s/ ) {
        $pre_text;
      } else {
        " $pre_text";
      }
    ]gem;
  }

  $self->SUPER::tidy_whitespace( $output );

  # Put the PRE blocks back in
  $$output =~ s{$unique\[(\d+)\]}{$pre_blocks[$1]}g;
}

=item B<wikify_table>

  $output = wikify_table( $elem )

=cut

sub wikify_table {
  my( $self, $node ) = @_;
  
  my @attrs = qw/cellpadding cellspacing border bgcolor align style class id/;
  my $output = "{| ".$self->elem_attr_str($node, @attrs)."\n";
  $output .= $self->elem_contents($node);
  $output .= "|}\n\n";

  return $output;
}

=item B<wikify_tr>

  $output = wikify_tr( $elem )

=cut

sub wikify_tr {
  my( $self, $node ) = @_;
  
  my @attrs = qw/id style class bgcolor/;
  my $attr_str = $self->elem_attr_str($node, @attrs);

  my $output = "|- $attr_str\n";
  $output .= $self->elem_contents($node);

  trim( \$output );

  return "$output\n";
}

=item B<wikify_td>

  $output = wikify_td( $elem )

=cut

sub wikify_td {
  my( $self, $node ) = @_;

  my @attrs = qw/id style class bgcolor/;
  my $attr_str = $self->elem_attr_str($node, @attrs);
  $attr_str .= " | " if $attr_str;

  my $output = "| $attr_str";
  my $content = $self->elem_contents($node);
  $output .= $content;

  trim( \$output );

  return "$output\n";
}

sub wikify_th {
  my( $self, $node ) = @_;

  my @attrs = qw/id style class bgcolor/;
  my $attr_str = $self->elem_attr_str($node, @attrs);
  $attr_str .= " ! " if $attr_str;

  my $output = "! $attr_str";
  my $content = $self->elem_contents($node);
  $output .= $content;

  trim( \$output );

  return "$output\n";
}

=item B<wikify_list_item>

  $output = wikify_list_item( $elem )

=cut

# XXX Doesn't properly handle nesting
sub wikify_list_item {
  my( $self, $node ) = @_;

  my $bullet_char = $self->elem_has_ancestor( $node, qr/(ol|ul)/ ) eq 'ol' ? '#' : '*';
  $bullet_char = ($bullet_char) x $self->list_nest_level($node);
  $bullet_char = "$bullet_char ";

  my $output = $bullet_char;
  my $content = $self->elem_contents($node);

  $output .= $content;

  trim( \$output );
  
  return "$output\n";
}

=item B<wikify_link>

  $output = wikify_link( $elem )

=cut

sub wikify_link {
  my( $self, $node ) = @_;

  my $url = $self->absolute_url( $node->attr('href') );
  my $title = $self->elem_contents($node);

  # Trim title unless the only child of this node is an IMG tag
  my @contents = $node->content_list;
  trim( \$title ) unless @contents == 1 and ref $contents[0] and $contents[0]->tag eq 'img';

  # Just return the link title if this tag is contained
  # within an header tag
  return $title if ref $node->parent and $node->parent->tag =~ /h\d/;

  # Return if this is a link to an image contained within
  return $title if $self->elem_is_image_div($node->parent);

  # Convert wiki links (this is not Unicode-friendly)
  if( $self->{convert_wplinks} ) {
    if( $url =~ m~http://(\w{2})\.wikipedia\.org/wiki/(.+)~ ) {
      my $lang = $1;
      ( my $wiki_page = $2 ) =~ s/_+/ /g;
      my $lang_interwiki = "$lang:" unless $lang eq $self->{default_wplang};
      return "[[$lang_interwiki$wiki_page]]" if $wiki_page eq $title;

      # Factor out common text in $wiki_page and $title and produce [[hand]]s link
      # where "s" is what was factored out and "hand" was the given $title
      my $canon_title = ucfirst lc $title;
      if( $canon_title =~ /^$wiki_page/ ) {
        # Preserve case of given $title
        # E.g., grab "Hand" out of "Hands"
        ( my $trailing = $title ) =~ s/^($wiki_page)//i;
        return "[[$lang_interwiki$1]]$trailing";
      }

      return "[[$lang_interwiki$wiki_page|$title]]";
    }
  }

  # If HREF is the same as the link title, then
  # just return the URL (it'll be converted into
  # a clickable link by the wiki engine)
  return "$url" if $url eq $title;
  return "[$url $title]";
}

=item B<wikify_img>

  $output = wikify_img( $elem )

=cut

sub wikify_img {
  my( $self, $node ) = @_;
  
  my $image_url = $self->absolute_url( URI->new( $node->attr('src') )->canonical );
  my $file = ( $image_url->path_segments )[-1];

  $self->log( "Processing IMG tag for SRC: ".$image_url->canonical."..." );

  #
  # Grab attributes to be added to the [[Image:]] markup
  #

  my $image_div = $node->parent if $self->elem_is_image_div( $node->parent );
  $image_div ||= $node->parent->parent if ref $node->parent and $self->elem_is_image_div( $node->parent->parent );

  my @attrs;
  if( $image_div ) {
    my $css_style = $image_div->attr('style');
    my $css_class = $image_div->attr('class');
    
    # Check for float attribute; if it's there,
    # then we'll add it to the [[Image:]] syntax
    $css_style =~ /float\:\s*(right|left)/i;
    my $alignment = $1;
    
    $css_class =~ /float(right|left)/i;
    $alignment ||= $1;
    
    if( $alignment ) {
      push @attrs, $alignment;

      $self->log( "  Image is contained within a DIV that specifies $alignment alignment" );
      $self->log( "  Adding '$alignment' to [[Image:]] markup attributes" );
    } else {
      $self->log( "  Image is not contained within a DIV for alignment" );
    }
  } else {
    $self->log( "  Image is not contained within a DIV" );
  }
  
  #
  # Check if we need to request a thumbnail of this
  # image; it's needed if the specified width attribute
  # differs from the default size of the image
  #

  if( my $width = $node->attr('width') ) {
    $self->log( "  Image has WIDTH attribute of $width" );
    $self->log( "  Checking whether resulting [[Image:]] markup should specify a thumbnail..." );

    # Download the image from the network and store
    # its contents in $buffer
    my $abs_url = $self->absolute_url( $node->attr('src') );
    $self->log( "    Fetching image '$abs_url' from the network" );
    my $image = new Image::Grab();
    $image->url( $abs_url );
    $image->grab();
    my $buffer = $image->image;
    
    # Grab the width & height of the image

    my( $actual_w, $actual_h ) = imgsize( \$buffer );
    $self->log( "    Calculating size of image '$abs_url': $actual_w x $actual_h" );

    # If the WIDTH attribute of the IMG tag is not equal
    # to the actual width of the image, then we need to
    # create a thumbnail
    if( $width =~ /^\d+$/ and $width != $actual_w ) {
      $self->log( "    IMG tag's WIDTH attribute ($width) differs from actual width of image ($actual_w)" );
      $self->log( "      -- that means we're going to need a thumbnail" );
      $self->log( "    Adding 'thumb' and '${width}px' to list of attributes for [[Image:]] markup" );
      push @attrs, 'thumb';
      push @attrs, "${width}px";
    }
  }

  if( my $alt = $node->attr('alt') ) {
    $self->log( "  Adding alternate text '$alt' to [[Image:]] markup" );
    push @attrs, $alt;
  }

  my $attr_str = join '|', @attrs;

  # All [[Image:]] markup ends with two newlines
  my $trail_space = "\n\n";

  $self->log( "...done processing IMG tag\n" );

  return "[[Image:$file|$attr_str]]$trail_space";
}

=item B<wikify_div>

  $output = wikify_div( $elem )

=cut

sub wikify_div {
  my( $self, $node ) = @_;
  
  my $contents = $self->elem_contents( $node );

  # Image DIVs will be removed because the [[Image:image.jpg|...]]
  # syntax (see wikify_img) can specify this information
  return $contents if $self->elem_is_image_div($node);

  # Normal (non-image) DIV
  my @attrs = qw/align class id style/;
  my $attr_str = $self->elem_attr_str($node, @attrs);
  $attr_str = " $attr_str" if $attr_str;
  return "<div$attr_str>$contents</div>\n\n";
}

=item B<wikify_span>

  $output = wikify_span( $elem )

Attempts to convert a SPAN tag into an equivalent FONT tag (since
some wikis do not allow SPAN tags, only FONT tags).

=cut

sub wikify_span {
  my( $self, $node ) = @_;

  my $content = $self->elem_contents( $node );

  # Grab STYLE attribute
  my $style = $node->attr('style');

  # Maps STYLE properties to FONT attributes
  my %style2font = (
    'font-family' => 'face',
    'color'       => 'color',
  );

  # Parse STYLE attribute
  my $font_attr_str = '';
  foreach my $prop ( split ';', $node->attr('style') ) {
    my( $pname, $pval ) = split ':', $prop, 2;
    $pname = lc $pname;

    if( exists $style2font{$pname} and length $pval ) {
      $font_attr_str .= " $style2font{$pname}=\"$pval\"" if length $pval;
    }
  }

  # Grab CLASS and ID attributes too
  for my $attr ( qw/class id/ ) {
    my $val = $node->attr($attr);
    $font_attr_str .= " $attr=\"$val\"" if length $val;
  }
  
  # Convert into FONT tag if we have some valid attributes
  return "<font$font_attr_str>$content</font>" if $font_attr_str;

  # Strip off SPAN tag otherwise
  return $content;
}

=item B<wikify_h>

  $output = wikify_h( $elem )

=cut

sub wikify_h {
  my( $self, $elem ) = @_;

  # Parse the heading level out of the tag name
  $elem->tag =~ /h(\d)/;

  # Number of equal signs in wiki heading syntax
  # is equal to the heading level ($1)
  my $markup = ('=') x $1; 

  my $contents = $self->elem_contents($elem);
  trim( \$contents );

  return "$markup $contents $markup\n\n";
}

1;
