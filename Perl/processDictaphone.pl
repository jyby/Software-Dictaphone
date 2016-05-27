#!/usr/bin/perl
use strict;
use warnings;
use File::stat;            # To get the time and size of a file
# use Time::localtime;       # localtime works WRONG when including this file???

# + Given four parameters $mount, $source, $audioNotesFolderOnComputer and $dataFolderOnComputer,
# + - rename and move the folder $mount$source to $audioNotesFolderOnComputer,
# + - rsynch the content of the folder $dataFolderOnComputer to the root of the dictaphone, and
# + - unmount $mount.
# + Given less parameters, take default values from right to left:
my $mount="/media/usb0/";
my $source="Record/Voice";
my $audioNotesFolderOnComputer = "/home/jbarbay/Unison/Boxes/MyBoxes/AudioNotesToProcess/";
my $dataFolderOnComputer = "/home/jbarbay/Unison/References/DataForOtherDevices/FilesToPutOnDictaphone";
my $movingFiles=0; # 0 for False, 1 for True.
my $debugLevel=1; # 0=silent, 1=print and run all system calls, 2=only print system calls.
my $logFile="log";

# + Example of Usage:
# ./processDictaphone.pl /media/WalkmanSony/ Record/Voice/ ~/Unison/AudioNotesToProcess/

print "# Perl Script to Back-up audionotes from any USB dictaphone.\n";
print "# by Jeremy Barbay\n\n";
print "# Version last modified on [2016-05-27 Fri 05:17] \n\n";
    

# Recover the parameters: 
if ( @ARGV == 0 ) {
    if( -e "/media/FUJITEL" ) {
	$mount="/media/FUJITEL/";
	$source="Record/";
	$audioNotesFolderOnComputer = "/home/jbarbay/Unison/AudioNotesToProcess/";
    } elsif( -e "/media/WALKMANSONY" ) {
	$mount="/media/WALKMANSONY/";
	$source="Record/Voice/";
	$audioNotesFolderOnComputer = "/home/jbarbay/Unison/AudioNotesToProcess/";
    }
} elsif ( @ARGV == 1 ) {
    $mount = shift;
} elsif ( @ARGV == 2 ) {
    $mount = shift;
    $source = shift;
} elsif ( @ARGV == 3 ) {
    $mount = shift;
    $source = shift;
    $audioNotesFolderOnComputer = shift;
}  else {
    die("Error with parameters (please read header in script)\n");
}


print "Will move and rename '$mount$source' to '$audioNotesFolderOnComputer'.\n";
checkSourceCanBeAccessed($mount,$source);
checkDestinationIsFolder($audioNotesFolderOnComputer);
trackNbAudioNotesLeftToRead($audioNotesFolderOnComputer); # Log nb of audionotes before adding the ones from the dictaphone
moveVoiceFolder("$mount$source",$audioNotesFolderOnComputer);
trackNbAudioNotesLeftToRead($audioNotesFolderOnComputer); # Log nb of audionotes after adding the ones from the dictaphone

updateContentOfDictaphone($dataFolderOnComputer,$mount);

unmountDictaphone($mount);
print "\nThat's all folks!\n";

##############################################################################

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

sub updateContentOfDictaphone {
    my ($dataFolderOnComputer) = shift;
    my ($mount) = shift; 
    if( $debugLevel == 0 ) {
      jybySystem("rsynch -r $dataFolderOnComputer/* $mount \n")
    } elsif( $debugLevel > 0 ) {
      jybySystem("rsync -vr $dataFolderOnComputer/* $mount \n")
    }
}

sub unmountDictaphone {
    my ($mount) = shift;
    # Umount the dictaphone
    jybySystem("umount '".$mount."'\n");
}


##############################################################################


sub trackNbAudioNotesLeftToRead{
    my $AudioNotes = shift; # repertory containing the audionotes.
    my $absoluteTime = time;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my $count=estimateNbAudioNotesLeftToRead($AudioNotes);
    # my $realYear = $year+1900;
    # my $realMonth = $mon+1;
    # my $smonth="";
    # my $smday="";

    # # add a leading zero to the day if less than 10.
    # if( $mday < 10 ) {
    # 	$smday = "0".$mday;
    # } else {
    # 	$smday = $mday;
    # }
    # add a leading zero to the month if less than 10.
    # if( $realMonth < 10 ) {
    # 	$smonth = "0".$realMonth;
    # } else {
    # 	$smonth = $realMonth;
    # }

    if( ($debugLevel == 0) | ($debugLevel == 1) ) {
	if( !(-e "${AudioNotes}${logFile}") ) {
	    open (LOGFILE, ">${AudioNotes}${logFile}") or die ("Cannot open file ${AudioNotes}${logFile} !!!");
	    print LOGFILE "# Log produced by the scripts =readWaveFiles.pl= and =processAudioNotes.pl=\n";
	    print LOGFILE "# ";
	    print LOGFILE "absoluteTime\t";
	    print LOGFILE "count\t";
	    print LOGFILE "yyyy\t";
	    print LOGFILE "mm-dd\t";
	    print LOGFILE "hh:mm:ss\t";
	    print LOGFILE "\n";
	} else {
	    open (LOGFILE, ">>${AudioNotes}${logFile}") or die ("Cannot open file ${AudioNotes}${logFile} !!!");
	}
	print LOGFILE "$absoluteTime\t";
	print LOGFILE "$count\t";
	printf("%u\t",(1900+$year));
	printf("%02u-%02u\t",($mon+1),$mday);
	printf("%02u:%02u:%02u\t",$hour,$min,$sec);
	print LOGFILE "\n";
	close (LOGFILE);
    }     
    if( ($debugLevel == 2) | ($debugLevel == 1) ) {
	#print "open $AudioNotes$logFile\n";
	print  "absoluteTime\t";
	print  "count\t";
	print  "yyyy\t";
	print  "mm-dd\t";
	print  "hh:mm:ss\t";
	print "\n";
	print  "$absoluteTime\t";
	print  "$count\t";
	printf("%u\t",(1900+$year));
	printf("%02u-%02u\t",($mon+1),$mday);
	printf("%02u:%02u:%02u\t",$hour,$min,$sec);
	print "\n";
	#print  'close (LOGFILE);\n';
    } 
    return $count;
}

sub estimateNbAudioNotesLeftToRead {
    my ($topdir) = shift; # repertory containing the audionotes.
    opendir (DIR, $topdir) ; 
    my @entries = readdir(DIR);
    my @dirs = ();
    my $totalCount = 0;
    my $e;

    foreach $e (@entries) {
	if ( -d "$topdir/$e" && $e ne "." && $e ne ".." ) {
	    $totalCount = $totalCount + estimateNbAudioNotesLeftToRead("$topdir/$e");
	}
	elsif ( -f "$topdir/$e"  && ( ($e =~ /\.wav$/) || ($e =~ /\.WAV$/) )  ) {
	    $totalCount++;
	}
    }
    return $totalCount;
}

