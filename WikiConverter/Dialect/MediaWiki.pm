package HTML::WikiConverter::Dialect::MediaWiki;

use HTML::WikiConverter::Dialect qw(trim passthru);
use base 'HTML::WikiConverter::Dialect';

use warnings;
use strict;

use vars qw($VERSION);
$VERSION = '0.17';

use HTML::Entities;
use Image::Grab;
use Image::Size;
use URI::Escape 'uri_unescape';

#
# version: 0.17
# date:    Wed July 07, 2004 10:58:19 PDT
# changes:
#   - lots of documentation additions
#   - 'wikify_span' now removes elements intended
#     only for URL expansion (as used by the MonoBook skin)
#   - 'wikify_link' does not wikify anchor tags (i.e.
#     A tags must have an HREF attribute)
#   - bug fix: table heading markup like "! bgcolor=black !"
#     is now properly generated as "! bgcolor=black |"
#   - TH now accepts a colspan and rowspan attribute
#   - "colspan=1" attribute is now stripped from table cells
#     that only span a single column. Likewise for "rowspan"
#     attribute
#   - added "taxo_format" option to help format taxoboxes
#   - align attribute is now preserved in TH and TD
#   - add "add_nowiki" parameter for adding NOWIKI tags
#     around {{messages}}
#   - table caption handling using "|+" wiki table markup
#   - better nested table handling; a newline is now added
#     before the "{|" for nested tables
#   - improved handling of image thumbnails -- image names
#     like "200px-blahblahblah" refer to thumbnailed images,
#     so "200px-" is now stripped off and "200px" is added
#     to the list of attributes for the [[Image:]] markup
#   - now uses warnings, strict
#   - removed tons of warnings (thanks to cpan testers for
#     revealing that there was a problem -- ID #147316)
#
# version: 0.16
# date:    Sun May 23, 2004 12:06:52 PDT
# changes:
#   - added "colspan" and "rowspan" to allowed TD attributes
#   - supports 'pretty_tables' option
#   - add \n\n before heading
#   - add PRE, CODE, and TT to passthru list
#   - removed arbitrary 20-char limit in conversion of2
#     "{{...}}" to "<nowiki>{{...}}</nowiki>" (now only
#     converts "{{...}}" if "..." contains no whitespace)
#   - "[1]" links are now converted
#   - hex codes in URLs now translated in wiki links
#   - major cleanup to 'wikify_list_item'
#   - documentation additions
#   - add new realworld test to t/mediawiki.t
# 

sub new {
  my( $pkg, %attr ) = @_;

  # Process optional parameters
  $attr{convert_wplinks} = exists $attr{convert_wplinks} ? $attr{convert_wplinks} : 1;
  $attr{default_wplang}  = exists $attr{default_wplang}  ? $attr{default_wplang}  : 'en';
  $attr{pretty_tables}   = exists $attr{pretty_tables}   ? $attr{pretty_tables}   : 0;
  $attr{taxo_format}     = exists $attr{taxo_format}     ? $attr{taxo_format}     : 0;
  $attr{add_nowiki}      = exists $attr{add_nowiki}      ? $attr{add_nowiki}      : 0;

  return $pkg->SUPER::new( %attr );
}

sub tag_handlers {
  return {
    b       => [ "'''", "'''" ],
    strong  => [ "'''", "'''" ],
    i       => [ "''",  "''" ],
    em      => [ "''",  "''"  ],
    hr      => "----",

    # Assumed to indicate indentation
    dl      => [ '', "\n\n" ],
    dt      => [ ';', '' ],
    dd      => [ ':', '' ],

    # Passthrough with valid XHTML
    br      => "<br />",

    li      => \&wikify_list_item,

    table   => \&wikify_table,
    tr      => \&wikify_tr,
    th      => \&wikify_th,
    td      => \&wikify_td,
    caption => \&wikify_caption,

    div     => \&wikify_div,
    img     => \&wikify_img,
    span    => \&wikify_span,
    a       => \&wikify_link,

    h1      => \&wikify_h,
    h2      => \&wikify_h,
    h3      => \&wikify_h,
    h4      => \&wikify_h,
    h5      => \&wikify_h,
    h6      => \&wikify_h,

    font    => \&passthru,
    sup     => \&passthru,
    sub     => \&passthru,

    center  => \&passthru,
    small   => \&passthru,

    tt      => \&passthru,
    pre     => \&passthru,
    code    => \&passthru,
  };
}

