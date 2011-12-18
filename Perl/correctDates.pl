#!/usr/bin/perl
use strict;
use warnings;
use File::stat;            # To get the time and size of a file

opendir(DIR, "./");
my @entries = readdir(DIR);
my ($e, $f, $d); # iterators for the three loops below

# Sort the content of the folder between folders and WAV files:
foreach $e (@entries) {
	if (  $e =~ "(.*)-1-(.*)" ) {	
	  print("mv '".$e."' '"."$1-01-$2"."'\n");
	  system("mv '".$e."' '"."$1-01-$2"."'\n");
	}	
}
