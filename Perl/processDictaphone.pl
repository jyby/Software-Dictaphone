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
my $mount="/home/jbarbay/Mnt/Walkman/";
my $source="Storage Media/Record/Voice";
my $audioNotesFolderOnComputer = "/home/jbarbay/Unison/Boxes/MyBoxes/AudioNotesToProcess/";
my $dataFolderOnComputer = "/home/jbarbay/Unison/References/DataForOtherDevices/Dictaphones";
my $debugLevel=0; # 0=silent, 1=print and run all system calls, 2=only print system calls.
my $logFile="/home/jbarbay/.audioNotes.log";
my $maxSizeTransferEnMegabytes = 2048;

# + Examples of Usage:
# ./processDictaphone.pl /media/WalkmanSony/Record/Voice/ ~/Unison/AudioNotesToProcess/
# ./processDictaphone.pl 

print "# Perl Script to Back-up audionotes from any USB dictaphone.\n";
print "# by Jeremy Barbay\n";
print "# Version last modified on [2019-04-06 Sat 09:33]\n";

# Recover the parameters: 
if ( @ARGV == 0 ) {
    if( -e "/media/FUJITEL" ) {
	$mount="/media/FUJITEL/";
	$source="Storage Media/Record/";
	$audioNotesFolderOnComputer = "/home/jbarbay/Unison/AudioNotesToProcess/";
    } elsif( -e "/media/WALKMANSONY" ) {
	print "WALKMAN Sony detected.\n";
	$mount="/media/WALKMANSONY/";
	$source="Storage Media/Record/Voice/";
	$audioNotesFolderOnComputer = "/home/jbarbay/Unison/AudioNotesToProcess/";
    } elsif( -e "/media/PHILCO" ) {
	$mount="/media/PHILCO/";
	$source="Storage Media/Record/";
	$audioNotesFolderOnComputer = "/home/jbarbay/Unison/AudioNotesToProcess/";
    } elsif( -e "/media/AMT_MP3" ) {
	$mount="/media/AMT_MP3/";
	$source="VOICE/";
	$audioNotesFolderOnComputer = "/home/jbarbay/Unison/AudioNotesToProcess/";
    }
    # if( -e "$mount$source" ) {
    # } else { 
    # 	$source="Storage Media/Record/";
    # }
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


print "\nProcessing '$mount$source' \n  to '$audioNotesFolderOnComputer'.\n";
mountDictaphone($mount);
checkSourceCanBeAccessed($mount,$source);
checkDestinationIsFolder($audioNotesFolderOnComputer);
my $nbAudioNotesOnDictaphone = estimateNbAudioNotesLeftToRead("$mount$source");
my $nbAudioNotesOnComputer = estimateNbAudioNotesLeftToRead($audioNotesFolderOnComputer);
my $nbAudioNotesToProcess = $nbAudioNotesOnDictaphone + $nbAudioNotesOnComputer;
print "Will move $nbAudioNotesOnDictaphone audionotes \n - from '$mount$source' \n - to '$audioNotesFolderOnComputer'.\n";
trackNbAudioNotesLeftToRead($audioNotesFolderOnComputer); # Log nb of audionotes before adding the ones from the dictaphone
moveAndRenameWavFilesInVoiceFolder("$mount$source",$audioNotesFolderOnComputer);
# moveVoiceFolder("$mount$source",$audioNotesFolderOnComputer);
trackNbAudioNotesLeftToRead($audioNotesFolderOnComputer); # Log nb of audionotes after adding the ones from the dictaphone
printTimeRequiredToProcessAudioNotes($nbAudioNotesToProcess);
print "\nRSynching files \n - in '$dataFolderOnComputer' \n - to '$mount'.\n";
updateContentOfDictaphone($dataFolderOnComputer,$mount);
printSpaceLeftOnDevice($mount);
# Umount the Dictaphone
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
    if( $debugLevel > 0 ) {
	print("# $string");
    }
}

