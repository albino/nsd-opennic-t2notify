#!/usr/bin/env perl
use 5.010;
use strict;
use warnings;
use Net::DNS::Resolver;

## Config
my $write_file = "/var/nsd/etc/cyb.conf";
my $template_file = "template";
## End config

if (scalar(@ARGV) > 0) {
	$write_file = $ARGV[0]; # manual override for testing
}

my $resolver = new Net::DNS::Resolver; # uses nameservers from resolv.conf, hopefully they are openNIC

my $reply = $resolver->query("dns.opennic.glue", "NS");
my $zone = $reply->string;
my @zone = split("\n", $zone);

my %t2s;
for my $record (grep {$_ =~ m/^[^\t ]+\.\t+\d+\t+IN\tA/} @zone) {
	my $name = record_name($record);
	if (exists $t2s{$name}) {
		push (
			@{ $t2s{$name} },
			{
				type => record_type($record),
				value => record_value($record),
			}
		);
	} else {
		$t2s{$name} = [
			{
				type => record_type($record),
				value => record_value($record),
			}
		];
	}
}

my $ret;

T2: while (my ($name, $val) = each %t2s) {
	for my $rec (@{ $val }) {
    if ($rec->{"type"} eq "A") {
			$ret .= "notify: $val->[0]->{value} NOKEY\n\t";
			next T2;
		}
	}
	$ret .= "notify: $val->[0]->{value} NOKEY\n\t";
}

open my $tmplfile, "<", $template_file or die $!;
my $tmpl;
$tmpl .= $_ while <$tmplfile>;
close $tmplfile;

$tmpl =~ s/\{\{\{ t2notify \}\}\}/$ret/;

open my $outfile, ">", $write_file or die $!;
say $outfile $_ for split("\n", $tmpl);
close $outfile;

sub record_name {
	my $record = shift;
	$record =~ /^([^\t ]+\.)/;
	return $1;
}
sub record_type {
	my $record = shift;
	$record =~ /^[^\t ]+\.\t+\d+\t+IN\t(A{1,4})/;
	return $1;
}
sub record_value {
	my $record = shift;
	$record =~ /^[^\t ]+\.\t+\d+\t+IN\tA{1,4}\t+([^\t ]+)$/;
	return $1;
}