sub output {
  my $self = shift;

  my $output = $self->SUPER::output();

  # Unicode support (translates high bit chars
  # to corresponding HTML entities)
  encode_entities( $output, "\200-\377" );

  # Escape {{messages}}
  if( $self->{add_nowiki} ) {
    $self->escape_wikitext( \$output );
  }

  return $output;
}

#
# Private function: escape_wikitext( \$text )
#
# Wraps all occurrences of {{...}} in matching NOWIKI tags, resulting
# in <NOWIKI>{{...}}</NOWIKI>. This allows things like
# "{{NUMBEROFARTICLES}}" to appear in the original HTML source and be
# converted into "<nowiki>{{NUMBEROFARTICLES}}</nowiki>" by this
# module.  Likewise for "{{msg:stub}}" and other magic.
# 
# In general, any string of characters surrounded by {{ and }} that
# does does not contain any whitespace will be flanked with NOWIKI
# tags.
#

sub escape_wikitext {
  my( $self, $output ) = @_;
  $$output =~ s~({{\S+}})~<nowiki>$1</nowiki>~gm;
}

#
# Private function: tidy_whitespace( \$text )
#
# Removes unnecessary space from the text to tidy it up for
# presentation purposes. Removes all leading and trailing whitespace,
# and any occurrence of three or more consecutive newlines are
# converted into two newlines. Special care is taken not to disturb
# preformatted text contained within PRE blocks.
#

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

  # Replace each PRE block with a unique string
  $$output =~ s{<\s*pre.*?>(.*?)<\s*/\s*pre\s*>}{
    push @pre_blocks, $1;
    $unique.'['.$pre_index++.']';
  }gise;

  # Now that we've protected all PRE blocks, *now*
  # we can call the usual tidy_whitespace method
  $self->SUPER::tidy_whitespace( $output );

  # Add leading space to every line of each PRE block (if necessary)
  foreach ( @pre_blocks ) {

    # Count total number of lines in this block, and
    # make a separate count for those that have a
    # leading space
    my( $total, $with_space );
    while( /^(.*)$/gm ) {
      my $pre_line = $1;

      $with_space++ if $pre_line =~ /^ /;
      $total++;
    }

    # If every line in this PRE block contains a leading space,
    # don't bother adding another one
    s/^|(\n)/$1 ? "\n " : " "/eg if $with_space < $total;
  }

  # Put the PRE blocks back in
  $$output =~ s{$unique\[(\d+)\]}{$pre_blocks[$1]}g;
}

sub wikify_text {
  my( $self, $text, $parent ) = @_;
  $text = $self->wikify_taxo( $text, $parent ) if $self->{taxo_format};
  return $text;
}

sub wikify_taxo {
  my( $self, $text, $parent ) = @_;

  my %taxo = (
    kingdom  => 'Regnum',
    phylum   => 'Phylum',
    class    => 'Classis',
    order    => 'Ordo',
    suborder => 'Subordo',
    family   => 'Familia',
    genus    => 'Genus',
    species  => 'Species'
  );

  my $taxoterm = join '|', keys %taxo;

  $text =~ s/($taxoterm):/'{{'.$taxo{lc $1}.'}}:'/ige;

  return $text;
}

#
# Tag handler: wikify_table( $elem )
#

sub wikify_table {
  my( $self, $node ) = @_;
  
  if( $self->{pretty_tables} ) {
    # Add 'border-collapse:collapse' to table style attribute
    my %style = $self->elem_style_attr_props( $node );
    $style{'border-collapse'} = 'collapse';

    $node->attr( style => $self->style_attr_str(%style) );
    $node->attr( cellspacing => 0 );
    $node->attr( cellpadding => 3 );
    $node->attr( border => 1 );
  }

  my @attrs = qw/cellpadding cellspacing border bgcolor align style class id/;
  my $output = "{| ".$self->elem_attr_str($node, @attrs)."\n";

  if( $self->{table_caption} ) {
    $output .= "|+ ".$self->{table_caption}."\n";
    $self->{table_caption} = '';
  }

  $output .= $self->elem_contents($node);

  trim( \$output );

  $output .= "\n|}\n\n";

  # If we're inside a TD, then add a newline before the "{|"
  if( $self->elem_has_ancestor($node, 'td') ) {
    $output = "\n$output";
  }

  return $output;
}

#
# Tag handler: wikify_tr( $elem )
#