sub printTimeRequiredToProcessAudioNotes {
    my ($nbAudioNotesToProcess) = shift;
    print "There are now $nbAudioNotesToProcess audionotes left to process, \n";
    print " which can be processed in at most ";
    my $estimatedProcessingTime = $nbAudioNotesToProcess*2; # 2mns per audio notes
    if( $estimatedProcessingTime<60 ) {
	print "$estimatedProcessingTime mns";
    } else {
	my $estimatedProcessingTimeInHours = int($estimatedProcessingTime / 60);
	my $estimatedProcessingTimeRemain = $estimatedProcessingTime % 60;
	if($estimatedProcessingTimeInHours == 1) {
	    print "1 hour";
	} else {
	    print "$estimatedProcessingTimeInHours hours";
	}
	if($estimatedProcessingTimeRemain > 0) {
	    print " and $estimatedProcessingTimeRemain mns";
	} 
	my $estimatedProcessingTimeInSessions = int($estimatedProcessingTime / 25);
	print ", or $estimatedProcessingTimeInSessions sessions of 25mns";
    }
    print ".\n";
}
    

sub printSpaceLeftOnDevice {
    my ($mount) = shift;
    print ("Space available on the device:\n");	
    jybySystem("df -h '$mount'\n");
}

sub checkSourceCanBeAccessed {
    my ($mount) = shift;
    my ($source) = shift;
    if( -e "$mount$source" ) {
	jybyPrint ("'$mount$source' available\n");	
    } else { 
	die("'$mount$source' cannot be accessed!\n");
    }
}

sub checkDestinationIsFolder {
    my ($destination) = shift;
# Check if $destination exists and is a folder.
    if ( -f $destination )  {
	die("WARNING! '$destination' is a file: cannot copy a folder to it!\n ");
    } elsif ( !(-d $destination) ) {
	jybyPrint("Folder '$destination' does not exist, creating it.\n");
	jybySystem("mkdir '$destination'\n");
    }
}

sub compactDateFormat {
    my ($date) = shift;
    
    my ($wday, $tmonth, $mday, $hour, $min, $sec, $year) 
	= ($date =~ /(\w+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d+)/) 
	or die("Problem parsing date: $!!\n");
    
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
    
    # Create name for new folder, named after current date:
    my $compactformat = $year."-".$month."-".$smday."_".$hour."-".$min."-".$sec."";
    return $compactformat;
}

sub moveAndRenameOneWavFile {
    my ($source) = shift;                 # file to process
    my ($destination) = shift;            # relative path
# Move the .wav file "$source" to the folder $destination, and rename it according to its modification date.

    jybyPrint("Move the .wav file $source\n to the folder '$destination',\n and rename it according to its modification date.\n");
    
    # Recover statistics:
    my $stats = stat($source) or die "Error while recovering stats: $!!\n";
    my $cdate = localtime($stats->ctime);
    jybyPrint("Creation Time of $source\t: ".$cdate."\n");
    my $mdate = localtime($stats->mtime);
    jybyPrint("Modif Time of $source\t: ".$mdate."\n");
    my $adate = localtime($stats->atime);
    jybyPrint("Access Time of $source\t: ".$adate."\n");
    my $backupDate = localtime();
    jybyPrint("Back-up Time (today)\t: ".$backupDate."\n");
    
    # Parse supposing $cdate follows the format "Sun Nov 28 06:25:26 2010" 
    my ($wday, $tmonth, $mday, $hour, $min, $sec, $year) 
	= ($cdate =~ /(\w+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d+)/) 
	or die("Problem parsing creation date: $!!\n");
    
    # translate textual month into digital value:
    my %mon2num = qw(jan 01 feb 02 mar 03 apr 04 may 05 jun 06 jul 07 aug 08 sep 09 oct 10 nov 11 dec 12); 
    my $month = $mon2num{ lc substr($tmonth, 0, 3) };

    # Build new name of File:
    my $baseNewFileName = ""; 
    if( $month == 1 && $mday == 1 && $hour == 1 && $min == 0 && $sec == 0 ) {
      $baseNewFileName = compactDateFormat($backupDate)."_backup";
      jybyPrint("Dictaphone without date: Using the back up date '".$baseNewFileName."' for its name instead.\n");
    } else  {
      $baseNewFileName = compactDateFormat($cdate);
    }
    # Build new name of File:
    my $newFileName = $baseNewFileName."_audioNote".".wav";
    my $version = 1;
    while( -e $destination."/".$newFileName) {
        jybyPrint("Increment the version number as '$destination/$newFileName' already exists.\n");
	$version = $version+1;
	$newFileName = $baseNewFileName."_v".$version.".wav";
    }
    # Move and rename the wave file to the folder $destination :
    jybyPrint("Moving a single file:\n");
    jybySystem("mv '$source' '$destination/$newFileName'\n");    
}


