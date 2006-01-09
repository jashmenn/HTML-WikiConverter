package HTML::WikiConverter::MoinMoin;
use base 'HTML::WikiConverter';
use warnings;
use strict;

sub rules {
  my %rules = (
    p   => { block => 1, trim => 'both', line_format => 'multi' },
    pre => { block => 1, start => "{{{\n", end => "\n}}}" },

    i      => { start => "''", end => "''", line_format => 'single' },
    em     => { alias => 'i' },
    b      => { start => "'''", end => "'''", line_format => 'single' },
    strong => { alias => 'b' },
    u      => { start => '__', end => '__', line_format => 'single' },

    sup   => { start => '^', end => '^', line_format => 'single' },
    sub   => { start => ',,', end => ',,', line_format => 'single' },
    code  => { start => '`', end => '`', line_format => 'single' },
    tt    => { alias => 'code' },
    small => { start => '~-', end => '-~', line_format => 'single' },
    big   => { start => '~+', end => '+~', line_format => 'single' },

    a => { replace => \&_link },
    img => { replace => \&_image },

    ul => { line_format => 'multi', block => 1, line_prefix => '  ' },
    ol => { alias => 'ul' },

    li => { start => \&_li_start, trim => 'leading' },

    dl => { line_format => 'multi' },
    dt => { trim => 'both', end => ':: ' },
    dd => { trim => 'both' },

    hr => { replace => "\n----\n" },
    br => { replace => '[[BR]]' },

    table => { block => 1, line_format => 'multi' },
    tr => { end => "||\n", line_format => 'single' },
    td => { start => \&_td_start, end => ' ', trim => 'both' },
    th => { alias => 'td' },
  );

  # Headings (h1-h6)
  my @headings = ( 1..6 );
  foreach my $level ( @headings ) {
    my $tag = "h$level";
    my $affix = ( '=' ) x ($level+1);
    $affix = '======' if $level == 6;
    $rules{$tag} = { start => $affix.' ', end => ' '.$affix, block => 1, trim => 'both', line_format => 'single' };
  }

  return \%rules;
}

my %att2prop = (
  width => 'width',
  bgcolor => 'background-color',
);

sub _td_start {
  my( $self, $td, $rules ) = @_;

  my $prefix = '||';

  my @style = ( );

  push @style, '|'.$td->attr('rowspan') if $td->attr('rowspan');
  push @style, '-'.$td->attr('colspan') if $td->attr('colspan');

  # If we're the first td in the table, then include table settings
  if( ! $td->parent->left && ! $td->left ) {
    my $table = $td->look_up( _tag => 'table' );
    my $attstr = _attrs2style( $table, qw/ width bgcolor / );
    push @style, "tablestyle=\"$attstr\"" if $attstr;
  }

  # If we're the first td in this tr, then include tr settings
  if( ! $td->left ) {
    my $attstr = $td->parent->attr('style');
    push @style, "rowstyle=\"$attstr\"" if $attstr;
  }

  # Include td settings
  my $attstr = join ' ', map { "$_=\"".$td->attr($_)."\"" } grep $td->attr($_), qw/ id class style /;
  push @style, $attstr if $attstr;

  my $opts = @style ? '<'.join(' ',@style).'>' : '';

  return $prefix.$opts.' ';
}

sub _attrs2style {
  my( $node, @attrs ) = @_;
  return unless $node;
  my %attrs = map { $_ => $node->attr($_) } grep $node->attr($_), @attrs;
  my $attstr = join '; ', map "$att2prop{$_}:$attrs{$_}", keys %attrs;
  return $attstr || '';
}

sub _li_start {
  my( $self, $node, $rules ) = @_;
  my $bullet = '';
  $bullet = '*'  if $node->parent->tag eq 'ul';
  $bullet = '1.' if $node->parent->tag eq 'ol';
  return "\n$bullet ";
}

sub _link {
  my( $self, $node, $rules ) = @_;
  my $url = $node->attr('href') || '';
  my $text = $self->get_elem_contents($node) || '';
  return $url if $url eq $text;
  return "[$url $text]";
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

my @protocols = qw( http https mailto );
my $urls  = '(' . join('|', @protocols) . ')';
my $ltrs  = '\w';
my $gunk  = '\/\#\~\:\.\?\+\=\&\%\@\!\-';
my $punc  = '\.\:\?\-\{\(\)\}';
my $any   = "${ltrs}${gunk}${punc}";
my $url_re = "\\b($urls:\[$any\]+?)(?=\[$punc\]*\[^$any\])";

sub postprocess_output {
  my( $self, $outref ) = @_;
  $$outref =~ s/($url_re)\[\[BR\]\]/$1 [[BR]]/go;
}

1;

__END__

=head1 NAME

HTML::WikiConverter::MoinMoin - HTML-to-wiki conversion rules for MoinMoin

=head1 SYNOPSIS

  use HTML::WikiConverter;
  my $wc = new HTML::WikiConverter( dialect => 'MoinMoin' );
  print $wc->html2wiki( $html );

=head1 DESCRIPTION

This module contains rules for converting HTML into MoinMoin
markup. See L<HTML::WikiConverter> for additional usage details.

=head1 AUTHOR

David J. Iberri <diberri@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2005 David J. Iberri

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