sub wikify_tr {
  my( $self, $node ) = @_;
  
  if( $self->{pretty_tables} and defined $node->left and $node->left->tag ne 'tr' ) {
    if( not $node->attr('bgcolor') ) {
      $node->attr( bgcolor => '#cccccc' );
    }
  }

  my @attrs = qw/id style class bgcolor/;
  my $attr_str = $self->elem_attr_str($node, @attrs);

  my $output = "|- $attr_str\n";
  $output .= $self->elem_contents($node);

  trim( \$output );

  return "$output\n";
}

#
# Tag handler: wikify_td( $elem )
#

sub wikify_td {
  my( $self, $node ) = @_;

  my @attrs = qw/id style class bgcolor align/;
  
  my $rowspan = $node->attr('rowspan') || 0;
  my $colspan = $node->attr('colspan') || 0;
  push @attrs, 'rowspan' if $rowspan > 1;
  push @attrs, 'colspan' if $colspan > 1;
  my $attr_str = $self->elem_attr_str($node, @attrs);
  $attr_str .= " | " if $attr_str;

  my $output = "| $attr_str";
  my $content = $self->elem_contents($node);
  $output .= $content;

  trim( \$output );

  return "$output\n";
}

sub wikify_caption {
  my( $self, $node ) = @_;
  
  $self->{table_caption} = $self->elem_contents($node)
    if $self->elem_has_ancestor($node, 'table');

  return '';
}

#
# Tag handler: wikify_th( $elem )
#

sub wikify_th {
  my( $self, $node ) = @_;

  my @attrs = qw/id style class bgcolor align/;

  my $rowspan = $node->attr('rowspan') || 0;
  my $colspan = $node->attr('colspan') || 0;
  push @attrs, 'rowspan' if $rowspan > 1;
  push @attrs, 'colspan' if $colspan > 1;

  my $attr_str = $self->elem_attr_str($node, @attrs);
  $attr_str .= " | " if $attr_str;

  my $output = "! $attr_str";
  my $content = $self->elem_contents($node);
  $output .= $content;

  trim( \$output );

  return "$output\n";
}

#
# Tag handler: wikify_list_item( $elem )
#

sub wikify_list_item {
  my( $self, $node ) = @_;

  my $bullet_char = $self->elem_has_ancestor( $node, qr/(ol|ul)/ ) eq 'ol' ? '#' : '*';
  $bullet_char = ($bullet_char) x $self->list_nest_level($node);
  $bullet_char = "$bullet_char ";

  # Grab everything inside this LI that's not a UL or OL,
  # and stick it in @nodes. If we find a nested list, then
  # store it in $nested_list and stop searching.

  my @content_list = $node->content_list;
  my $output = '';
  my $nested_list;
  my @nodes;

  # Check if we have a nested list
  foreach my $c ( @content_list ) {
    $nested_list = $c, last if $self->is_elem($c) and $c->tag =~ /ol|ul/;
  }

  if( $nested_list ) {
    foreach my $child ( @content_list ) {
      last if $child eq $nested_list;
      push @nodes, $child;
    }

    # Wikify everything we've got so far
    $output .= $self->wikify($_, $node) foreach @nodes;
  } else {
    # This node has no contents, so just wikify it
    $output = $self->elem_contents($node);
  }

  # Only add the bullets if there's output (i.e. don't create empty list items
  # or those that contain only whitespace)
  $output = $bullet_char . $output if $output =~ /\S/;

  # Remove internal newlines (all list items must appear on a single line)
  $output =~ s/[\r\n]+/ /g;

  # Ensure list item ends in a single newline
  trim( \$output );
  $output .= "\n" if $output;

  # Add the nested list
  $output .= $self->wikify($nested_list, $node) if $nested_list;

  return $output;
}

#
# Tag handler: wikify_link( $elem )
#