sub moveAndRenameWavFilesInVoiceFolder {
    my ($source) = shift;                 # file to process
    my ($destination) = shift;            # relative path
# Create in $destination a folder named according to the current (backup) date, and move there and rename the audionotes from $source.

    jybyPrint("Create in '$destination'\n a folder named according to the current (backup) date,\n and move there and rename the audionotes from '$source'.\n");
    
    # Recover statistics:
    my $backupDate = localtime();
    jybyPrint("Back-up Time (today):\t$backupDate\n");
    
    # Create new folder, named after current date:
    my $baseNewFolderName =  compactDateFormat($backupDate);
    my $newFolderName = $baseNewFolderName;
    my $version = 0;
    while( -e $destination.$newFolderName) {
	$version = $version+1;
	$newFolderName = $baseNewFolderName."v".$version;
    }
    jybySystem("mkdir '$destination$newFolderName'\n");
    
    # Move the content of the source folder to the folder $destination/$newFolderName :
    jybyPrint("Opening folder\t'$source'\n");
    opendir (DIR, "$source"); 
    my @entries = readdir(DIR);
    my @dirs = ();
    my $e;

    foreach $e (@entries) {
	if ( -f "$source/$e"  && ( ($e =~ /\.wav$/) || ($e =~ /\.WAV$/) )  ) {
	    moveAndRenameOneWavFile("$source/$e","$destination$newFolderName");
	}  else {
	    jybyPrint("Ignoring file '$e' in folder '$source'\n");	    
    	}
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
    jybyPrint("Back-up Time (today):\t$backupDate\n");
    
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
    jybySystem("mkdir '$destination$newFolderName'\n");
    jybySystem("cd '".$source."' && mv * '".$destination.$newFolderName."/' && cd - \n");    
}


sub updateContentOfDictaphone {
    my ($dataFolderOnComputer) = shift;
    my ($mount) = shift; 
    if( $debugLevel == 0 ) {
	jybySystem("rsync -cr '$dataFolderOnComputer/' '$mount/Storage Media/' \n");
    } elsif( $debugLevel > 0 ) {
	jybySystem("rsync -vcr '$dataFolderOnComputer/' '$mount/Storage Media/' \n");
    }
}

sub mountDictaphone {
    my ($mount) = shift;
    # Mount the dictaphone
    jybySystem("fusermount -u '".$mount."'\n");
    jybySystem("jmtpfs '".$mount."'\n");
}
sub unmountDictaphone {
    my ($mount) = shift;
    # Umount the dictaphone
    # jybySystem("sudo umount '".$mount."'\n");
    jybySystem("fusermount -u '".$mount."'\n");
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
	if( !(-e "${logFile}") ) {
	    open (LOGFILE, ">${logFile}") or die ("Cannot open file ${logFile} !!!");
	    print LOGFILE "# Log produced by the scripts =readWaveFiles.pl= and =processAudioNotes.pl=\n";
	    print LOGFILE "# ";
	    print LOGFILE "absoluteTime\t";
	    print LOGFILE "count\t";
	    print LOGFILE "yyyy\t";
	    print LOGFILE "mm-dd\t";
	    print LOGFILE "hh:mm:ss\t";
	    print LOGFILE "\n";
	} else {
	    open (LOGFILE, ">>${logFile}") or die ("Cannot open file ${logFile} !!!");
	}
	print LOGFILE "$absoluteTime\t";
	print LOGFILE "$count\t";
	printf(LOGFILE "%u\t",(1900+$year));
	printf(LOGFILE "%02u-%02u\t",($mon+1),$mday);
	printf(LOGFILE "%02u:%02u:%02u\t",$hour,$min,$sec);
	printf(LOGFILE "processDictaphone\t");
	print LOGFILE "\n";
	close (LOGFILE);
    }     
    if( ($debugLevel == 2) | ($debugLevel == 1) ) {
	print "open '$logFile' and log the following entry:\n";
	print  "absoluteTime\t";
	print  "count\t";
	print  "yyyy\t";
	print  "mm-dd\t";
	print  "hh:mm:ss\t";
	print  "nameOfScriptLogging\t";
	print "\n";
	print  "$absoluteTime\t";
	print  "$count\t";
	printf("%u\t",(1900+$year));
	printf("%02u-%02u\t",($mon+1),$mday);
	printf("%02u:%02u:%02u\t",$hour,$min,$sec);
	printf("processDictaphone\t");
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

