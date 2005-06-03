package HTML::WikiConverter::PmWiki;
use base 'HTML::WikiConverter';
use warnings;
use strict;

sub rules {
  my %rules = (
    hr => { replace => "\n----\n" },
    br => { replace => " \\\\\n" },

    h1 => { start => '! ',      block => 1, trim => 'both', line_format => 'single' },
    h2 => { start => '!! ',     block => 1, trim => 'both', line_format => 'single' },
    h3 => { start => '!!! ',    block => 1, trim => 'both', line_format => 'single' },
    h4 => { start => '!!!! ',   block => 1, trim => 'both', line_format => 'single' },
    h5 => { start => '!!!!! ',  block => 1, trim => 'both', line_format => 'single' },
    h6 => { start => '!!!!!! ', block => 1, trim => 'both', line_format => 'single' },

    blockquote => { start => \&_blockquote_start, trim => 'both', block => 1, line_format => 'multi' },
    pre        => { line_prefix => ' ', block => 1 },
    p          => { block => 1, trim => 'both', line_format => 'multi' },

    b      => { start => "'''", end => "'''", line_format => 'single' },
    strong => { alias => 'b' },
    i      => { start => "''", end => "''", line_format => 'single' },
    em     => { alias => 'i' },
    tt     => { start => '@@', end => '@@', trim => 'both', line_format => 'single' },
    code   => { alias => 'tt' },

    big   => { start => '+',  end => '+',  line_format => 'single' },
    small => { start => '-',  end => '-',  line_format => 'single' },
    sup   => { start => '^',  end => '^',  line_format => 'single' },
    sub   => { start => '_',  end => '_',  line_format => 'single' },
    ins   => { start => '{+', end => '+}', line_format => 'single' },
    del   => { start => '{-', end => '-}', line_format => 'single' },

    ul => { line_format => 'multi', block => 1 },
    ol => { alias => 'ul' },
    li => { start => \&_li_start, trim => 'leading' },

    dl => { alias => 'ul' },
    dt => { start => \&_li_start, line_format => 'single', trim => 'both' },
    dd => { start => ': ' },

    a   => { replace => \&_link },
    img => { replace => \&_image },

    table => { start => \&_table_start, block => 1 },
    tr    => { start => "\n||", line_format => 'single' },
    td    => { start => \&_td_start, end => \&_td_end, trim => 'both' },
    th    => { alias => 'td' }
  );

  return \%rules;
}

sub _table_start {
  my( $self, $node, $rules ) = @_;
  my @attrs = qw/ border cellpadding cellspacing width bgcolor align /;
  return '|| '.$self->get_attr_str( $node, @attrs );
}

sub _td_start {
  my( $self, $node, $rules ) = @_;
  my $prefix = $node->tag eq 'th' ? '!' : '';

  my $align = $node->attr('align') || 'left';
  $prefix .= ' ' if $align eq 'center' or $align eq 'right';

  return $prefix;
}

sub _td_end {
  my( $self, $node, $rules ) = @_;
  my $colspan = $node->attr('colspan') || 1;
  my $suffix = ( '||' ) x $colspan;

  my $align = $node->attr('align') || 'left';
  $suffix = ' '.$suffix if $align eq 'center' or $align eq 'left';

  return $suffix;
}

sub _blockquote_start {
  my( $self, $node, $rules ) = @_;
  my @parent_bqs = $node->look_up( _tag => 'blockquote' );
  my $depth = @parent_bqs;
  
  my $start = ( '-' ) x $depth;
  return "\n".$start.'>';
}

sub _li_start {
  my( $self, $node, $rules ) = @_;
  my @parent_lists = $node->look_up( _tag => qr/ul|ol|dl/ );
  my $depth = @parent_lists;

  my $bullet = '';
  $bullet = '*' if $node->parent->tag eq 'ul';
  $bullet = '#' if $node->parent->tag eq 'ol';
  $bullet = ':' if $node->parent->tag eq 'dl';

  my $prefix = ( $bullet ) x $depth;
  return "\n".$prefix.' ';
}

sub _link {
  my( $self, $node, $rules ) = @_;
  my $url = $node->attr('href') || '';
  my $text = $self->get_elem_contents($node) || '';
  return "[[$url | $text]]";
}

sub _image {
  my( $self, $node, $rules ) = @_;
  return $node->attr('src') || '';
}

sub preprocess_node {
  my( $self, $node ) = @_;
  $self->strip_aname($node) if $node->tag eq 'a';
  $self->caption2para($node) if $node->tag eq 'caption';
}

1;

__END__

=head1 NAME

HTML::WikiConverter::PmWiki - HTML-to-wiki conversion rules for PmWiki

=head1 SYNOPSIS

  use HTML::WikiConverter;
  my $wc = new HTML::WikiConverter( dialect => 'PmWiki' );
  print $wc->html2wiki( $html );

=head1 DESCRIPTION

This module contains rules for converting HTML into PmWiki markup. See
L<HTML::WikiConverter> for additional usage details.

=head1 AUTHOR

David J. Iberri <diberri@yahoo.com>

=head1 COPYRIGHT

Copyright (c) 2005 David J. Iberri

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