sub wikify_link {
  my( $self, $node ) = @_;

  # Don't wikify anchors without an HREF attribute
  my $contents = $self->elem_contents($node);
  return trim($contents) if not $node->attr('href');

  my $url = $self->absolute_url( $node->attr('href') );
  my $title = $contents;

  return $title if $self->elem_is_img_link($node);

  # Trim title unless the only child of this node is an IMG tag
  my @contents = $node->content_list;
  trim( \$title ) unless @contents == 1 and ref $contents[0] and $contents[0]->tag eq 'img';

  # Just return the link title if this tag is contained
  # within an header tag
  return $title if ref $node->parent and $node->parent->tag =~ /h\d/;

  # Return if this is a link to an image contained within
  return $title if $self->elem_is_image_div($node->parent);

  # Regexps for matching Wikipedia's URLs for viewing/editing pages
  my $re_art_view = qr~http://(\w{2})\.wikipedia\.org/wiki/(.+)~;
  my $re_art_edit = qr~http://(\w{2})\.wikipedia\.org/w/wiki\.phtml\?title\=(.+?)&action\=edit~;

  # Convert wiki links (this is not Unicode-friendly)
  if( $title =~ /\[\d+\]/ ) {
    return "[$url]";
  } elsif( $self->{convert_wplinks} and ( $url =~ $re_art_view or $url =~ $re_art_edit ) ) {
    my $lang = $1;
    ( my $wiki_page = $2 ) =~ s/_+/ /g;

    # Convert hex codes and HTML entities to single characters
    _fully_unescape( \$wiki_page );

    my $lang_interwiki = $lang eq $self->{default_wplang} ? '' : ":$lang:";
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

  # If HREF is the same as the link title, then
  # just return the URL (it'll be converted into
  # a clickable link by the wiki engine)
  return $url if $url eq $title;
  return "[$url $title]";
}

sub elem_is_img_link {
  my( $self, $node ) = @_;
  my @contents = $node->content_list;
  return 1 if @contents == 1 and ref $contents[0] and $contents[0]->tag eq 'img';
  return 0;
}

#
# In-place conversion of hex codes and HTML entities
# into their single-character equivalents
#

sub _fully_unescape {
  my $src = shift;
  $$src = uri_unescape( $$src );
  $$src = encode_entities( $$src );
}

#
# Tag handler: wikify_img( $elem )
#

sub wikify_img {
  my( $self, $node ) = @_;
  
  my $image_url = $self->absolute_url( URI->new( $node->attr('src') )->canonical );
  my $file = ( $image_url->path_segments )[-1];

  $self->log( "Processing IMG tag for SRC: ".$image_url->canonical."..." );

#  return '' if $node->attr('alt') eq 'Enlarge';

  #
  # Grab attributes to be added to the [[Image:]] markup
  #

  my $image_div = $node->parent if $self->elem_is_image_div( $node->parent );
  $image_div ||= $node->parent->parent if ref $node->parent and $self->elem_is_image_div( $node->parent->parent );

  my @attrs;

  #
  # Handle image right/left/center alignment
  #

  if( $image_div ) {
    my $css_style = $image_div->attr('style') || '';
    my $css_class = $image_div->attr('class') || '';
    
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
  # Check for thumbnailing
  # 
  # It's needed if the specified width attribute
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
  } else {
    # Check whether image name is something like "200px-BlahBlahBlah" -- if so, the
    # "200px" means this is a thumbnailed image
    $self->log( "  No WIDTH attribute specified; checking for a title like '200px-blahblahblah'" );
    
    if( $file =~ s/^(\d+px)\-// ) {
      my $thumbsize = $1;
      push @attrs, $thumbsize;
      $self->log( "    Title matches /^\\d+px\-/" );
      $self->log( "    Stripped '$1-' from filename" );
      $self->log( "    Adding '$thumbsize' to list of attributes for [[Image:]] markup" );
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

#
# Tag handler: wikify_div( $elem )
#

# New thumbnail HTML:
#
#<div class="thumb tright">
#  <div style="width:252px;">
#    <a href="jpg"><img></a>
#    <div class="thumbcaption">
#      <div class="magnify">
#        <a href="jpg"><img></a>
#      </div>
#    </div>
#  </div>
#</div>

sub wikify_div {
  my( $self, $node ) = @_;
  
  my $contents = $self->elem_contents( $node );

#  return '' if $node->attr('class') eq 'magnify';
#  return '' if $node->attr('class') eq 'thumbcaption';
#  return $contents if $node->attr('style') =~ /^width:\d+px;$/;

  # Image DIVs will be removed because the [[Image:image.jpg|...]]
  # syntax (see wikify_img) can specify this information
  return $contents if $self->elem_is_image_div($node);

  # Normal (non-image) DIV
  my @attrs = qw/align class id style/;
  my $attr_str = $self->elem_attr_str($node, @attrs);
  $attr_str = " $attr_str" if $attr_str;
  return "<div$attr_str>$contents</div>\n\n";
}

#
# Tag handler: wikify_span( $elem )
#
# Attempts to convert a SPAN tag into an equivalent FONT tag (since
# some wikis do not allow SPAN tags, only FONT tags). Also, strips
# SPAN elements intended for URL expansion.
#

sub wikify_span {
  my( $self, $node ) = @_;

  # Remove element if it was intended only for URL expansion
  my $class = $node->attr('class') || '';
  return '' if trim($class) eq 'urlexpansion';

  #
  # Convert SPAN style properties onto their FONT counterparts
  #

  # Maps STYLE properties to FONT attributes
  my %style2font = (
    'font-family' => 'face',
    'color'       => 'color',
  );

  # Fetch hash mapping style property to its value
  my %style = $self->elem_style_attr_props($node);

  # Convert STYLE properties to their FONT attribute counterparts
  my $font_attr_str = '';
  foreach my $prop ( keys %style ) {
    my $lc_prop = lc $prop; # for keying into %style2font
    next unless exists $style2font{$lc_prop} and length $style{$prop};
    $font_attr_str .= " $style2font{$lc_prop}=\"$style{$prop}\"";
  }

  # Some SPAN attributes are allowed
  for my $attr ( qw/class id/ ) {
    my $val = $node->attr($attr);
    $font_attr_str .= " $attr=\"$val\"" if $val and length $val;
  }

  # Grab element contents
  my $content = $self->elem_contents( $node );

  # Convert into FONT tag if we have some valid/allowed attributes
  return "<font$font_attr_str>$content</font>" if $font_attr_str;

  # Strip off SPAN tag otherwise
  return $content;
}

#
# Tag handler: wikify_h( $elem )
#

sub wikify_h {
  my( $self, $elem ) = @_;

  # Parse the heading level out of the tag name
  $elem->tag =~ /h(\d)/;

  # Number of equal signs in wiki heading syntax
  # is equal to the heading level ($1)
  my $markup = ('=') x $1; 

  my $contents = $self->elem_contents($elem);
  trim( \$contents );

  return "\n\n$markup $contents $markup\n\n";
}

#
# Utility function: elem_is_image_div( $elem )
#
# Returns true if $elem is a container element (P or DIV) that was
# used to lay out an IMG.
#
# More specifically, returns true if the given element is a DIV or P
# element and the only child it contains is an IMG tag or an IMG tag
# contained within a sole A tag (not counting child elements with
# whitespace text only).
#

sub elem_is_image_div {
  my( $self, $node ) = @_;

  # Return false if node is undefined or isn't a DIV at all
  return 0 if not defined $node or $node->tag !~ /(?:p|div)/;

  return 1 if $node->attr('class') and $node->attr('class') =~ /^thumb/;

  # This counts the number of child nodes
  # that are either tags or are plain text
  # with at least one nonspace character
  my @contents = grep {
    ref $_ or $_ =~ /\S/
  } $node->content_list;

  # Returns true if sole child is an IMG tag  
  return 1 if @contents == 1 and ref $contents[0] and $contents[0]->tag eq 'img';

  # Check if child is a sole A tag that contains an IMG tag
  if( @contents == 1 and ref $contents[0] and $contents[0]->tag eq 'a' ) {
    my @children = grep {
      ref $_ or $_ =~ /\S/
    } $contents[0]->content_list;
    return 1 if @children == 1 and ref $children[0] and $children[0]->tag eq 'img';
  }

  return 0;
}

1;

__END__

=head1 NAME

HTML::WikiConverter::Dialect::MediaWiki - Dialect for conversion of HTML to MediaWiki markup

=head1 SYNOPSIS

  use HTML::WikiConverter;

  my $wc = new HTMLM::WikiConverter(
    html => $html,
    dialect => 'MediaWiki',
    pretty_tables => 1
  );

  print $wc->output;

=head1 DESCRIPTION

This module is the HTML::WikiConverter dialect for producing MediaWiki markup
from HTML source. MediaWiki is a wiki engine, particularly well known because
it is the wiki engine used by the free encyclopedia, Wikipedia.

=head1 OPTIONS

This module accepts a few options. You can pass them in to this module by
including them when you construct a new HTML::WikiConverter:

  my $wc = new HTML::WikiConverter(
    html => $html,
    dialect => 'MediaWiki',
    base_url => 'http://en.wikipedia.org',

    default_wplang  => 'en',
    convert_wplinks => 1,
    pretty_tables   => 1
  );

In addition to the standard parameters that can be passed to any wiki
dialect (including C<html>, and C<base_url>), this module also
accepts:

=over

=item B<convert_wplinks>

Specifies whether links to Wikipedia (http://www.wikipedia.org) should
be converted into their [[wikilink]] equivalents. For example, with
the C<convert_wplinks> enabled, the HTML

  <A HREF="http://en.wikipedia.org/wiki/Comedy_film">Comedy film</A>

will be automatically converted to

  [[Comedy film]]

Wikipedia allows you to specify alternate titles for links. This
module uses the content of the A tag as the alternate title. So

  <A HREF="http://en.wikipedia.org/wiki/Comedy_film">comedy</A>

becomes

  [[Comedy film|comedy]]

Capitalization is also considered when producing wiki links. If the
page title and alternate title differ only in the capitalization of
the first character of the title, then a simpler link is produced.  So
rather than converting

  <A HREF="http://en.wikipedia.org/wiki/Comedy_film">comedy film</A>

to

  [[Comedy film|comedy film]]

this module produces

  [[comedy film]]

since the Wikipedia parser knows that this should point to the "Comedy
film" article.

B<Note>: Despite this apparent coolness, the "pipe trick" is not yet
used by this module. If it were, this module would convert this

  <A HREF="http://en.wikipedia.org/wiki/User:Diberri">Diberri</A>

into

  [[User:Diberri|]]

(Note the trailing pipe character.) That would be really cool, but
it's not yet implemented.

=item B<default_wplang>

Specifies the two-character langauge code to be used as the default
language when converting links to Wikipedia articles. If the language
differs from the language found in the URL, then an interlanguage wiki
link is created with

  [[:xx:Article]]

Where "xx" is the language code in the URL, and "Article" is the name
of the article being linked to. Note that the leading colon is not a
typo -- this is needed so that the MediaWiki software interprets this
as a link to an article rather than an indication that a translation
of the current page is available.

=item B<pretty_tables>

Boolean specifying whether to stylize tables with shading and thin
borders. A "pretty table" looks like this:

  {| cellpadding="3" cellspacing="0" border="1" style="border-collapse: collapse"
  |- bgcolor="#cccccc"
  | ... etc
  |}

=head1 FEATURES

The MediaWiki dialect converts most HTML tags into their MediaWiki
equivalents.

=over

=item Simple markup

Tags such as B, STRONG, EM, and I are converted to their MediaWiki
equivalents.

=item Tables (nested tables not supported)

TABLE tags and associated TR, TH, and TD tags are converted into
"{|...|}" blocks. Nested tables are currently not supported at any
reasonable level.

=item Lists (nested lists are supported)

Both unordered and ordered lists (UL and OL, respectively) are
converted into their MediaWiki counterparts using an asterisk (*) to
indicate a bulleted (unordered) list, and a pound sign (#) to
represent a numbered (ordered) list.

=item Indentation (and multiple-indentation)

In the HTML source, indentation is accomplished with DL and DD
tags. Indented blocks are prefixed with a colon (or multiple colons,
for multiply-indented blocks) in the MediaWiki markup.

=item Converts SPAN to FONT

Where possible, SPAN tags are converted into their FONT equivalents.
Some style properties present in the SPAN tag, including "font-family"
and "color", are converted to FONT attributes. The "font-family"
property is converted to a "face" attribute on the FONT tag, and the
"color" property is converted to a "color" attribute.

The "class" and "id" SPAN attributes are copied to the FONT tag.

=item Headings (H1-H6)

Headings tags (H1-H6) are replaced with symmetrical sequences of equal
signs, with one equal sign per heading level (e.g. H1 gets a single
equal sign, H6 gets six of them).

=item Images (including thumbnails and their placement)

IMG tags are converted to the appropriate [[Image:...]] markup, and
the context of the IMG tag is used to add attributes to the resulting
MediaWiki image markup. For example, if the IMG tag is enclosed in a
DIV that specifies "float:right" for the STYLE attribute, then the
"right" keyword is appended to the list of attributes in the image
markup (e.g. "[[Image:thing.png|right]]").

Additionally, thumbnail markup is generated if the IMG tag specifies a
"width" attribute that differs from the actual width of the image as
it's stored on the network.

=item Line breaks

HTML line breaks (BR tags) are converted to the XHTML-compatible
"E<lt>br /E<gt>".

=back

=head1 KNOWN BUGS

 Nested tables are not handled properly (or at all, really)

 DIVs used to align images are not always properly recognized

 Whether to pull an image of the network should be a configurable option

=head1 COPYRIGHT

Copyright (c) 2004 David J. Iberri

This library is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

David J. Iberri <diberri@yahoo.com>

=cut