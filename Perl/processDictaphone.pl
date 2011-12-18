#!/usr/bin/perl
use strict;
use warnings;
use File::stat;            # To get the time and size of a file
# use Time::localtime;       # localtime works WRONG when including this file???

# + Given three parameters $mount, $source and $destination, rename and move the
# folder $mount$source to $destination and unmount $mount.
# + Given less parameters, take default values from right to left:
my $mount="/media/WALKMAN/";
my $source="Record/Voice";
my $destination = "/home/jbarbay/Unison/AudioNotesToProcess/";
my $movingFiles=1; # 0 for False, 1 for True.
my $debugLevel=1; # 0=silent, 1=print and run all system calls, 2=only print system calls.

# + Example of Usage:
# ./processDictaphone.pl /media/WalkmanSony/ Record/Voice/ ~/Unison/AudioNotesToProcess/

print "# Perl Script to Back-up audionotes from any USB dictaphone.\n";
print "# by Jeremy Barbay\n\n";
    

# Recover the parameters: 
if ( @ARGV == 0 ) {
    if( -e "/media/FUJITEL" ) {
	$mount="/media/FUJITEL/";
	$source="Record/";
	$destination = "/home/jbarbay/Unison/AudioNotesToProcess/";
    } elsif( -e "/media/WALKMANSONY" ) {
	$mount="/media/WALKMANSONY/";
	$source="Record/Voice/";
	$destination = "/home/jbarbay/Unison/AudioNotesToProcess/";
    }
} elsif ( @ARGV == 1 ) {
    $mount = shift;
} elsif ( @ARGV == 2 ) {
    $mount = shift;
    $source = shift;
} elsif ( @ARGV == 3 ) {
    $mount = shift;
    $source = shift;
    $destination = shift;
}  else {
    die("Error with parameters (please read header in script)\n");
}


print "Will move and rename '$mount$source' to '$destination'.\n";
checkSourceCanBeAccessed($mount,$source);
checkDestinationIsFolder($destination);
moveVoiceFolder("$mount$source",$destination);
unmountDictaphone($mount);
print "\nThat's all folks!\n";

sub jybySystem {    
    my ($string) = shift;
# 0=silent, 1=print and run all system calls, 2=only print system calls.
    if( $debugLevel == 0 ) {
	system($string);
    } elsif( $debugLevel == 1 ) {
	print "\033[1m$string\033[0m";
	system($string);
    } elsif( $debugLevel == 2 ) {
	print "\033[1m$string\033[0m";
    }
}

sub jybyPrint {
    my ($string) = shift; 
    if( $debugLevel == 0 ) {
    } elsif( $debugLevel == 1 ) {
	print($string);
    } elsif( $debugLevel == 2 ) {
	print($string);
    }
}

sub checkSourceCanBeAccessed {
    my ($mount) = shift;
    my ($source) = shift;
    if( -e "$mount$source" ) {
	jybyPrint ("$mount$source available\n");	
    } else { 
	die("$mount$source cannot be accessed!\n");
    }
}

sub checkDestinationIsFolder {
    my ($destination) = shift;
# Check if $destination exists and is a folder.
    if ( -f $destination )  {
	die("WARNING! '".$destination."' is a file: cannot copy a folder to it!\n ");
    } elsif ( !(-d $destination) ) {
	jybyPrint("Folder '".$destination."' does not exist, creating it.\n");
	jybySystem("mkdir '".$destination."'\n");
    }
}


sub moveVoiceFolder {
    my ($source) = shift;                 # file to process
    my ($destination) = shift;      # relative path
# Automatically Move and rename of "$source" folder to $destination.

    # Recover statistics:
    my $stats = stat($source) or die "Error while recovering stats: $!!\n";
    my $cdate = localtime($stats->ctime);
    jybyPrint("Creation Time\t: ".$cdate."\n");
    my $mdate = localtime($stats->mtime);
    jybyPrint("Modif Time\t: ".$mdate."\n");
    my $adate = localtime($stats->atime);
    jybyPrint("Access Time\t: ".$adate."\n");
    my $backupDate = localtime();
    jybyPrint("Back-up Time (today)\t: ".$backupDate."\n");
    
    # Parse supposing $mdate follows the format "Sun Nov 28 06:25:26 2010" 
    my ($wday, $tmonth, $mday, $hour, $min, $sec, $year) 
	= ($backupDate =~ /(\w+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d+)/) 
	or die("Problem parsing modification date: $!!\n");
    
    # translate textual month into digital value:
    my %mon2num = qw(jan 01 feb 02 mar 03 apr 04 may 05 jun 06 jul 07 aug 08 sep 09 oct 10 nov 11 dec 12); 
    my $month = $mon2num{ lc substr($tmonth, 0, 3) };
    
    # add a leading zero to the day if less than 10.
    my $smday = "";
    if( $mday < 10 ) {
	$smday = "0".$mday;
    } else {
	$smday = $mday;
    }
    
    # Build new name of Folder:
    my $baseNewFolderName = $year."-".$month."-".$smday."_".$hour."-".$min."-".$sec."";
    my $newFolderName = $baseNewFolderName;
    my $version = 0;
    while( -e $source.$newFolderName) {
	$version = $version+1;
	$newFolderName = $baseNewFolderName." version ".$version;
    }
    
    # Move the content of the source folder to the folder $destination/$newFolderName :
    jybySystem("mkdir '".$destination.$newFolderName."'\n");
    jybySystem("cd '".$source."' && mv * '".$destination.$newFolderName."/' && cd - \n");    
}

sub unmountDictaphone {
    my ($mount) = shift;
    # Umount the dictaphone
    jybySystem("umount '".$mount."'\n");
}
