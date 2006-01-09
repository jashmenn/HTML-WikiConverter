use Test::More;
use File::Spec;
use HTML::Entities;
use HTML::WikiConverter;
*e = \&encode_entities;

#
# This script parses and evaluates the HTML::WikiConverter tests. Each
# dialect's test script should look something like this:
#
#    local $/;
#    require 't/runtests.pl';
#    runtests( data => <DATA>, dialect => 'MyDialect' );
#    close DATA;
#
#    __DATA__
#    test1-name
#    <b>test1-markup</b>
#    ++
#    **test1-markup**
#    ++++
#    test2-name
#    <i>test2-markup</i>
#    ++
#    //test2-markup//
#
# Etc.
#
# In addition to these dialect-specific tests, runtests.pl generates a
# host of other tests to be evaluated in each dialect (e.g. HTML
# entity tests and miscellaneous strip_* tests).
#

my $more_tests = <<END_TESTS;
++++
entities (1)
To enter a '&lt;' in your input, use "&amp;lt;"
++
To enter a '&lt;' in your input, use "&amp;lt;"
++++
entities (2)
To enter a '<' in your input, use "&amp;lt;"
++
To enter a '&lt;' in your input, use "&amp;lt;"
++++
strip comments
A <!-- stripped --> comment
++
A  comment
++++
strip head
<html>
<head><title>fun stuff</title></head>
<body>
<p>Crazy stuff here</p>
</body>
</html>
++
Crazy stuff here
++++
strip scripts
<html>
<head><script>bogus stuff</script></head>
<body>
<script>maliciousCode()</script>
<p>benevolent text</p>
</body>
</html>
++
benevolent text
END_TESTS

sub runtests {
  my %arg = @_;

  $arg{strip_comments} = 1;
  $arg{wrap_in_html} = 1;
  $arg{base_uri} ||= 'http://www.test.com';
  my $minimal = $arg{minimal} || 0;

  my $data = $arg{data} || '';
  $data .= entity_tests() . $more_tests unless $minimal;

  my @tests = split /\+\+\+\+\n/, $data;
  my $numtests = @tests;
  $numtests += 1 unless $minimal; # file test
  plan tests => $numtests;

  # Delete unrecognized HTML::WikiConverter options
  delete $arg{$_} for qw/ data minimal /;

  my $wc = new HTML::WikiConverter(%arg);
  foreach my $test ( @tests ) {
    $test =~ s/^(.*?)\n//; my $name = $1;
    my( $html, $wiki ) = split /\+\+/, $test;
    for( $html, $wiki ) { s/^\n+//; s/\n+$// }
    is( $wc->html2wiki($html), $wiki, $name );
  }

  file_test($wc) unless $minimal;
}

sub entity_tests {
  my $tmpl = "++++\n%s\n%s\n++\n%s\n"; # test-name, input, expected-output

  my $data = '';
  my @chars = ( '<', '>', '&' );
  foreach my $char ( @chars ) {
    ( my $charname = e($char) ) =~ s/[&;]//g;
    $data .= sprintf $tmpl, "literal ($charname)", $char, e($char)
          .  sprintf $tmpl, "encode ($charname)", e($char), e($char)
          .  sprintf $tmpl, "meta ($charname)", e(e($char)), e(e($char));
  }

  return $data;
}

sub _slurp {
  my $path = shift;
  open H, $path or die "couldn't open $path: $!";
  local $/;
  my $c = <H>;
  close H;
  return $c;
}

sub file_test {
  my $wc = shift;
  my $lc_dialect = lc $wc->dialect;
  my $infile = File::Spec->catfile( 't', 'complete.html' );
  my $outfile = File::Spec->catfile( 't', "complete.$lc_dialect" );

  SKIP: {
    skip "Couldn't find $infile (ignore this)", 1 unless -e $infile;
    skip "Couldn't find $outfile (ignore this)", 1 unless -e $outfile;
    my( $got, $expect ) = ( $wc->html2wiki( file => $infile, slurp => 1 ), _slurp($outfile) );
    for( $got, $expect ) { s/^\n+//; s/\n+$// }
    is( $got, $expect, 'read from file' );
  };
}

1;
